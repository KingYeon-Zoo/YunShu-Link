"""豆包端到端实时语音大模型（RealtimeAPI）二进制协议编解码。

帧结构：4 字节 header + optional + payload size(4B) + payload。
header：
  byte0 = (protocol_version << 4) | header_size      固定 0x11
  byte1 = (message_type << 4) | flags
  byte2 = (serialization << 4) | compression
  byte3 = 0x00 保留
optional 按固定顺序组装：code(仅错误帧) → sequence → event → connect_id → session_id。
本模块只使用 event flag，不使用 sequence，压缩固定为无压缩。
"""

import json
from typing import Any, Dict, Optional, Tuple

PROTOCOL_HEADER = 0x11

# Message Type
MSG_FULL_CLIENT = 0b0001
MSG_FULL_SERVER = 0b1001
MSG_AUDIO_CLIENT = 0b0010
MSG_AUDIO_SERVER = 0b1011
MSG_ERROR = 0b1111

# Message type specific flags
FLAG_EVENT = 0b0100

# Serialization / Compression
SER_RAW = 0b0000
SER_JSON = 0b0001
COMPRESS_NONE = 0b0000

# 客户端事件
EV_START_CONNECTION = 1
EV_FINISH_CONNECTION = 2
EV_START_SESSION = 100
EV_FINISH_SESSION = 102
EV_TASK_REQUEST = 200
EV_UPDATE_CONFIG = 201
EV_SAY_HELLO = 300
EV_END_ASR = 400
EV_CHAT_TTS_TEXT = 500
EV_CHAT_TEXT_QUERY = 501
EV_CHAT_RAG_TEXT = 502
EV_CLIENT_INTERRUPT = 515

# 服务端事件
EV_CONNECTION_STARTED = 50
EV_CONNECTION_FAILED = 51
EV_CONNECTION_FINISHED = 52
EV_SESSION_STARTED = 150
EV_SESSION_FINISHED = 152
EV_SESSION_FAILED = 153
EV_USAGE_RESPONSE = 154
EV_CONFIG_UPDATED = 251
EV_TTS_SENTENCE_START = 350
EV_TTS_SENTENCE_END = 351
EV_TTS_RESPONSE = 352
EV_TTS_ENDED = 359
EV_ASR_INFO = 450
EV_ASR_RESPONSE = 451
EV_ASR_ENDED = 459
EV_CHAT_RESPONSE = 550
EV_CHAT_TEXT_QUERY_CONFIRMED = 553
EV_CHAT_ENDED = 559
EV_DIALOG_COMMON_ERROR = 599

# Connect 级事件不携带 session id
CONNECT_LEVEL_EVENTS = frozenset(
    {
        EV_START_CONNECTION,
        EV_FINISH_CONNECTION,
        EV_CONNECTION_STARTED,
        EV_CONNECTION_FAILED,
        EV_CONNECTION_FINISHED,
    }
)

# 用户主动退出意图，随 TTSEnded 事件下发
STATUS_USER_EXIT = "20000002"


class ServerFrame:
    """解析后的服务端帧。"""

    __slots__ = ("event", "session_id", "payload", "audio", "error_code")

    def __init__(
        self,
        event: Optional[int] = None,
        session_id: str = "",
        payload: Optional[Dict[str, Any]] = None,
        audio: Optional[bytes] = None,
        error_code: Optional[int] = None,
    ):
        self.event = event
        self.session_id = session_id
        self.payload = payload or {}
        self.audio = audio
        self.error_code = error_code

    def __repr__(self) -> str:
        if self.audio is not None:
            return f"ServerFrame(event={self.event}, audio={len(self.audio)}B)"
        return f"ServerFrame(event={self.event}, payload={self.payload})"


def _build(
    message_type: int,
    serialization: int,
    event: int,
    payload: bytes,
    session_id: Optional[str] = None,
) -> bytes:
    frame = bytearray(
        [
            PROTOCOL_HEADER,
            (message_type << 4) | FLAG_EVENT,
            (serialization << 4) | COMPRESS_NONE,
            0x00,
        ]
    )
    frame.extend(event.to_bytes(4, "big"))
    if session_id is not None:
        sid = session_id.encode("utf-8")
        frame.extend(len(sid).to_bytes(4, "big"))
        frame.extend(sid)
    frame.extend(len(payload).to_bytes(4, "big"))
    frame.extend(payload)
    return bytes(frame)


def build_event(
    event: int, payload: Optional[Dict[str, Any]] = None, session_id: Optional[str] = None
) -> bytes:
    """构造 JSON 文本事件帧。payload 为 None 时发送空对象 {}。"""
    raw = json.dumps(
        payload if payload is not None else {},
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    if event in CONNECT_LEVEL_EVENTS:
        session_id = None
    return _build(MSG_FULL_CLIENT, SER_JSON, event, raw, session_id)


def build_audio(pcm: bytes, session_id: str) -> bytes:
    """构造 TaskRequest 音频帧，payload 为裸 PCM 二进制。"""
    return _build(MSG_AUDIO_CLIENT, SER_RAW, EV_TASK_REQUEST, pcm, session_id)


def _read_u32(data: bytes, offset: int) -> Tuple[int, int]:
    return int.from_bytes(data[offset : offset + 4], "big"), offset + 4


def parse_frame(data: bytes) -> ServerFrame:
    """解析服务端帧。音频帧的 payload 放在 audio 字段，其余放在 payload。"""
    if len(data) < 4:
        raise ValueError(f"帧长度不足: {len(data)}")

    header_size = (data[0] & 0x0F) * 4
    message_type = data[1] >> 4
    flags = data[1] & 0x0F
    serialization = data[2] >> 4

    offset = header_size
    error_code = None
    event = None

    if message_type == MSG_ERROR:
        error_code, offset = _read_u32(data, offset)
    elif flags & FLAG_EVENT:
        event, offset = _read_u32(data, offset)

    session_id = ""
    if event is not None and event not in CONNECT_LEVEL_EVENTS:
        sid_size, offset = _read_u32(data, offset)
        if sid_size:
            session_id = data[offset : offset + sid_size].decode("utf-8", "ignore")
            offset += sid_size

    payload_size, offset = _read_u32(data, offset)
    raw = data[offset : offset + payload_size]

    if message_type == MSG_AUDIO_SERVER or serialization == SER_RAW:
        if message_type == MSG_AUDIO_SERVER:
            return ServerFrame(event=event, session_id=session_id, audio=raw)

    payload: Dict[str, Any] = {}
    if raw:
        try:
            decoded = json.loads(raw.decode("utf-8"))
            payload = decoded if isinstance(decoded, dict) else {"data": decoded}
        except (UnicodeDecodeError, json.JSONDecodeError):
            payload = {"raw": raw.hex()}

    return ServerFrame(
        event=event, session_id=session_id, payload=payload, error_code=error_code
    )
