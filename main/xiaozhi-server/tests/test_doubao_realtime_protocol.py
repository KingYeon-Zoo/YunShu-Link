import unittest

from core.providers.s2s import protocol as pr


class ProtocolFrameTest(unittest.TestCase):
    """帧编码必须与官方文档给出的字节数组完全一致。"""

    def test_start_connection_matches_official_bytes(self):
        expected = bytes(
            [17, 20, 16, 0, 0, 0, 0, 1, 0, 0, 0, 2, 123, 125]
        )
        self.assertEqual(pr.build_event(pr.EV_START_CONNECTION), expected)

    def test_start_session_matches_official_bytes(self):
        session_id = "75a6126e-427f-49a1-a2c1-621143cb9db3"
        payload = {"dialog": {"bot_name": "豆包", "dialog_id": "", "extra": None}}
        frame = pr.build_event(pr.EV_START_SESSION, payload, session_id)

        # header + event + session id 长度/内容，随后 payload 长度为 60
        self.assertEqual(frame[:4], bytes([17, 20, 16, 0]))
        self.assertEqual(int.from_bytes(frame[4:8], "big"), pr.EV_START_SESSION)
        self.assertEqual(int.from_bytes(frame[8:12], "big"), len(session_id))
        self.assertEqual(frame[12 : 12 + 36].decode(), session_id)
        self.assertEqual(int.from_bytes(frame[48:52], "big"), 60)

    def test_connect_level_event_carries_no_session_id(self):
        """StartConnection 带上 session id 会被服务端拒绝。"""
        frame = pr.build_event(pr.EV_FINISH_CONNECTION, {}, "should-be-dropped")
        self.assertNotIn(b"should-be-dropped", frame)

    def test_session_event_keeps_session_id(self):
        frame = pr.build_event(pr.EV_FINISH_SESSION, {}, "sid-123")
        self.assertIn(b"sid-123", frame)

    def test_audio_frame_uses_raw_serialization(self):
        pcm = b"\x01\x02" * 320
        frame = pr.build_audio(pcm, "sid-abc")
        # Message type = Audio-only request, serialization = Raw
        self.assertEqual(frame[1] >> 4, pr.MSG_AUDIO_CLIENT)
        self.assertEqual(frame[2] >> 4, pr.SER_RAW)
        self.assertTrue(frame.endswith(pcm))

    def test_parse_tts_response_extracts_audio_and_session(self):
        raw = bytes(
            [17, 180, 0, 0, 0, 0, 1, 96, 0, 0, 0, 36]
        ) + b"3c791a7d-227a-4446-993b-24f9e302cc98" + (2044).to_bytes(4, "big") + b"OggS"
        frame = pr.parse_frame(raw)
        self.assertEqual(frame.event, pr.EV_TTS_RESPONSE)
        self.assertEqual(frame.session_id, "3c791a7d-227a-4446-993b-24f9e302cc98")
        self.assertEqual(frame.audio, b"OggS")

    def test_parse_json_server_event(self):
        payload = b'{"dialog_id":"d-1"}'
        raw = (
            bytes([17, 0x94, 0x10, 0])
            + pr.EV_SESSION_STARTED.to_bytes(4, "big")
            + (5).to_bytes(4, "big")
            + b"sid-1"
            + len(payload).to_bytes(4, "big")
            + payload
        )
        frame = pr.parse_frame(raw)
        self.assertEqual(frame.event, pr.EV_SESSION_STARTED)
        self.assertEqual(frame.payload["dialog_id"], "d-1")

    def test_parse_error_frame_reads_code(self):
        payload = b'{"error":"boom"}'
        raw = (
            bytes([17, 0xF0, 0x10, 0])
            + (45000003).to_bytes(4, "big")
            + len(payload).to_bytes(4, "big")
            + payload
        )
        frame = pr.parse_frame(raw)
        self.assertEqual(frame.error_code, 45000003)
        self.assertEqual(frame.payload["error"], "boom")


if __name__ == "__main__":
    unittest.main()
