import json
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from core.connection import ConnectionHandler

TAG = __name__
EMOJI_MAP = {
    "😂": "funny",
    "😭": "crying",
    "😠": "angry",
    "😔": "sad",
    "😍": "loving",
    "😲": "surprised",
    "😱": "shocked",
    "🤔": "thinking",
    "😌": "relaxed",
    "😴": "sleepy",
    "😜": "silly",
    "🙄": "confused",
    "😶": "neutral",
    "🙂": "happy",
    "😆": "laughing",
    "😳": "embarrassed",
    "😉": "winking",
    "😎": "cool",
    "🤤": "delicious",
    "😘": "kissy",
    "😏": "confident",
}
EMOJI_RANGES = [
    (0x1F600, 0x1F64F),
    (0x1F300, 0x1F5FF),
    (0x1F680, 0x1F6FF),
    (0x1F900, 0x1F9FF),
    (0x1FA70, 0x1FAFF),
    (0x2600, 0x26FF),
    (0x2700, 0x27BF),
]

# 当模型没有严格按提示词输出 emoji 时，由服务端根据回复语义选择情绪，
# 确保设备表现不依赖具体模型的指令遵循能力。顺序代表匹配优先级。
EMOTION_KEYWORDS = [
    ("sleepy", "😴", ("晚安", "睡觉", "睡眠", "困了", "好困", "休息")),
    ("crying", "😭", ("哭了", "哭泣", "流泪")),
    ("sad", "😔", ("抱歉", "遗憾", "难过", "伤心", "可惜")),
    ("angry", "😠", ("生气", "愤怒", "恼火", "讨厌")),
    ("shocked", "😱", ("震惊", "吓一跳", "太吓人")),
    ("surprised", "😲", ("惊讶", "没想到", "竟然", "居然", "哇")),
    ("thinking", "🤔", ("想一想", "想想", "思考", "分析", "让我看看")),
    ("confused", "🙄", ("困惑", "疑惑", "不确定", "不太明白")),
    ("loving", "😍", ("喜欢你", "爱你", "真棒", "太棒了")),
    ("laughing", "😆", ("哈哈", "好笑", "笑死")),
    ("happy", "🙂", ("好的", "当然", "可以", "没问题", "太好了", "恭喜", "开心")),
]


def get_string_no_punctuation_or_emoji(s):
    """去除字符串首尾的空格、标点符号和表情符号"""
    chars = list(s)
    # 处理开头的字符
    start = 0
    while start < len(chars) and is_punctuation_or_emoji(chars[start]):
        start += 1
    # 处理结尾的字符
    end = len(chars) - 1
    while end >= start and is_punctuation_or_emoji(chars[end]):
        end -= 1
    return "".join(chars[start : end + 1])


def is_punctuation_or_emoji(char):
    """检查字符是否为空格、指定标点或表情符号"""
    # 定义需要去除的中英文标点（包括全角/半角）
    punctuation_set = {
        "，",
        ",",  # 中文逗号 + 英文逗号
        "。",
        ".",  # 中文句号 + 英文句号
        "！",
        "!",  # 中文感叹号 + 英文感叹号
        "“",
        "”",
        '"',  # 中文双引号 + 英文引号
        "：",
        ":",  # 中文冒号 + 英文冒号
        "-",
        "－",  # 英文连字符 + 中文全角横线
        "、",  # 中文顿号
        "[",
        "]",  # 方括号
        "【",
        "】",  # 中文方括号
    }
    if char.isspace() or char in punctuation_set:
        return True
    return is_emoji(char)


async def get_emotion(conn: "ConnectionHandler", text):
    """生成并下发固件可识别的 LLM 情绪消息。"""
    emoji = "🙂"
    emotion = "happy"
    for char in text:
        if char in EMOJI_MAP:
            emoji = char
            emotion = EMOJI_MAP[char]
            break
    else:
        # emoji 是首选信号；模型遗漏 emoji 时再使用服务端语义兜底。
        normalized_text = text.lower()
        for candidate_emotion, candidate_emoji, keywords in EMOTION_KEYWORDS:
            if any(keyword in normalized_text for keyword in keywords):
                emoji = candidate_emoji
                emotion = candidate_emotion
                break

    message = {
        "type": "llm",
        "text": emoji,
        "emotion": emotion,
        "session_id": conn.session_id,
    }
    try:
        await conn.websocket.send(json.dumps(message))
        conn.logger.bind(tag=TAG).debug(
            f"下发设备情绪消息: emotion={emotion}, emoji={emoji}"
        )
    except Exception as e:
        conn.logger.bind(tag=TAG).warning(f"发送情绪表情失败，错误:{e}")
    return


def is_emoji(char):
    """检查字符是否为emoji表情"""
    code_point = ord(char)
    return any(start <= code_point <= end for start, end in EMOJI_RANGES)


def check_emoji(text):
    """去除文本中的所有emoji表情"""
    return "".join(char for char in text if not is_emoji(char) and char != "\n")
