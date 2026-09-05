import json
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from core.connection import ConnectionHandler
TAG = __name__


async def handleAbortMessage(conn: "ConnectionHandler"):
    conn.logger.bind(tag=TAG).info("Abort message received")
    # 设置成打断状态，会自动打断llm、tts任务
    conn.close_after_chat = False
    conn.client_abort = True
    conn.clear_queues()
    # 端到端语音模式：同步作废本轮的音频闸门与工具等待
    if getattr(conn.asr, "is_s2s", False):
        await conn.asr.abort_round()
    # 打断客户端说话状态
    await conn.websocket.send(
        json.dumps({"type": "tts", "state": "stop", "session_id": conn.session_id})
    )
    conn.clearSpeakStatus()
    conn.logger.bind(tag=TAG).info("Abort message received-end")
