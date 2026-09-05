import unittest

from core.providers.asr.doubao_stream import ASRProvider


class DoubaoStreamAsrTest(unittest.TestCase):
    def setUp(self):
        self.provider = ASRProvider.__new__(ASRProvider)
        self.provider.api_key = "test-api-key"
        self.provider.appid = ""
        self.provider.access_token = None
        self.provider.resource_id = "volc.seedasr.sauc.duration"
        self.provider.uid = "test-user"
        self.provider.workflow = (
            "audio_in,resample,partition,vad,fe,decode,itn,nlu_punctuate"
        )
        self.provider.result_type = "single"
        self.provider.end_window_size = 200
        self.provider.boosting_table_name = ""
        self.provider.correct_table_name = ""
        self.provider.format = "pcm"
        self.provider.codec = "pcm"
        self.provider.rate = 16000
        self.provider.bits = 16
        self.provider.channel = 1
        self.provider.enable_multilingual = False
        self.provider.language = None

    def test_uses_new_console_headers_without_legacy_credentials(self):
        headers = self.provider.token_auth()

        self.assertEqual(headers["X-Api-Key"], "test-api-key")
        self.assertEqual(
            headers["X-Api-Resource-Id"], "volc.seedasr.sauc.duration"
        )
        self.assertEqual(headers["X-Api-Sequence"], "-1")
        self.assertTrue(headers["X-Api-Request-Id"])
        self.assertNotIn("X-Api-App-Key", headers)
        self.assertNotIn("X-Api-Access-Key", headers)

    def test_new_console_request_does_not_put_secret_in_body(self):
        request = self.provider.construct_request("request-id")

        self.assertNotIn("app", request)
        self.assertEqual(request["request"]["model_name"], "bigmodel")
        self.assertNotIn("test-api-key", str(request))

    def test_keeps_legacy_auth_as_compatibility_fallback(self):
        self.provider.api_key = None
        self.provider.appid = "legacy-app"
        self.provider.access_token = "legacy-token"

        headers = self.provider.token_auth()
        request = self.provider.construct_request("request-id")

        self.assertEqual(headers["X-Api-App-Key"], "legacy-app")
        self.assertEqual(headers["X-Api-Access-Key"], "legacy-token")
        self.assertEqual(request["app"]["appid"], "legacy-app")
        self.assertEqual(request["app"]["token"], "legacy-token")


if __name__ == "__main__":
    unittest.main()
