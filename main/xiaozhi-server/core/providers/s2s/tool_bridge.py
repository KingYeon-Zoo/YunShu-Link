"""端到端模型的工具调用桥接。

端到端模型本身不支持 function_call，所以这里用一个旁路 LLM 做工具路由：
用户文本 → 旁路 LLM 判断是否要调工具 → 执行 → 结果用 ChatRAGText 注入，
由端到端模型自己总结并用当前音色播报，人设与音色都不会断。

时序上有一个固有竞态：ASREnded 之后端到端模型会立刻开始生成闲聊音频，
而工具路由需要几百毫秒。处理办法是先缓存模型的闲聊音频（tts_type=default）
不下发，等路由出结果：
- 判定要调工具 → 丢掉缓存的闲聊音频，播报 external_rag 的总结结果
- 判定不调工具（或超时/失败）→ 冲刷缓存音频，正常播报闲聊结果

缓存有上限与截止时间，超时一律按"不调工具"放行，保证不会把用户吊死。
"""

import asyncio
import json
import time
from typing import Any, Dict, List, Optional, Tuple

from config.logger import setup_logging
from plugins_func.register import Action

TAG = __name__
logger = setup_logging()

# 路由判定的截止时间：超过就放行闲聊音频，避免可感知的静默
DECISION_TIMEOUT = 2.5
# 缓存的闲聊音频上限（24k/int16/单声道 ≈ 48KB/s，约 3 秒）
MAX_BUFFERED_BYTES = 48000 * 3

ROUTER_SYSTEM_PROMPT = """你是语音助手的工具路由器。根据用户的话判断是否需要调用工具。

规则：
- 需要实时信息、设备控制、播放音乐、查询天气或新闻、退出对话时，调用对应工具。
- 普通闲聊、情感交流、知识问答、角色扮演对话，一律不要调用任何工具。
- 只输出工具调用，不要输出任何解释性文字。
- 不确定时不要调用工具。"""


class ToolDecision:
    """路由结果。"""

    __slots__ = ("use_tool", "rag_text", "action", "direct_text")

    def __init__(
        self,
        use_tool: bool = False,
        rag_text: str = "",
        action: Optional[Action] = None,
        direct_text: str = "",
    ):
        self.use_tool = use_tool
        self.rag_text = rag_text
        self.action = action
        self.direct_text = direct_text


class ToolBridge:
    def __init__(self, conn, config: Dict[str, Any]):
        self.conn = conn
        self.enabled = bool(config.get("enable_tools", True))
        self.timeout = float(config.get("tool_decision_timeout", DECISION_TIMEOUT))
        self._task: Optional[asyncio.Task] = None

    # ---------------------------------------------------------------- 工具描述

    def _tools(self) -> List[Dict[str, Any]]:
        handler = getattr(self.conn, "func_handler", None)
        if handler is None:
            return []
        try:
            tools = handler.get_functions() or []
        except Exception as e:
            logger.bind(tag=TAG).warning(f"获取工具列表失败: {e}")
            return []
        # direct_answer 是为文本链路准备的"不调工具"占位，端到端链路不需要
        return [
            t
            for t in tools
            if t.get("function", {}).get("name") != "direct_answer"
        ]

    def available(self) -> bool:
        return self.enabled and bool(self._tools()) and self.conn.llm is not None

    # ---------------------------------------------------------------- 路由

    async def decide(self, user_text: str) -> ToolDecision:
        """判断并执行工具调用，返回可注入的结果。"""
        if not user_text or not self.available():
            return ToolDecision()
        try:
            return await asyncio.wait_for(
                self._route(user_text), timeout=self.timeout
            )
        except asyncio.TimeoutError:
            logger.bind(tag=TAG).info("工具路由超时，按闲聊处理")
            return ToolDecision()
        except Exception as e:
            logger.bind(tag=TAG).warning(f"工具路由失败: {e}")
            return ToolDecision()

    async def _route(self, user_text: str) -> ToolDecision:
        call = await asyncio.to_thread(self._ask_router, user_text)
        if call is None:
            return ToolDecision()

        name, arguments = call
        logger.bind(tag=TAG).info(f"端到端链路命中工具: {name} {arguments}")

        handler = self.conn.func_handler
        result = await handler.handle_llm_function_call(
            self.conn, {"name": name, "arguments": arguments}
        )
        if result is None:
            return ToolDecision()

        # SYSTEM_CTL 之类的工具会自己接管播放/退出流程，这里不再注入
        if result.action == Action.NONE:
            return ToolDecision(use_tool=True, action=result.action)
        if result.action == Action.ERROR:
            logger.bind(tag=TAG).warning(f"工具执行失败: {result.response}")
            return ToolDecision()

        payload = result.response or result.result or ""
        if not payload:
            return ToolDecision(use_tool=True, action=result.action)

        # RESPONSE：内容已经是给用户的话，直接让模型照读
        if result.action == Action.RESPONSE:
            return ToolDecision(
                use_tool=True, action=result.action, direct_text=str(payload)
            )

        # REQLLM / RECORD：作为外部知识交给模型总结
        rag = json.dumps(
            [{"title": name, "content": str(payload)}], ensure_ascii=False
        )
        return ToolDecision(use_tool=True, rag_text=rag, action=result.action)

    def _ask_router(self, user_text: str) -> Optional[Tuple[str, Any]]:
        """用旁路 LLM 做一次 function_call 判断（同步，跑在线程池里）。"""
        dialogue = [
            {"role": "system", "content": ROUTER_SYSTEM_PROMPT},
            {"role": "user", "content": user_text},
        ]
        tools = self._tools()
        name: Optional[str] = None
        arguments = ""
        try:
            for _, tool_calls in self.conn.llm.response_with_functions(
                self.conn.session_id, dialogue, functions=tools
            ):
                if not tool_calls:
                    continue
                for tc in tool_calls:
                    func = tc.get("function") or {}
                    if func.get("name"):
                        name = func["name"]
                    if func.get("arguments"):
                        arguments += func["arguments"]
        except Exception as e:
            logger.bind(tag=TAG).warning(f"旁路 LLM 路由异常: {e}")
            return None

        if not name:
            return None
        return name, arguments or {}

    async def close(self):
        if self._task and not self._task.done():
            self._task.cancel()


class DefaultAudioGate:
    """闲聊音频的缓存闸门，等工具路由出结果再决定放行还是丢弃。"""

    def __init__(self):
        self.pending = False
        self.suppress = False
        self._buffer: List[bytes] = []
        self._buffered_bytes = 0
        self._deadline = 0.0
        self._subtitle: Optional[Tuple[Any, str]] = None

    def open_round(self, pending: bool, timeout: float = DECISION_TIMEOUT):
        self.pending = pending
        self.suppress = False
        self._buffer = []
        self._buffered_bytes = 0
        self._deadline = time.time() + timeout if pending else 0.0
        self._subtitle = None

    def expired(self) -> bool:
        return self.pending and time.time() > self._deadline

    def hold_subtitle(self, sentence_type: Any, text: str):
        self._subtitle = (sentence_type, text)

    def take_subtitle(self) -> Optional[Tuple[Any, str]]:
        subtitle, self._subtitle = self._subtitle, None
        return subtitle

    def buffer(self, audio: bytes) -> bool:
        """缓存一帧闲聊音频。返回 False 表示缓存已满，应直接放行。"""
        if self._buffered_bytes >= MAX_BUFFERED_BYTES:
            return False
        self._buffer.append(audio)
        self._buffered_bytes += len(audio)
        return True

    def release(self) -> List[bytes]:
        """按"不调工具"放行：吐出缓存音频。"""
        self.pending = False
        self.suppress = False
        buffered, self._buffer = self._buffer, []
        self._buffered_bytes = 0
        return buffered

    def discard(self):
        """按"要调工具"处理：丢掉闲聊音频，后续 default 音频一律不播。"""
        self.pending = False
        self.suppress = True
        self._buffer = []
        self._buffered_bytes = 0
        self._subtitle = None
