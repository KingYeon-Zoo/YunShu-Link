"""豆包端到端实时语音大模型接入（占用 ASR 槽位的编排器）。

为什么放在 ASR 槽位：设备侧协议完全不变，音频入口是 conn.asr.receive_audio，
音频出口是 conn.tts.tts_audio_queue。端到端模型把 ASR/LLM/TTS 合成一步，
因此由本 provider 接住音频流，再把模型返回的音频塞回原有播放队列，
sendAudioMessage 的流控、字幕、情绪消息、上报链路全部照旧复用。

配置端到端模式后 selected_module.LLM / TTS 不再参与实时链路，
但记忆总结、聊天标题等旁路仍会用到 LLM，保持原样配置即可。
"""

import asyncio
import json
import threading
import time
import uuid
from typing import TYPE_CHECKING, Any, Dict, List, Optional, Tuple

from config.logger import setup_logging
from core.providers.asr.base import ASRProviderBase
from core.providers.asr.dto.dto import InterfaceType
from core.providers.s2s import protocol as pr
from core.providers.s2s.client import DoubaoRealtimeClient, RealtimeSessionError
from core.providers.s2s.session_config import (
    PCM_SAMPLE_RATE,
    build_start_session_payload,
)
from core.providers.s2s.tool_bridge import DefaultAudioGate, ToolBridge
from core.providers.tts.dto.dto import SentenceType
from core.handle.reportHandle import enqueue_asr_report
from core.handle.sendAudioHandle import send_stt_message
from core.utils.dialogue import Message

if TYPE_CHECKING:
    from core.connection import ConnectionHandler

TAG = __name__
logger = setup_logging()


class ASRProvider(ASRProviderBase):
    def __init__(self, config: Dict[str, Any], delete_audio_file: bool):
        super().__init__()
        # 声明为流式，避免基类按 VAD 停顿切片调用 speech_to_text
        self.interface_type = InterfaceType.STREAM
        # 供上层识别端到端模式（文本 query 走 S2S 而非 LLM 链路）
        self.is_s2s = True
        self.config = config
        self.output_dir = config.get("output_dir", "tmp/")
        self.delete_audio_file = delete_audio_file

        self.client = DoubaoRealtimeClient(config)
        self.conn: Optional["ConnectionHandler"] = None
        self.recv_task: Optional[asyncio.Task] = None
        self.tool_bridge: Optional[ToolBridge] = None
        self.gate = DefaultAudioGate()
        self._decision_task: Optional[asyncio.Task] = None
        # 丢弃闲聊音频、改播工具结果时，要等工具那一轮音频结束再收尾
        self._await_tool_round = False
        self._tool_round_watchdog: Optional[asyncio.Task] = None

        # 会话状态
        self._session_ready = asyncio.Event()
        self._starting = False
        self._closed = False
        self._user_text = ""
        self._assistant_text = ""
        self._current_tts_type = ""
        self._sentence_started = False
        self._pending_user_audio: List[bytes] = []
        self._last_audio_send = 0.0
        self._resample_state = None

    # ------------------------------------------------------------------ 生命周期

    async def open_audio_channels(self, conn: "ConnectionHandler"):
        """接管音频通道：启动基类的音频消费线程，并建立端到端会话。"""
        self.conn = conn
        self.tool_bridge = ToolBridge(conn, self.config)
        await super().open_audio_channels(conn)
        asyncio.create_task(self._ensure_session())

    async def _ensure_session(self) -> bool:
        """建连 + StartSession，幂等。"""
        if self._session_ready.is_set():
            return True
        if self._closed:
            return False
        if self._starting:
            try:
                await asyncio.wait_for(self._session_ready.wait(), timeout=15)
                return self._session_ready.is_set()
            except asyncio.TimeoutError:
                return False

        self._starting = True
        try:
            await self.client.connect()
            payload = build_start_session_payload(
                self.config,
                prompt=self._resolve_prompt(),
                history=self._resolve_history(),
            )
            logger.bind(tag=TAG).info(
                f"端到端会话配置: {json.dumps(_redact(payload), ensure_ascii=False)}"
            )
            await self.client.start_session(payload)
            self.recv_task = asyncio.create_task(self._receive_loop())
            self._session_ready.set()
            await self._flush_pending_audio()
            return True
        except Exception as e:
            logger.bind(tag=TAG).error(f"端到端会话建立失败: {e}")
            await self.client.close()
            return False
        finally:
            self._starting = False

    def _resolve_prompt(self) -> str:
        """取当前设备的智能体提示词。控制台模式下已被私有配置覆盖。"""
        if self.conn is None:
            return ""
        return self.conn.config.get("prompt") or ""

    def _resolve_history(self) -> List[Dict[str, str]]:
        """把云枢已加载的记忆/历史转成 dialog_context 输入。"""
        if self.conn is None or not getattr(self.conn, "dialogue", None):
            return []
        history: List[Dict[str, str]] = []
        for msg in self.conn.dialogue.dialogue:
            if getattr(msg, "is_temporary", False):
                continue
            if msg.role in ("user", "assistant") and msg.content:
                history.append({"role": msg.role, "content": msg.content})
        return history

    # ------------------------------------------------------------------ 音频上行

    async def receive_audio(
        self, conn: "ConnectionHandler", pcm_frame: bytes, audio_have_voice: bool
    ):
        """把设备侧 16k PCM 直接转发给端到端模型。

        不调用父类实现：父类会按 VAD 停顿触发一次性识别，而端到端模型
        自带服务端 VAD，需要连续的音频流。
        """
        if self._closed or not pcm_frame:
            return

        if not self._session_ready.is_set():
            # 会话尚未就绪时缓存少量音频，避免开场丢字
            self._pending_user_audio.append(pcm_frame)
            if len(self._pending_user_audio) > 50:
                self._pending_user_audio = self._pending_user_audio[-50:]
            await self._ensure_session()
            return

        try:
            await self.client.send_audio(pcm_frame)
            self._last_audio_send = time.time()
        except Exception as e:
            logger.bind(tag=TAG).warning(f"上传音频失败: {e}")
            await self._handle_disconnect()

    async def _flush_pending_audio(self):
        if not self._pending_user_audio:
            return
        cached, self._pending_user_audio = self._pending_user_audio, []
        for frame in cached:
            try:
                await self.client.send_audio(frame)
            except Exception as e:
                logger.bind(tag=TAG).warning(f"补发缓存音频失败: {e}")
                return

    async def _send_stop_request(self):
        """listen stop：设备声明本轮说完。

        push_to_talk 模式下需要显式告知服务端；其余模式由服务端 VAD 判定，
        这里不做处理以免截断正常识别。
        """
        if not self._session_ready.is_set():
            return
        if self.config.get("input_mod") == "push_to_talk":
            try:
                await self.client.end_asr()
            except Exception as e:
                logger.bind(tag=TAG).warning(f"发送 EndASR 失败: {e}")

    def stop_ws_connection(self):
        # 端到端会话跨轮次复用，不在单轮结束时断开
        pass

    async def speech_to_text(self, opus_data, session_id, artifacts=None):
        # 端到端链路不存在独立的识别调用
        return "", None

    # ------------------------------------------------------------------ 事件下行

    async def _receive_loop(self):
        """消费服务端事件，翻译成设备侧协议。"""
        try:
            while not self._closed and self.client.is_open:
                frame = await self.client.recv()
                await self._dispatch(frame)
        except asyncio.CancelledError:
            raise
        except Exception as e:
            if not self._closed:
                logger.bind(tag=TAG).error(f"端到端事件循环异常: {e}")
                await self._handle_disconnect()

    async def _dispatch(self, frame: pr.ServerFrame):
        event = frame.event

        if event == pr.EV_TTS_RESPONSE:
            await self._on_audio_event(frame.audio)
        elif event == pr.EV_ASR_INFO:
            await self._on_user_speech_start()
        elif event == pr.EV_ASR_RESPONSE:
            self._on_asr_text(frame.payload)
        elif event == pr.EV_ASR_ENDED:
            await self._on_asr_ended()
        elif event == pr.EV_CHAT_RESPONSE:
            self._assistant_text += frame.payload.get("content") or ""
        elif event == pr.EV_TTS_SENTENCE_START:
            await self._on_sentence_start(frame.payload)
        elif event == pr.EV_TTS_ENDED:
            await self._on_round_end(frame.payload)
        elif event == pr.EV_CHAT_ENDED:
            pass
        elif event == pr.EV_USAGE_RESPONSE:
            logger.bind(tag=TAG).debug(f"用量: {frame.payload.get('usage')}")
        elif event in (pr.EV_SESSION_FAILED, pr.EV_CONNECTION_FAILED):
            logger.bind(tag=TAG).error(f"端到端会话失败: {frame.payload}")
            await self._handle_disconnect()
        elif event == pr.EV_DIALOG_COMMON_ERROR:
            logger.bind(tag=TAG).error(f"端到端对话错误: {frame.payload}")
            await self._finalize_round(interrupted=True)
        elif frame.error_code is not None:
            logger.bind(tag=TAG).error(
                f"端到端错误帧 code={frame.error_code}: {frame.payload}"
            )
            await self._handle_disconnect()

    async def _on_user_speech_start(self):
        """服务端识别到首字：打断设备正在播放的音频。"""
        conn = self.conn
        if conn is None:
            return
        # 新一轮用户输入到来，上一轮的闲聊闸门与工具等待一律作废
        self.reset_round_state()
        if conn.client_is_speaking:
            from core.handle.abortHandle import handleAbortMessage

            await handleAbortMessage(conn)

    async def abort_round(self):
        """设备主动打断：清理闸门，并在 push_to_talk 模式下通知服务端停嘴。"""
        self.reset_round_state()
        if (
            self._session_ready.is_set()
            and self.config.get("input_mod") == "push_to_talk"
        ):
            try:
                await self.client.interrupt()
            except Exception as e:
                logger.bind(tag=TAG).warning(f"发送 ClientInterrupt 失败: {e}")

    def reset_round_state(self):
        """打断或新一轮开始时清理本轮的闸门与待处理任务。"""
        self.gate.open_round(False)
        self._await_tool_round = False
        for task in (self._decision_task, self._tool_round_watchdog):
            if task and not task.done():
                task.cancel()
        self._decision_task = None
        self._tool_round_watchdog = None

    def _on_asr_text(self, payload: Dict[str, Any]):
        results = payload.get("results") or []
        for item in results:
            text = item.get("text") or ""
            if not text:
                continue
            # 非中间结果才作为最终用户文本
            if not item.get("is_interim"):
                self._user_text = text
            elif not self._user_text:
                self._user_text = text

    async def _on_asr_ended(self):
        """用户说完：下发字幕并开启新一轮播放。"""
        conn = self.conn
        if conn is None or not self._user_text:
            return

        conn.client_abort = False
        conn.sentence_id = uuid.uuid4().hex
        self._assistant_text = ""
        self._sentence_started = False

        logger.bind(tag=TAG).info(f"端到端识别: {self._user_text}")
        enqueue_asr_report(conn, self._user_text, [])
        await self._begin_round(self._user_text)

    async def _begin_round(self, user_text: str):
        """本轮开始：写对话历史、下发字幕、开启工具闸门。

        语音输入（ASREnded）与文本输入（ChatTextQuery）共用这段逻辑。
        """
        conn = self.conn
        if conn is None:
            return
        conn.dialogue.put(Message(role="user", content=user_text))
        # 复用既有链路：下发 type=stt 字幕并把设备切到 speaking 状态
        await send_stt_message(conn, user_text)

        # 开闸：需要工具路由时先缓存模型的闲聊音频，等判定结果
        routing = self.tool_bridge is not None and self.tool_bridge.available()
        self.gate.open_round(
            routing, timeout=float(self.config.get("tool_decision_timeout", 2.5))
        )
        if routing:
            self._decision_task = asyncio.create_task(
                self._run_tool_decision(user_text)
            )

    async def _run_tool_decision(self, user_text: str):
        """执行工具路由，并据结果决定闲聊音频的去留。"""
        decision = await self.tool_bridge.decide(user_text)
        conn = self.conn
        if conn is None or conn.client_abort:
            return

        if not decision.use_tool:
            await self._release_default_audio()
            return

        # 命中工具：丢掉模型自己的闲聊音频，改播工具结果。
        # 工具那一路音频会以新的 tts_type 到来，所以要压住本轮的收尾动作，
        # 否则设备会先收到 tts stop 提前退出播放态。
        self.gate.discard()
        self._assistant_text = ""
        sent = False
        if decision.direct_text:
            sent = await self.speak_text(decision.direct_text)
        elif decision.rag_text:
            sent = await self.inject_rag(decision.rag_text)
        else:
            # 工具自行接管了播放（如播放音乐、退出对话）
            logger.bind(tag=TAG).debug("工具已自行处理本轮响应")
            self._await_tool_round = False
            return

        if sent:
            self._await_tool_round = True
            self._tool_round_watchdog = asyncio.create_task(
                self._watch_tool_round()
            )
        else:
            # 注入失败，退回闲聊音频（此时缓存已丢弃，至少保证会话不卡死）
            self._await_tool_round = False
            await self._finalize_round()

    async def _watch_tool_round(self):
        """工具结果迟迟不来时兜底收尾，避免设备停在播放态。"""
        try:
            await asyncio.sleep(float(self.config.get("tool_round_timeout", 15)))
        except asyncio.CancelledError:
            return
        if self._await_tool_round:
            logger.bind(tag=TAG).warning("工具结果音频超时，强制结束本轮")
            self._await_tool_round = False
            await self._finalize_round()

    async def _release_default_audio(self):
        """按"不调工具"放行：补发字幕与缓存的闲聊音频。"""
        conn = self.conn
        if conn is None:
            return
        buffered = self.gate.release()
        subtitle = self.gate.take_subtitle()
        if subtitle is not None:
            sentence_type, text = subtitle
            conn.tts.tts_audio_queue.put(
                (sentence_type, [], text, conn.sentence_id)
            )
        for audio in buffered:
            self._encode_and_enqueue(audio)

    async def _on_sentence_start(self, payload: Dict[str, Any]):
        """一句音频开始，携带该句文本，用于字幕与情绪消息。"""
        conn = self.conn
        if conn is None:
            return
        self._current_tts_type = payload.get("tts_type") or "default"
        text = payload.get("text") or ""
        if not text:
            return
        if self._current_tts_type == "network":
            logger.bind(tag=TAG).info("本轮回复来自内置联网搜索")

        sentence_type = (
            SentenceType.FIRST if not self._sentence_started else SentenceType.MIDDLE
        )
        is_chitchat = self._current_tts_type == "default"

        # 闲聊字幕先扣住，等工具判定；工具结果的字幕直接下发
        if is_chitchat and self.gate.pending:
            self.gate.hold_subtitle(sentence_type, text)
            return
        if is_chitchat and self.gate.suppress:
            return

        self._sentence_started = True
        # 走原有播放队列：FIRST 会触发 sentence_start 字幕与情绪消息
        conn.tts.tts_audio_queue.put((sentence_type, [], text, conn.sentence_id))

    async def _on_audio_event(self, audio: Optional[bytes]):
        """模型音频（24k PCM）编码为 Opus 后进入设备播放队列。"""
        conn = self.conn
        if conn is None or not audio or conn.client_abort:
            return

        if self._current_tts_type == "default":
            if self.gate.suppress:
                return
            if self.gate.pending:
                # 判定超时就不再等，直接放行，避免可感知的静默
                if self.gate.expired():
                    await self._release_default_audio()
                elif self.gate.buffer(audio):
                    return
                else:
                    # 缓存满了同样放行，防止内存无界增长
                    await self._release_default_audio()

        self._encode_and_enqueue(audio)

    def _encode_and_enqueue(self, audio: bytes):
        conn = self.conn
        encoder = getattr(conn.tts, "opus_encoder", None) if conn else None
        if encoder is None:
            return
        try:
            encoder.encode_pcm_to_opus_stream(
                self._match_device_rate(audio),
                end_of_stream=False,
                callback=conn.tts.handle_opus,
            )
        except Exception as e:
            logger.bind(tag=TAG).warning(f"Opus 编码失败: {e}")

    def _match_device_rate(self, pcm: bytes) -> bytes:
        """端到端模型固定输出 24k，设备协商了别的采样率时做一次重采样。

        Opus 编码器是按 conn.sample_rate 建的，直接喂 24k 数据会变调。
        """
        target = getattr(self.conn, "sample_rate", PCM_SAMPLE_RATE)
        if target == PCM_SAMPLE_RATE:
            return pcm
        try:
            import audioop

            converted, self._resample_state = audioop.ratecv(
                pcm, 2, 1, PCM_SAMPLE_RATE, target, self._resample_state
            )
            return converted
        except Exception as e:
            logger.bind(tag=TAG).warning(f"重采样到 {target}Hz 失败: {e}")
            return pcm

    async def _on_round_end(self, payload: Dict[str, Any]):
        """一轮音频播放结束。status_code 命中退出意图时结束连接。"""
        user_exit = str(payload.get("status_code") or "") == pr.STATUS_USER_EXIT

        # 闲聊那一轮已被丢弃、正在等工具结果音频：跳过这次收尾
        if self._await_tool_round:
            self._await_tool_round = False
            return

        if self._tool_round_watchdog and not self._tool_round_watchdog.done():
            self._tool_round_watchdog.cancel()
        await self._finalize_round()
        if user_exit:
            conn = self.conn
            if conn is not None:
                logger.bind(tag=TAG).info("模型识别到用户退出意图，准备关闭连接")
                conn.close_after_chat = True

    async def _finalize_round(self, interrupted: bool = False):
        conn = self.conn
        if conn is None:
            return

        # 模型这一轮已经说完，但工具判定还没回来：不能再等，放行闲聊音频
        if self.gate.pending and not interrupted:
            await self._release_default_audio()

        encoder = getattr(conn.tts, "opus_encoder", None)
        if encoder is not None and not interrupted:
            try:
                encoder.encode_pcm_to_opus_stream(
                    b"", end_of_stream=True, callback=conn.tts.handle_opus
                )
            except Exception as e:
                logger.bind(tag=TAG).debug(f"冲刷 Opus 编码器失败: {e}")

        if self._assistant_text:
            conn.dialogue.put(Message(role="assistant", content=self._assistant_text))

        # LAST 触发 tts stop，设备退出播放态
        conn.tts.tts_audio_queue.put(
            (SentenceType.LAST, [], self._assistant_text or None, conn.sentence_id)
        )
        self._user_text = ""
        self._sentence_started = False

    async def _handle_disconnect(self):
        """连接异常：清理会话状态，下一次有声音时自动重连。"""
        if self._closed:
            return
        self._session_ready.clear()
        if self.recv_task and self.recv_task is not asyncio.current_task():
            self.recv_task.cancel()
        await self.client.close()

    # ------------------------------------------------------------------ 外部注入

    async def inject_rag(self, text: str) -> bool:
        """把外部知识交给模型总结播报，替代本轮闲聊结果。"""
        if not self._session_ready.is_set() or not text:
            return False
        try:
            await self.client.send_rag_text(text[:4000])
            return True
        except Exception as e:
            logger.bind(tag=TAG).warning(f"注入 RAG 文本失败: {e}")
            return False

    async def speak_text(self, text: str) -> bool:
        """指定文本直接合成，跳过模型生成。须在 ASREnded 之后调用。"""
        if not self._session_ready.is_set() or not text:
            return False
        try:
            await self.client.send_tts_text(text, start=True, end=False)
            await self.client.send_tts_text("", start=False, end=True)
            return True
        except Exception as e:
            logger.bind(tag=TAG).warning(f"下发合成文本失败: {e}")
            return False

    async def send_text_query(self, text: str) -> bool:
        """以文本发起一轮对话（设备端 detect/唤醒词文本走这条路）。

        文本 query 不会触发 ASRInfo/ASREnded，所以本轮的字幕、sentence_id
        与工具闸门都要在这里自己准备好。
        """
        if not text or not await self._ensure_session():
            return False

        conn = self.conn
        if conn is None:
            return False
        try:
            await self.client.send_text_query(text)
        except Exception as e:
            logger.bind(tag=TAG).warning(f"发送文本 query 失败: {e}")
            return False

        self.reset_round_state()
        conn.client_abort = False
        conn.sentence_id = uuid.uuid4().hex
        self._user_text = text
        self._assistant_text = ""
        self._sentence_started = False
        await self._begin_round(text)
        return True

    async def update_persona(self, prompt: str = "", speaker: str = "") -> bool:
        """通话中切换人设或音色。服务端按全量覆盖，需带齐字段。"""
        if not self._session_ready.is_set():
            return False
        payload = build_start_session_payload(
            self.config,
            prompt=prompt or self._resolve_prompt(),
            dialog_id=self.client.dialog_id,
        )
        update: Dict[str, Any] = {
            "tts": {
                "speaker": speaker or payload["tts"]["speaker"],
                "audio_config": payload["tts"]["audio_config"],
            },
            "dialog": {
                k: v
                for k, v in payload["dialog"].items()
                if k in ("bot_name", "system_role", "speaking_style", "dialog_id")
            },
        }
        try:
            await self.client.update_config(update)
            return True
        except Exception as e:
            logger.bind(tag=TAG).warning(f"更新人设失败: {e}")
            return False


    async def close(self):
        self._closed = True
        if self.recv_task and not self.recv_task.done():
            self.recv_task.cancel()
        if self.tool_bridge is not None:
            await self.tool_bridge.close()
        try:
            await self.client.finish_session()
        except Exception:
            pass
        await self.client.close()


def _redact(payload: Dict[str, Any]) -> Dict[str, Any]:
    """日志脱敏：搜索密钥不落日志。"""
    import copy

    safe = copy.deepcopy(payload)
    extra = safe.get("dialog", {}).get("extra", {})
    for key in ("volc_websearch_api_key", "volc_websearch_bot_id"):
        if extra.get(key):
            extra[key] = "***"
    return safe
