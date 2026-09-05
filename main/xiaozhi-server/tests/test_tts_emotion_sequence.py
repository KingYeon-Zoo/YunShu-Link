import json
import sys
import types
import unittest
from types import SimpleNamespace
from unittest import mock


class _FakeWebSocket:
    def __init__(self):
        self.messages = []

    async def send(self, message):
        self.messages.append(json.loads(message))


class _FakeBoundLogger:
    def debug(self, _message):
        pass

    def warning(self, message):
        raise AssertionError(message)


class _FakeLogger:
    def bind(self, **_kwargs):
        return _FakeBoundLogger()


def _load_send_tts_message():
    # 测试只覆盖 JSON 下发顺序，不需要加载音频编解码及文件转换依赖。
    opus_module = types.ModuleType("opuslib_next")
    opus_module.Decoder = object
    util_module = types.ModuleType("core.utils.util")
    rate_controller_module = types.ModuleType("core.utils.audioRateController")
    rate_controller_module.AudioRateController = object

    async def audio_to_data(*_args, **_kwargs):
        return []

    util_module.audio_to_data = audio_to_data
    with mock.patch.dict(
        sys.modules,
        {
            "opuslib_next": opus_module,
            "core.utils.util": util_module,
            "core.utils.audioRateController": rate_controller_module,
        },
    ):
        from core.handle.sendAudioHandle import send_tts_message

    return send_tts_message


class TtsEmotionSequenceTest(unittest.IsolatedAsyncioTestCase):
    async def test_首句播放前服务端必须先下发情绪消息(self):
        websocket = _FakeWebSocket()
        conn = SimpleNamespace(
            websocket=websocket,
            session_id="websocket-session",
            sentence_id="sentence-1",
            emotion_sent_sentence_id=None,
            features={"emoji": True},
            logger=_FakeLogger(),
        )

        send_tts_message = _load_send_tts_message()
        await send_tts_message(conn, "sentence_start", "让我想一想。")

        self.assertEqual([message["type"] for message in websocket.messages], ["llm", "tts"])
        self.assertEqual(websocket.messages[0]["emotion"], "thinking")
        self.assertEqual(websocket.messages[1]["state"], "sentence_start")

    async def test_同一句子已有情绪时不得重复下发(self):
        websocket = _FakeWebSocket()
        conn = SimpleNamespace(
            websocket=websocket,
            session_id="websocket-session",
            sentence_id="sentence-1",
            emotion_sent_sentence_id="sentence-1",
            features={"emoji": True},
            logger=_FakeLogger(),
        )

        send_tts_message = _load_send_tts_message()
        await send_tts_message(conn, "sentence_start", "好的，马上开始。")

        self.assertEqual(len(websocket.messages), 1)
        self.assertEqual(websocket.messages[0]["type"], "tts")


if __name__ == "__main__":
    unittest.main()
