"""升级依赖的离线兼容测试，不调用云端服务。"""
import os
os.environ['MEM0_TELEMETRY'] = 'false'
import asyncio
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

class DependencyCompatibilityTest(unittest.TestCase):
    def test_audio_roundtrip_and_onnx_silence(self):
        import numpy as np
        import torch
        import torchaudio
        import onnxruntime
        from funasr.utils.load_utils import load_bytes
        pcm=np.array([0,32767,-32768],dtype=np.int16)
        np.testing.assert_allclose(load_bytes(pcm.tobytes()),pcm.astype(np.float32)/32768)
        self.assertEqual(torchaudio.transforms.Resample(16000,8000)(torch.zeros(1600)).shape,(800,))
        path=Path(__file__).resolve().parents[1]/'models/snakers4_silero-vad/src/silero_vad'
        spec=importlib.util.spec_from_file_location('compat_vad',path/'utils_vad.py')
        helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
        with tempfile.TemporaryDirectory() as tmp:
            wav=str(Path(tmp)/'test.wav');helper.save_audio(wav,torch.zeros(1600),16000)
            self.assertEqual(helper.read_audio(wav,8000).shape,(800,))
        session=onnxruntime.InferenceSession(str(path/'data/silero_vad.onnx'),providers=['CPUExecutionProvider'])
        out,state=session.run(None,{'input':np.zeros((1,576),np.float32),'state':np.zeros((2,1,128),np.float32),'sr':np.array(16000,np.int64)})
        self.assertTrue(np.isfinite(out).all());self.assertEqual(state.shape,(2,1,128))

    def test_mem0_cloud_client_payloads(self):
        import httpx
        from mem0 import MemoryClient
        calls=[]
        def respond(request):
            self.assertEqual(request.headers['Authorization'],'Token local-test')
            calls.append((request.url.path,json.loads(request.content) if request.content else None))
            return httpx.Response(200,json={'org_id':'org-test','project_id':'project-test','user_email':'test@example.invalid'} if request.url.path == '/v1/ping/' else {'results':[{'memory':'测试记忆'}]})
        with httpx.Client(transport=httpx.MockTransport(respond)) as transport:
            client=MemoryClient(api_key='local-test',host='https://test.invalid',client=transport)
            client.add([{'role':'user','content':'测试'}],user_id='role-test')
            result=client.search('测试',filters={'user_id':'role-test'})
        self.assertEqual(result['results'][0]['memory'],'测试记忆')
        self.assertEqual(calls[1][0],'/v3/memories/add/');self.assertEqual(calls[1][1]['user_id'],'role-test')
        self.assertEqual(calls[2][1]['filters'],{'user_id':'role-test'})

class AiohttpCompatibilityTest(unittest.IsolatedAsyncioTestCase):
    async def test_local_http_and_websocket(self):
        from aiohttp import web,ClientSession
        async def echo(request):return web.json_response(await request.json())
        async def websocket(request):
            ws=web.WebSocketResponse();await ws.prepare(request)
            async for msg in ws:await ws.send_str(msg.data)
            return ws
        app=web.Application();app.router.add_post('/echo',echo);app.router.add_get('/ws',websocket)
        runner=web.AppRunner(app);await runner.setup();site=web.TCPSite(runner,'127.0.0.1',0);await site.start()
        port=site._server.sockets[0].getsockname()[1]
        try:
            async with ClientSession() as client:
                async with client.post(f'http://127.0.0.1:{port}/echo',json={'message':'测试'}) as response:self.assertEqual(await response.json(),{'message':'测试'})
                async with client.ws_connect(f'http://127.0.0.1:{port}/ws') as ws:
                    await ws.send_str('测试');self.assertEqual((await ws.receive()).data,'测试')
        finally:await runner.cleanup()

if __name__=='__main__':unittest.main()
