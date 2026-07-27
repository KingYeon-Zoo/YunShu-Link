"""豆包端到端实时语音大模型 WebSocket 客户端（纯传输层）。

只负责连接、会话生命周期与事件收发，不涉及设备侧协议。
事件语义与编排由调用方（core/providers/asr/doubao_realtime.py）负责。
"""

import uuid
import websockets
from typing import Any, Dict, Optional

from config.logger import setup_logging
from core.providers.s2s import protocol as pr

TAG = __name__
logger = setup_logging()

WS_URL = "wss://openspeech.bytedance.com/api/v3/realtime/dialogue"
# 固定值，见接口文档 2.1
APP_KEY = "PlgvMymc7f3tQnJ6"
RESOURCE_ID = "volc.speech.dialog"

# model 字段为必传，取值枚举见文档 1.1
MODEL_O2 = "1.2.1.1"  # O2.0：多模态，支持精品音色与唱歌
MODEL_SC2 = "2.2.0.0"  # SC2.0：角色扮演，支持 saturn_/S_ 克隆音色


class RealtimeSessionError(RuntimeError):
    """StartSession / StartConnection 失败，或会话中收到致命错误帧。"""


class DoubaoRealtimeClient:
    def __init__(self, config: Dict[str, Any]):
        self.app_id = str(config.get("appid") or config.get("app_id") or "")
        self.access_key = config.get("access_key") or config.get("access_token") or ""
        self.resource_id = config.get("resource_id", RESOURCE_ID)
        self.ws_url = config.get("ws_url", WS_URL)
        self.connect_timeout = int(config.get("connect_timeout", 10))

        self.ws = None
        self.session_id: str = ""
        self.dialog_id: str = ""
        self.connect_id: str = ""
        self.logid: str = ""

    @property
    def is_open(self) -> bool:
        return self.ws is not None

    def _headers(self) -> Dict[str, str]:
        self.connect_id = str(uuid.uuid4())
        return {
            "X-Api-App-ID": self.app_id,
            "X-Api-Access-Key": self.access_key,
            "X-Api-Resource-Id": self.resource_id,
            "X-Api-App-Key": APP_KEY,
            "X-Api-Connect-Id": self.connect_id,
        }

    async def connect(self) -> None:
        """建立 WebSocket 并完成 StartConnection 握手。"""
        if not self.app_id or not self.access_key:
            raise RealtimeSessionError("端到端语音缺少 appid 或 access_key 配置")

        self.ws = await websockets.connect(
            self.ws_url,
            additional_headers=self._headers(),
            max_size=None,
            ping_interval=None,
            ping_timeout=None,
            close_timeout=self.connect_timeout,
        )
        self.logid = (self.ws.response.headers or {}).get("X-Tt-Logid", "")

        await self.ws.send(pr.build_event(pr.EV_START_CONNECTION))
        frame = pr.parse_frame(await self.ws.recv())
        if frame.event != pr.EV_CONNECTION_STARTED:
            await self.close()
            raise RealtimeSessionError(
                f"建立连接失败: event={frame.event} {frame.payload}"
            )
        logger.bind(tag=TAG).info(f"端到端语音连接已建立, logid={self.logid}")

    async def start_session(self, payload: Dict[str, Any]) -> str:
        """发送 StartSession 并等待 SessionStarted，返回服务端下发的 dialog_id。"""
        self.session_id = str(uuid.uuid4())
        await self.ws.send(pr.build_event(pr.EV_START_SESSION, payload, self.session_id))

        frame = pr.parse_frame(await self.ws.recv())
        if frame.event != pr.EV_SESSION_STARTED:
            raise RealtimeSessionError(
                f"启动会话失败: event={frame.event} {frame.payload}"
            )
        self.dialog_id = frame.payload.get("dialog_id", "")
        logger.bind(tag=TAG).info(
            f"端到端会话已启动, session={self.session_id}, dialog={self.dialog_id}"
        )
        return self.dialog_id

    async def recv(self) -> pr.ServerFrame:
        return pr.parse_frame(await self.ws.recv())

    async def _send(self, event: int, payload: Optional[Dict[str, Any]] = None) -> None:
        if self.ws is None:
            return
        await self.ws.send(pr.build_event(event, payload, self.session_id))

    async def send_audio(self, pcm: bytes) -> None:
        """上传 16k/单声道/int16/小端 PCM 音频。"""
        if self.ws is None:
            return
        await self.ws.send(pr.build_audio(pcm, self.session_id))

    async def send_text_query(self, text: str) -> None:
        """以文本发起 query，模型正常生成闲聊回复。"""
        await self._send(pr.EV_CHAT_TEXT_QUERY, {"content": text})

    async def send_rag_text(self, external_rag: str) -> None:
        """注入外部知识，由模型总结口语化后播报（替代本轮闲聊结果）。"""
        await self._send(pr.EV_CHAT_RAG_TEXT, {"external_rag": external_rag})

    async def send_tts_text(self, content: str, start: bool, end: bool) -> None:
        """指定文本直接合成音频，跳过模型生成。须在 ASREnded 之后发送。"""
        await self._send(
            pr.EV_CHAT_TTS_TEXT, {"start": start, "content": content, "end": end}
        )

    async def say_hello(self, content: str) -> None:
        await self._send(pr.EV_SAY_HELLO, {"content": content})

    async def end_asr(self) -> None:
        """push_to_talk 模式下声明本轮音频输入结束。"""
        await self._send(pr.EV_END_ASR)

    async def interrupt(self) -> None:
        """push_to_talk 模式下打断服务端响应。"""
        await self._send(pr.EV_CLIENT_INTERRUPT)

    async def update_config(self, payload: Dict[str, Any]) -> None:
        """通话中更新音色与人设，注意服务端按全量覆盖处理。"""
        await self._send(pr.EV_UPDATE_CONFIG, payload)

    async def finish_session(self) -> None:
        """结束会话。发送后服务端不再返回事件，WebSocket 可复用。"""
        if self.ws is None:
            return
        try:
            await self._send(pr.EV_FINISH_SESSION)
        except Exception as e:
            logger.bind(tag=TAG).warning(f"发送 FinishSession 失败: {e}")

    async def close(self) -> None:
        """按文档要求先 FinishConnection 再断开，避免 ContextCanceled。"""
        if self.ws is None:
            return
        ws, self.ws = self.ws, None
        try:
            await ws.send(pr.build_event(pr.EV_FINISH_CONNECTION))
        except Exception:
            pass
        try:
            await ws.close()
        except Exception:
            pass
        self.session_id = ""
