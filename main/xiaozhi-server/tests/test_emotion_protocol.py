import json
import unittest
from types import SimpleNamespace

from core.utils.textUtils import get_emotion


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


class EmotionProtocolTest(unittest.IsolatedAsyncioTestCase):
    async def test_回复中的表情应转换为固件可识别的_llm_消息(self):
        websocket = _FakeWebSocket()
        conn = SimpleNamespace(
            websocket=websocket,
            session_id="regression-session",
            logger=_FakeLogger(),
        )

        await get_emotion(conn, "🤔让我想一想。")

        self.assertEqual(
            websocket.messages,
            [
                {
                    "type": "llm",
                    "text": "🤔",
                    "emotion": "thinking",
                    "session_id": "regression-session",
                }
            ],
        )

    async def test_回复没有表情时应保持向后兼容的开心状态(self):
        websocket = _FakeWebSocket()
        conn = SimpleNamespace(
            websocket=websocket,
            session_id="regression-session",
            logger=_FakeLogger(),
        )

        await get_emotion(conn, "普通文本回复")

        self.assertEqual(websocket.messages[0]["emotion"], "happy")
        self.assertEqual(websocket.messages[0]["text"], "🙂")

    async def test_模型遗漏表情时服务端应根据语义生成情绪(self):
        websocket = _FakeWebSocket()
        conn = SimpleNamespace(
            websocket=websocket,
            session_id="regression-session",
            logger=_FakeLogger(),
        )

        await get_emotion(conn, "真没想到会是这个结果，我也很惊讶。")

        self.assertEqual(websocket.messages[0]["emotion"], "surprised")
        self.assertEqual(websocket.messages[0]["text"], "😲")


if __name__ == "__main__":
    unittest.main()
