import base64
import json
import unittest

from core.providers.tts.doubao_v3_utils import decode_ndjson_audio


class DoubaoV3TtsTest(unittest.TestCase):
    def test_decodes_multiple_ndjson_audio_chunks(self):
        body = "\n".join(
            [
                json.dumps({"code": 0, "data": base64.b64encode(b"hello ").decode()}),
                json.dumps({"code": 0, "data": base64.b64encode(b"world").decode()}),
                json.dumps({"code": 20000000}),
            ]
        )

        self.assertEqual(decode_ndjson_audio(body), b"hello world")

    def test_raises_for_service_error(self):
        with self.assertRaisesRegex(RuntimeError, "code=45000000"):
            decode_ndjson_audio(
                json.dumps({"code": 45000000, "message": "invalid speaker"})
            )

    def test_ignores_non_json_lines(self):
        body = "not-json\n" + json.dumps(
            {"code": 0, "data": base64.b64encode(b"audio").decode()}
        )

        self.assertEqual(decode_ndjson_audio(body), b"audio")


if __name__ == "__main__":
    unittest.main()
