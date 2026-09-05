import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from core.providers.asr.doubao_realtime import ASRProvider
from core.providers.s2s import protocol as pr
from core.providers.tts.dto.dto import SentenceType


class FakeQueue:
    def __init__(self):
        self.items = []

    def put(self, item):
        self.items.append(item)

    def qsize(self):
        return len(self.items)


class FakeEncoder:
    """记录喂进来的 PCM，并把每帧当作一个 opus 包回调出去。"""

    def __init__(self):
        self.fed = []
        self.flushed = False

    def encode_pcm_to_opus_stream(self, pcm, end_of_stream, callback):
        if end_of_stream:
            self.flushed = True
            return
        self.fed.append(pcm)
        callback(b"opus:" + pcm[:4])


class FakeDialogue:
    def __init__(self):
        self.dialogue = []

    def put(self, msg):
        self.dialogue.append(msg)


def make_conn():
    tts = SimpleNamespace(
        tts_audio_queue=FakeQueue(),
        tts_text_queue=FakeQueue(),
        opus_encoder=FakeEncoder(),
    )
    tts.handle_opus = lambda data: tts.tts_audio_queue.put(
        (SentenceType.MIDDLE, data, None, "sid")
    )
    return SimpleNamespace(
        tts=tts,
        dialogue=FakeDialogue(),
        config={"prompt": "你是琉璃"},
        session_id="session-1",
        sentence_id="",
        client_abort=False,
        client_is_speaking=False,
        close_after_chat=False,
        sample_rate=24000,
        llm=None,
        func_handler=None,
        logger=SimpleNamespace(bind=lambda **_: SimpleNamespace(
            info=lambda *a, **k: None,
            debug=lambda *a, **k: None,
            warning=lambda *a, **k: None,
            error=lambda *a, **k: None,
        )),
    )


def make_provider(conn, config=None):
    cfg = {"appid": "1", "access_key": "k", "enable_tools": False}
    cfg.update(config or {})
    provider = ASRProvider(cfg, delete_audio_file=True)
    provider.conn = conn
    provider._session_ready.set()
    return provider


class RealtimeRoundFlowTest(unittest.IsolatedAsyncioTestCase):
    """一轮完整交互必须复用设备侧既有协议。"""

    async def test_asr_ended_sends_subtitle_and_records_user_turn(self):
        conn = make_conn()
        provider = make_provider(conn)
        provider._on_asr_text({"results": [{"text": "今天天气", "is_interim": False}]})

        with patch(
            "core.providers.asr.doubao_realtime.send_stt_message", new=AsyncMock()
        ) as stt, patch(
            "core.providers.asr.doubao_realtime.enqueue_asr_report"
        ) as report:
            await provider._on_asr_ended()

        stt.assert_awaited_once_with(conn, "今天天气")
        report.assert_called_once()
        self.assertEqual(conn.dialogue.dialogue[-1].role, "user")
        self.assertEqual(conn.dialogue.dialogue[-1].content, "今天天气")
        self.assertTrue(conn.sentence_id)

    async def test_interim_result_does_not_override_final(self):
        provider = make_provider(make_conn())
        provider._on_asr_text({"results": [{"text": "最终", "is_interim": False}]})
        provider._on_asr_text({"results": [{"text": "中间", "is_interim": True}]})
        self.assertEqual(provider._user_text, "最终")

    async def test_first_sentence_then_middle(self):
        conn = make_conn()
        provider = make_provider(conn)
        await provider._on_sentence_start({"tts_type": "default", "text": "你好"})
        await provider._on_sentence_start({"tts_type": "default", "text": "在的"})

        types = [item[0] for item in conn.tts.tts_audio_queue.items]
        self.assertEqual(types, [SentenceType.FIRST, SentenceType.MIDDLE])

    async def test_audio_is_encoded_into_device_queue(self):
        conn = make_conn()
        provider = make_provider(conn)
        provider._current_tts_type = "default"
        await provider._on_audio_event(b"\x01\x02" * 480)

        self.assertEqual(len(conn.tts.opus_encoder.fed), 1)
        self.assertTrue(
            any(item[1] == b"opus:\x01\x02\x01\x02" for item in conn.tts.tts_audio_queue.items)
        )

    async def test_audio_dropped_after_abort(self):
        conn = make_conn()
        conn.client_abort = True
        provider = make_provider(conn)
        await provider._on_audio_event(b"\x01\x02" * 480)
        self.assertEqual(conn.tts.opus_encoder.fed, [])

    async def test_round_end_emits_last_and_records_assistant_turn(self):
        conn = make_conn()
        provider = make_provider(conn)
        conn.sentence_id = "sid-1"
        provider._assistant_text = "今天晴天"

        await provider._on_round_end({})

        last = conn.tts.tts_audio_queue.items[-1]
        self.assertEqual(last[0], SentenceType.LAST)
        self.assertEqual(conn.dialogue.dialogue[-1].role, "assistant")
        self.assertEqual(conn.dialogue.dialogue[-1].content, "今天晴天")
        self.assertTrue(conn.tts.opus_encoder.flushed)

    async def test_user_exit_signal_closes_after_chat(self):
        conn = make_conn()
        provider = make_provider(conn)
        await provider._on_round_end({"status_code": pr.STATUS_USER_EXIT})
        self.assertTrue(conn.close_after_chat)

    async def test_normal_round_end_does_not_close(self):
        conn = make_conn()
        provider = make_provider(conn)
        await provider._on_round_end({"status_code": "20000000"})
        self.assertFalse(conn.close_after_chat)

    async def test_asr_info_aborts_playback_when_speaking(self):
        conn = make_conn()
        conn.client_is_speaking = True
        provider = make_provider(conn)
        with patch(
            "core.handle.abortHandle.handleAbortMessage", new=AsyncMock()
        ) as abort:
            await provider._on_user_speech_start()
        abort.assert_awaited_once()


class ToolGateFlowTest(unittest.IsolatedAsyncioTestCase):
    """工具路由与闲聊音频的竞态处理。"""

    async def test_chitchat_audio_held_while_routing(self):
        conn = make_conn()
        provider = make_provider(conn)
        provider.gate.open_round(True, timeout=5)
        provider._current_tts_type = "default"

        await provider._on_audio_event(b"\x03\x04" * 480)
        # 判定期间不应喂给编码器
        self.assertEqual(conn.tts.opus_encoder.fed, [])

    async def test_held_audio_and_subtitle_released_when_no_tool(self):
        conn = make_conn()
        provider = make_provider(conn)
        provider.gate.open_round(True, timeout=5)
        provider._current_tts_type = "default"

        await provider._on_sentence_start({"tts_type": "default", "text": "你好呀"})
        await provider._on_audio_event(b"\x03\x04" * 480)
        self.assertEqual(conn.tts.tts_audio_queue.items, [])

        await provider._release_default_audio()

        first = conn.tts.tts_audio_queue.items[0]
        self.assertEqual(first[0], SentenceType.FIRST)
        self.assertEqual(first[2], "你好呀")
        self.assertEqual(len(conn.tts.opus_encoder.fed), 1)

    async def test_discard_suppresses_subsequent_chitchat_audio(self):
        conn = make_conn()
        provider = make_provider(conn)
        provider.gate.open_round(True, timeout=5)
        provider._current_tts_type = "default"
        await provider._on_audio_event(b"\x03\x04" * 480)

        provider.gate.discard()
        await provider._on_audio_event(b"\x05\x06" * 480)

        self.assertEqual(conn.tts.opus_encoder.fed, [])
        self.assertEqual(conn.tts.tts_audio_queue.items, [])

    async def test_tool_result_audio_passes_gate(self):
        """工具结果音频的 tts_type 不是 default，不受闸门影响。"""
        conn = make_conn()
        provider = make_provider(conn)
        provider.gate.open_round(True, timeout=5)
        provider.gate.discard()

        provider._current_tts_type = "external_rag"
        await provider._on_sentence_start(
            {"tts_type": "external_rag", "text": "北京今天晴"}
        )
        await provider._on_audio_event(b"\x07\x08" * 480)

        self.assertEqual(len(conn.tts.opus_encoder.fed), 1)
        self.assertEqual(conn.tts.tts_audio_queue.items[0][2], "北京今天晴")

    async def test_expired_gate_releases_audio(self):
        conn = make_conn()
        provider = make_provider(conn)
        provider.gate.open_round(True, timeout=-1)  # 立即过期
        provider._current_tts_type = "default"

        await provider._on_audio_event(b"\x03\x04" * 480)

        self.assertEqual(len(conn.tts.opus_encoder.fed), 1)
        self.assertFalse(provider.gate.pending)

    async def test_round_end_while_pending_still_releases(self):
        """判定没回来但模型已说完：必须放行，不能让设备卡在播放态。"""
        conn = make_conn()
        provider = make_provider(conn)
        conn.sentence_id = "sid-2"
        provider.gate.open_round(True, timeout=5)
        provider._current_tts_type = "default"
        await provider._on_audio_event(b"\x03\x04" * 480)

        await provider._on_round_end({})

        self.assertEqual(len(conn.tts.opus_encoder.fed), 1)
        self.assertEqual(conn.tts.tts_audio_queue.items[-1][0], SentenceType.LAST)

    async def test_awaiting_tool_round_skips_premature_stop(self):
        """丢弃闲聊后，模型原轮的 TTSEnded 不能提前给设备发 stop。"""
        conn = make_conn()
        provider = make_provider(conn)
        provider._await_tool_round = True

        await provider._on_round_end({})

        types = [item[0] for item in conn.tts.tts_audio_queue.items]
        self.assertNotIn(SentenceType.LAST, types)
        self.assertFalse(provider._await_tool_round)

    async def test_abort_round_resets_gate(self):
        conn = make_conn()
        provider = make_provider(conn)
        provider.gate.open_round(True, timeout=5)
        provider._await_tool_round = True

        await provider.abort_round()

        self.assertFalse(provider.gate.pending)
        self.assertFalse(provider._await_tool_round)


class ResampleTest(unittest.IsolatedAsyncioTestCase):
    async def test_no_resample_when_rates_match(self):
        conn = make_conn()
        provider = make_provider(conn)
        pcm = b"\x01\x02" * 480
        self.assertIs(provider._match_device_rate(pcm), pcm)

    async def test_resamples_when_device_wants_16k(self):
        conn = make_conn()
        conn.sample_rate = 16000
        provider = make_provider(conn)
        out = provider._match_device_rate(b"\x01\x02" * 480)
        # 24k → 16k，样本数变为 2/3
        self.assertEqual(len(out), 640)


if __name__ == "__main__":
    unittest.main()
