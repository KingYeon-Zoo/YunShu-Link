"""把云枢的智能体配置翻译成 StartSession 事件的 payload。

关键约束（来自接口文档，踩错就直接报 42000020）：
- asr.extra 与 tts.extra 不能为空对象缺失，必须存在。
- dialog.extra.model 必传：O2.0 用 1.2.1.1，SC2.0 用 2.2.0.0。
- O 系列人设走 bot_name/system_role/speaking_style；SC 系列走 character_manifest，
  两套字段不通用，配错版本会静默失效。
- 音色与版本必须匹配，否则报 ClientError:InvalidSpeaker：
  saturn_/S_ 开头是 SC2.0 克隆音色，精品音色（vv 等）只在 O 系列生效。
- 联网搜索的 volc_websearch_api_key 必填，web_agent 还要 volc_websearch_bot_id。
"""

from typing import Any, Dict, List, Optional

from core.providers.s2s.client import MODEL_O2, MODEL_SC2

# 服务端默认音色
DEFAULT_SPEAKER = "zh_female_vv_jupiter_bigtts"

# 我们输出给设备的音频规格：单声道 24k int16 小端，与 xiaozhi.audio_params 对齐，
# 便于直接 Opus 编码后下发，无需重采样。
PCM_FORMAT = "pcm_s16le"
PCM_SAMPLE_RATE = 24000

_SC_SPEAKER_PREFIXES = ("saturn_", "S_", "ICL_")


def resolve_model(config: Dict[str, Any]) -> str:
    """确定端到端模型版本。显式配置优先，否则按音色前缀推断。"""
    model = str(config.get("model") or "").strip()
    if model:
        return model
    speaker = str(config.get("speaker") or "")
    if speaker.startswith(_SC_SPEAKER_PREFIXES):
        return MODEL_SC2
    return MODEL_O2


def is_sc_model(model: str) -> bool:
    return model == MODEL_SC2


def _clean(value: Any) -> str:
    """清掉会让服务端 YAML 解析失败的字符（见错误码 50000000）。"""
    if not value:
        return ""
    return str(value).replace("\x00", "").strip()


def build_dialog_context(
    history: Optional[List[Dict[str, str]]], limit: int = 20
) -> List[Dict[str, Any]]:
    """把对话历史整理成 dialog_context。

    服务端要求严格的 user/assistant 交替、数组长度为偶数，最多 20 轮。
    这里只保留成对的 QA，落单的消息直接丢弃而不是补空串。
    """
    if not history:
        return []

    pairs: List[Dict[str, Any]] = []
    pending: Optional[Dict[str, str]] = None
    for msg in history:
        role = msg.get("role")
        text = _clean(msg.get("content"))
        if role not in ("user", "assistant") or not text:
            continue
        if role == "user":
            pending = {"role": "user", "text": text}
        elif pending is not None:
            pairs.append(pending)
            pairs.append({"role": "assistant", "text": text})
            pending = None

    # 只保留最近 limit 轮（每轮两条）
    if len(pairs) > limit * 2:
        pairs = pairs[-limit * 2 :]
    return pairs


def build_start_session_payload(
    config: Dict[str, Any],
    prompt: str = "",
    dialog_id: str = "",
    history: Optional[List[Dict[str, str]]] = None,
) -> Dict[str, Any]:
    """构造 StartSession payload。

    Args:
        config: 端到端 provider 的配置段。
        prompt: 云枢智能体的系统提示词，按模型版本落到对应字段。
        dialog_id: 续接历史对话用；为空则服务端新建。
        history: 云枢侧已有的对话历史，用于初始化上下文。
    """
    model = resolve_model(config)
    speaker = _clean(config.get("speaker")) or DEFAULT_SPEAKER

    dialog: Dict[str, Any] = {"dialog_id": dialog_id or ""}

    prompt = _clean(prompt)
    if is_sc_model(model):
        # SC 系列：整段人设走 character_manifest。官方克隆音色（ICL_/saturn_ 结尾 _tob）
        # 服务端已内置角色描述，此时不要覆盖。
        manifest = _clean(config.get("character_manifest")) or prompt
        if manifest and not speaker.endswith("_tob"):
            dialog["character_manifest"] = manifest
    else:
        # O 系列：人设拆成三段，bot_name 限 20 字符。
        bot_name = _clean(config.get("bot_name"))
        if bot_name:
            dialog["bot_name"] = bot_name[:20]
        system_role = _clean(config.get("system_role")) or prompt
        if system_role:
            dialog["system_role"] = system_role
        speaking_style = _clean(config.get("speaking_style"))
        if speaking_style:
            dialog["speaking_style"] = speaking_style

    context = build_dialog_context(history)
    if context:
        dialog["dialog_context"] = context

    location = config.get("location")
    if isinstance(location, dict) and location:
        dialog["location"] = location

    extra: Dict[str, Any] = {"model": model}

    # 输入模式：设备侧是流式麦克风，静音时无法上传，用 keep_alive 避免
    # 52000042 DialogAudioIdleTimeoutError。
    extra["input_mod"] = _clean(config.get("input_mod")) or "keep_alive"

    if config.get("strict_audit") is not None:
        extra["strict_audit"] = bool(config["strict_audit"])
    audit_response = _clean(config.get("audit_response"))
    if audit_response:
        extra["audit_response"] = audit_response

    # 内置联网搜索
    if config.get("enable_websearch"):
        search_type = _clean(config.get("websearch_type")) or "web"
        extra["enable_volc_websearch"] = True
        extra["volc_websearch_type"] = search_type
        api_key = _clean(config.get("websearch_api_key"))
        if api_key:
            extra["volc_websearch_api_key"] = api_key
        if search_type == "web_agent":
            bot_id = _clean(config.get("websearch_bot_id"))
            if bot_id:
                extra["volc_websearch_bot_id"] = bot_id
        count = config.get("websearch_result_count")
        if count:
            extra["volc_websearch_result_count"] = min(int(count), 10)
        no_result = _clean(config.get("websearch_no_result_message"))
        if no_result:
            extra["volc_websearch_no_result_message"] = no_result

    # 唱歌只在 O2.0 生效，配到 SC2.0 会直接报 42000020。
    if config.get("enable_music") and model == MODEL_O2:
        extra["enable_music"] = True

    if config.get("enable_loudness_norm"):
        extra["enable_loudness_norm"] = True
    # 打开后 TTSEnded 会带 status_code=20000002 表示用户想结束对话。
    extra["enable_user_query_exit"] = bool(config.get("enable_user_query_exit", True))

    dialog["extra"] = extra

    # asr.extra 必须存在。end_smooth_window_ms 控制判定用户说完话的静音窗口。
    asr_extra: Dict[str, Any] = {}
    window = config.get("end_smooth_window_ms")
    if window:
        asr_extra["end_smooth_window_ms"] = max(500, min(int(window), 50000))
    hotwords = config.get("hotwords") or []
    correct_words = config.get("correct_words") or {}
    if hotwords or correct_words:
        context_cfg: Dict[str, Any] = {}
        if hotwords:
            context_cfg["hotwords"] = [
                {"word": _clean(w)} for w in hotwords if _clean(w)
            ]
            # 热词依赖非流式二遍识别
            asr_extra["enable_asr_twopass"] = True
        if correct_words:
            context_cfg["correct_words"] = correct_words
        asr_extra["context"] = context_cfg

    tts_extra: Dict[str, Any] = {}
    dialect = _clean(config.get("explicit_dialect"))
    if dialect:
        tts_extra["explicit_dialect"] = dialect

    audio_config: Dict[str, Any] = {
        "channel": 1,
        "format": PCM_FORMAT,
        "sample_rate": PCM_SAMPLE_RATE,
    }
    for key in ("speech_rate", "loudness_rate"):
        if config.get(key) is not None:
            audio_config[key] = max(-50, min(int(config[key]), 100))

    return {
        "asr": {"extra": asr_extra},
        "tts": {
            "speaker": speaker,
            "audio_config": audio_config,
            "extra": tts_extra,
        },
        "dialog": dialog,
    }
