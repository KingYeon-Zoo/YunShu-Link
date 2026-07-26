import unittest

from core.providers.s2s.client import MODEL_O2, MODEL_SC2
from core.providers.s2s.session_config import (
    build_dialog_context,
    build_start_session_payload,
)
from core.providers.s2s.tool_bridge import DefaultAudioGate
from core.providers.tts.dto.dto import SentenceType


class StartSessionPayloadTest(unittest.TestCase):
    def test_asr_and_tts_extra_always_present(self):
        """asr.extra 或 tts.extra 缺失会让服务端直接报 42000020。"""
        payload = build_start_session_payload({})
        self.assertIn("extra", payload["asr"])
        self.assertIn("extra", payload["tts"])
        self.assertIsInstance(payload["asr"]["extra"], dict)
        self.assertIsInstance(payload["tts"]["extra"], dict)

    def test_model_is_always_sent(self):
        payload = build_start_session_payload({})
        self.assertEqual(payload["dialog"]["extra"]["model"], MODEL_O2)

    def test_sc_model_inferred_from_clone_speaker(self):
        payload = build_start_session_payload(
            {"speaker": "saturn_zh_female_aojiaonvyou_tob"}
        )
        self.assertEqual(payload["dialog"]["extra"]["model"], MODEL_SC2)

    def test_o_model_uses_three_persona_fields(self):
        payload = build_start_session_payload(
            {"model": MODEL_O2}, prompt="你是琉璃，一只中二猫娘。"
        )
        dialog = payload["dialog"]
        self.assertEqual(dialog["system_role"], "你是琉璃，一只中二猫娘。")
        self.assertNotIn("character_manifest", dialog)

    def test_sc_model_uses_character_manifest(self):
        payload = build_start_session_payload(
            {"model": MODEL_SC2, "speaker": "S_custom01"},
            prompt="你是琉璃，一只中二猫娘。",
        )
        dialog = payload["dialog"]
        self.assertEqual(dialog["character_manifest"], "你是琉璃，一只中二猫娘。")
        self.assertNotIn("system_role", dialog)

    def test_official_clone_speaker_keeps_server_side_persona(self):
        """_tob 官方音色的角色描述在服务端，覆盖会破坏效果。"""
        payload = build_start_session_payload(
            {"model": MODEL_SC2, "speaker": "saturn_zh_male_badaoshaoye_tob"},
            prompt="不该覆盖",
        )
        self.assertNotIn("character_manifest", payload["dialog"])

    def test_bot_name_truncated_to_twenty_chars(self):
        payload = build_start_session_payload({"bot_name": "云" * 30})
        self.assertEqual(len(payload["dialog"]["bot_name"]), 20)

    def test_music_rejected_on_sc_model(self):
        """enable_music 只在 O2.0 生效，配到 SC2.0 会报 42000020。"""
        payload = build_start_session_payload(
            {"model": MODEL_SC2, "enable_music": True}
        )
        self.assertNotIn("enable_music", payload["dialog"]["extra"])

    def test_music_allowed_on_o2_model(self):
        payload = build_start_session_payload(
            {"model": MODEL_O2, "enable_music": True}
        )
        self.assertTrue(payload["dialog"]["extra"]["enable_music"])

    def test_default_input_mod_avoids_idle_timeout(self):
        """默认 keep_alive，规避 52000042 静音超时。"""
        payload = build_start_session_payload({})
        self.assertEqual(payload["dialog"]["extra"]["input_mod"], "keep_alive")

    def test_websearch_agent_carries_bot_id(self):
        payload = build_start_session_payload(
            {
                "enable_websearch": True,
                "websearch_type": "web_agent",
                "websearch_api_key": "key-1",
                "websearch_bot_id": "bot-1",
            }
        )
        extra = payload["dialog"]["extra"]
        self.assertTrue(extra["enable_volc_websearch"])
        self.assertEqual(extra["volc_websearch_type"], "web_agent")
        self.assertEqual(extra["volc_websearch_api_key"], "key-1")
        self.assertEqual(extra["volc_websearch_bot_id"], "bot-1")

    def test_websearch_result_count_capped_at_ten(self):
        payload = build_start_session_payload(
            {"enable_websearch": True, "websearch_result_count": 99}
        )
        self.assertEqual(
            payload["dialog"]["extra"]["volc_websearch_result_count"], 10
        )

    def test_audio_config_matches_device_sample_rate(self):
        payload = build_start_session_payload({})
        audio = payload["tts"]["audio_config"]
        self.assertEqual(audio["format"], "pcm_s16le")
        self.assertEqual(audio["sample_rate"], 24000)
        self.assertEqual(audio["channel"], 1)

    def test_end_smooth_window_clamped_to_valid_range(self):
        low = build_start_session_payload({"end_smooth_window_ms": 100})
        self.assertEqual(low["asr"]["extra"]["end_smooth_window_ms"], 500)
        high = build_start_session_payload({"end_smooth_window_ms": 99999})
        self.assertEqual(high["asr"]["extra"]["end_smooth_window_ms"], 50000)

    def test_hotwords_enable_twopass_recognition(self):
        payload = build_start_session_payload({"hotwords": ["云枢", "琉璃"]})
        extra = payload["asr"]["extra"]
        self.assertTrue(extra["enable_asr_twopass"])
        self.assertEqual(
            extra["context"]["hotwords"], [{"word": "云枢"}, {"word": "琉璃"}]
        )


class DialogContextTest(unittest.TestCase):
    def test_only_complete_qa_pairs_are_kept(self):
        """服务端要求偶数长度且 user/assistant 成对。"""
        history = [
            {"role": "user", "content": "你好"},
            {"role": "assistant", "content": "在的"},
            {"role": "user", "content": "落单的问题"},
        ]
        context = build_dialog_context(history)
        self.assertEqual(len(context), 2)
        self.assertEqual(context[0]["role"], "user")
        self.assertEqual(context[1]["role"], "assistant")

    def test_context_truncated_to_twenty_rounds(self):
        history = []
        for i in range(30):
            history.append({"role": "user", "content": f"问{i}"})
            history.append({"role": "assistant", "content": f"答{i}"})
        context = build_dialog_context(history)
        self.assertEqual(len(context), 40)
        self.assertEqual(context[0]["text"], "问10")

    def test_empty_history_returns_empty_list(self):
        self.assertEqual(build_dialog_context(None), [])


class DefaultAudioGateTest(unittest.TestCase):
    def test_release_returns_buffered_audio_in_order(self):
        gate = DefaultAudioGate()
        gate.open_round(True)
        gate.buffer(b"aa")
        gate.buffer(b"bb")
        self.assertEqual(gate.release(), [b"aa", b"bb"])
        self.assertFalse(gate.pending)
        self.assertFalse(gate.suppress)

    def test_discard_drops_audio_and_suppresses_rest(self):
        gate = DefaultAudioGate()
        gate.open_round(True)
        gate.buffer(b"aa")
        gate.discard()
        self.assertTrue(gate.suppress)
        self.assertFalse(gate.pending)
        self.assertEqual(gate.release(), [])

    def test_buffer_refuses_beyond_cap(self):
        gate = DefaultAudioGate()
        gate.open_round(True)
        # 超过 3 秒（约 144KB）后应拒绝继续缓存
        self.assertTrue(gate.buffer(b"x" * 100000))
        self.assertTrue(gate.buffer(b"x" * 50000))
        self.assertFalse(gate.buffer(b"x" * 10))

    def test_subtitle_is_held_and_taken_once(self):
        gate = DefaultAudioGate()
        gate.open_round(True)
        gate.hold_subtitle(SentenceType.FIRST, "你好")
        self.assertEqual(gate.take_subtitle(), (SentenceType.FIRST, "你好"))
        self.assertIsNone(gate.take_subtitle())

    def test_not_pending_when_routing_disabled(self):
        gate = DefaultAudioGate()
        gate.open_round(False)
        self.assertFalse(gate.pending)
        self.assertFalse(gate.expired())


if __name__ == "__main__":
    unittest.main()
