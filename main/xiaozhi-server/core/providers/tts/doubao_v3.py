import asyncio

import requests

from config.logger import setup_logging
from core.providers.tts.base import TTSProviderBase
from core.providers.tts.doubao_v3_utils import decode_ndjson_audio
from core.utils.tts import convert_percentage_to_range
from core.utils.util import check_model_key


TAG = __name__
logger = setup_logging()

DEFAULT_ENDPOINT = "https://openspeech.bytedance.com/api/v3/tts/unidirectional"
DEFAULT_RESOURCE_ID = "seed-tts-2.0"


class TTSProvider(TTSProviderBase):
    """豆包语音合成 2.0 单向 HTTP Provider。

    接口返回 NDJSON，每行可能携带一段 base64 音频，不能把整个响应当作单个 JSON
    解析。鉴权优先使用新版控制台 API Key，同时兼容旧版 App ID + Access Token。
    """

    def __init__(self, config, delete_audio_file):
        super().__init__(config, delete_audio_file)
        self.api_url = config.get("api_url") or DEFAULT_ENDPOINT
        self.resource_id = config.get("resource_id") or DEFAULT_RESOURCE_ID
        self.api_key = config.get("api_key")
        self.appid = config.get("appid")
        self.access_token = config.get("access_token")
        self.voice = config.get("private_voice") or config.get("speaker")
        self.audio_file_type = config.get("format", "mp3")
        self.sample_rate = int(config.get("sample_rate", 24000))
        self.timeout = float(config.get("request_timeout", 120))
        self.speech_rate = int(config.get("speech_rate", 0))

        if "ttsRate" in config:
            self.speech_rate = int(
                convert_percentage_to_range(
                    config["ttsRate"], min_val=-50, max_val=100, base_val=0
                )
            )

        model_key = self.api_key or self.access_token
        model_key_msg = check_model_key("TTS", model_key)
        if model_key_msg:
            logger.bind(tag=TAG).error(model_key_msg)

    def generate_filename(self, extension=None):
        return super().generate_filename(extension or f".{self.audio_file_type}")

    def _auth_headers(self):
        headers = {
            "Content-Type": "application/json",
            "X-Api-Resource-Id": self.resource_id,
        }
        if self.api_key:
            headers["X-Api-Key"] = self.api_key
            return headers
        if self.appid and self.access_token:
            headers["X-Api-App-Id"] = str(self.appid)
            headers["X-Api-Access-Key"] = self.access_token
            return headers
        raise ValueError(
            "豆包 TTS 未配置鉴权：请设置 api_key，或同时设置 appid 与 access_token"
        )

    def _request_audio(self, text):
        if not self.voice:
            raise ValueError("豆包 TTS 未配置 speaker 音色")

        payload = {
            "user": {"uid": "yunshu_link"},
            "req_params": {
                "text": text,
                "speaker": self.voice,
                "audio_params": {
                    "format": self.audio_file_type,
                    "sample_rate": self.sample_rate,
                    "speech_rate": self.speech_rate,
                },
            },
        }
        response = requests.post(
            self.api_url,
            json=payload,
            headers=self._auth_headers(),
            timeout=self.timeout,
        )
        response.raise_for_status()
        return decode_ndjson_audio(response.text)

    async def text_to_speak(self, text, output_file):
        try:
            audio = await asyncio.to_thread(self._request_audio, text)
        except Exception as exc:
            raise RuntimeError(f"豆包 TTS 请求失败: {exc}") from exc

        if not audio:
            raise RuntimeError("豆包 TTS 未返回音频数据")
        if output_file:
            with open(output_file, "wb") as audio_file:
                audio_file.write(audio)
            return None
        return audio
