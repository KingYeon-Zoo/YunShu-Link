import base64
import json


STREAM_END_CODE = 20000000


def decode_ndjson_audio(body):
    """解码豆包 V3 TTS 的 NDJSON 分片响应。"""
    chunks = []
    for raw_line in body.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            continue

        code = data.get("code")
        if code == STREAM_END_CODE:
            break
        if code not in (0, None) and not data.get("data"):
            raise RuntimeError(
                f"豆包 TTS 返回错误 code={code}: {data.get('message', '未知错误')}"
            )
        if data.get("data"):
            chunks.append(base64.b64decode(data["data"]))
    return b"".join(chunks)
