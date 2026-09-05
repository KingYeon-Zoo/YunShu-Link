#!/usr/bin/env python3
"""对控制台里启用的模型逐个发起真实调用，确认烧录前链路可用。

只校验字段非空是不够的：失效的密钥同样"非空"，却会在设备连上来的那一刻才暴露成
401。所以这里直接用 provider 本体走一遍设备实际使用的代码路径。

用法（需在 main/xiaozhi-server 的虚拟环境中运行）：
    python scripts/diagnose-models.py            # 全量
    python scripts/diagnose-models.py --quick    # 跳过较慢的 ASR 闭环

退出码：0 全部通过；1 存在失败项。
"""

from __future__ import annotations

import argparse
import asyncio
import json
import subprocess
import sys
from pathlib import Path

import os

ROOT = Path(__file__).resolve().parent.parent
SERVER_DIR = ROOT / "main" / "xiaozhi-server"
sys.path.insert(0, str(SERVER_DIR))
# provider 加载器用相对路径 core/providers/... 定位实现，必须以服务目录为工作目录。
os.chdir(SERVER_DIR)

GREEN, RED, YELLOW, DIM, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"

# provider 模块在导入时会同步加载配置（内部调用 asyncio.run），必须在事件循环之外
# 完成首次导入，否则会抛 "asyncio.run() cannot be called from a running event loop"。
from core.utils import asr as asr_utils  # noqa: E402
from core.utils import llm as llm_utils  # noqa: E402
from core.utils import tts as tts_utils  # noqa: E402

results: list[tuple[bool, str, str]] = []


def record(ok: bool, item: str, detail: str) -> None:
    mark = f"{GREEN}[通过]{RESET}" if ok else f"{RED}[失败]{RESET}"
    print(f"  {mark} {item:<22} {detail}", flush=True)
    results.append((ok, item, detail))


def skip(item: str, detail: str) -> None:
    print(f"  {YELLOW}[跳过]{RESET} {item:<22} {detail}", flush=True)


def query(sql: str, project: str, db: str) -> str:
    """通过 docker exec 读库，避免依赖宿主机的 mysql 客户端。"""
    proc = subprocess.run(
        ["docker", "exec", f"{project}-mysql-1", "mysql", "-uroot", "-p123456",
         "--default-character-set=utf8mb4", db, "-N", "-s", "-e", sql],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"查询数据库失败：{proc.stderr.strip()[:200]}")
    return proc.stdout.strip()


class Context:
    def __init__(self, project: str, db: str) -> None:
        self.project, self.db = project, db

    def model_config(self, model_id: str) -> dict | None:
        raw = query(
            f"SELECT config_json FROM ai_model_config WHERE id='{model_id}';",
            self.project, self.db,
        )
        return json.loads(raw) if raw else None

    def agent_bindings(self) -> list[dict]:
        rows = query(
            "SELECT agent_name, asr_model_id, llm_model_id, tts_model_id, tts_voice_id "
            "FROM ai_agent;", self.project, self.db,
        )
        out = []
        for line in filter(None, rows.splitlines()):
            cells = line.split("\t")
            if len(cells) == 5:
                out.append(dict(zip(
                    ("agent", "asr", "llm", "tts", "voice"), cells)))
        return out

    def voice_code(self, voice_id: str) -> str:
        if not voice_id or voice_id == "NULL":
            return ""
        return query(
            f"SELECT tts_voice FROM ai_tts_voice WHERE id='{voice_id}';",
            self.project, self.db,
        )


async def check_llm(ctx: Context, model_id: str) -> None:
    cfg = ctx.model_config(model_id)
    if not cfg:
        record(False, f"LLM {model_id}", "数据库中找不到该模型配置")
        return
    name = cfg.get("model_name", "?")
    try:
        provider = llm_utils.create_instance(cfg["type"], cfg)
        reply = "".join(
            str(chunk) for chunk in provider.response(
                "diagnose", [{"role": "user", "content": "回复两个字：正常"}])
        ).strip()
        if reply:
            record(True, f"LLM {model_id}", f"{name} → {reply[:24]}")
        else:
            record(False, f"LLM {model_id}", f"{name} 返回空内容")
    except Exception as exc:  # noqa: BLE001 - 汇总所有失败原因供人工判断
        record(False, f"LLM {model_id}", f"{name} {type(exc).__name__}: {exc}"[:150])


async def synth(ctx: Context, model_id: str, voice: str, fmt: str, rate: int) -> bytes:
    cfg = dict(ctx.model_config(model_id) or {})
    cfg["format"], cfg["sample_rate"] = fmt, rate
    provider = tts_utils.create_instance(cfg["type"], cfg, False)
    if voice:
        provider.voice = voice
    return await provider.text_to_speak("云枢链路自检。", None)


async def check_tts(ctx: Context, model_id: str, voice: str) -> bytes | None:
    try:
        audio = await synth(ctx, model_id, voice, "mp3", 24000)
        if audio:
            record(True, f"TTS {model_id}",
                   f"音色 {voice or '默认'} 合成 {len(audio)} 字节")
            return audio
        record(False, f"TTS {model_id}", "接口未返回音频数据")
    except Exception as exc:  # noqa: BLE001
        detail = f"{type(exc).__name__}: {exc}"
        if "401" in detail or "Unauthorized" in detail:
            detail += "（密钥可能失效，参见 scripts/demo/README.md）"
        record(False, f"TTS {model_id}", detail[:170])
    return None


async def check_asr(ctx: Context, model_id: str, tts_model: str, voice: str) -> None:
    """用 TTS 合成的语音反向验证 ASR，覆盖真实的流式协议与鉴权。"""
    import gzip
    import uuid

    import websockets

    cfg = ctx.model_config(model_id)
    if not cfg:
        record(False, f"ASR {model_id}", "数据库中找不到该模型配置")
        return
    try:
        pcm = await synth(ctx, tts_model, voice, "pcm", 16000)
        if not pcm:
            record(False, f"ASR {model_id}", "无法生成测试音频（TTS 不可用）")
            return

        provider = asr_utils.create_instance(cfg["type"], cfg, False)
        if not hasattr(provider, "token_auth"):
            skip(f"ASR {model_id}", "该实现非流式，未做联网校验")
            return

        headers = provider.token_auth()
        async with websockets.connect(
            provider.ws_url, additional_headers=headers,
            max_size=10 ** 9, ping_interval=None, open_timeout=15,
        ) as ws:
            payload = gzip.compress(
                json.dumps(provider.construct_request(str(uuid.uuid4()))).encode())
            head = provider.generate_header()
            head.extend(len(payload).to_bytes(4, "big"))
            head.extend(payload)
            await ws.send(head)
            await ws.recv()

            frames = [pcm[i:i + 3200] for i in range(0, len(pcm), 3200)]
            for index, frame in enumerate(frames):
                body = gzip.compress(frame)
                is_last = index == len(frames) - 1
                chunk = bytearray(
                    provider.generate_last_audio_default_header() if is_last
                    else provider.generate_audio_default_header())
                chunk.extend(len(body).to_bytes(4, "big"))
                chunk.extend(body)
                await ws.send(chunk)
                await asyncio.sleep(0.01)

            text = ""
            for _ in range(60):
                try:
                    parsed = provider.parse_response(
                        await asyncio.wait_for(ws.recv(), timeout=8))
                except (asyncio.TimeoutError, Exception):  # noqa: B014
                    break
                got = (parsed.get("payload_msg", {}).get("result") or {}).get("text")
                if got:
                    text = got
                if parsed.get("is_last_package"):
                    break

        if text:
            record(True, f"ASR {model_id}", f"识别结果「{text}」")
        else:
            record(False, f"ASR {model_id}", "连接正常但未返回识别文本")
    except Exception as exc:  # noqa: BLE001
        record(False, f"ASR {model_id}", f"{type(exc).__name__}: {exc}"[:170])


def check_endpoints(project: str, db: str) -> None:
    """OTA 下发的地址必须是设备真能访问的局域网地址。"""
    import urllib.error
    import urllib.request

    rows = query(
        "SELECT param_code, param_value FROM sys_params WHERE param_code IN "
        "('server.websocket','server.ota','server.fronted_url');", project, db)
    params = dict(
        line.split("\t", 1) for line in filter(None, rows.splitlines())
        if "\t" in line)

    for code in ("server.websocket", "server.ota"):
        value = params.get(code, "")
        if not value or value == "null":
            record(False, code,
                   "未配置；OTA 会自动探测，可能下发旧网络地址导致设备连不上")
        elif "127.0.0.1" in value or "localhost" in value:
            record(False, code, f"{value} 是本机回环地址，设备无法访问")
        else:
            record(True, code, value)

    try:
        with urllib.request.urlopen(
                "http://127.0.0.1:8002/xiaozhi/ota/", timeout=8) as resp:
            body = resp.read().decode("utf-8", "replace").strip()
        record("正常" in body, "OTA 自检接口", body[:80])
    except Exception as exc:  # noqa: BLE001
        record(False, "OTA 自检接口", f"{type(exc).__name__}: {exc}"[:120])


async def main() -> int:
    parser = argparse.ArgumentParser(description="模型链路自检")
    parser.add_argument("--quick", action="store_true", help="跳过较慢的 ASR 闭环校验")
    parser.add_argument("--project", default="yunshu-link-dev")
    parser.add_argument("--db", default="xiaozhi_esp32_server")
    args = parser.parse_args()

    ctx = Context(args.project, args.db)
    print("模型链路自检（对启用的模型发起真实调用）：")

    try:
        agents = ctx.agent_bindings()
    except RuntimeError as exc:
        print(f"  {RED}[失败]{RESET} 无法连接数据库：{exc}")
        print(f"  {DIM}请先确认 MySQL 容器已启动。{RESET}")
        return 1

    if not agents:
        print(f"  {YELLOW}[跳过]{RESET} 未找到智能体，数据库可能尚未初始化")
        return 0

    print(f"\n{DIM}接入地址{RESET}")
    check_endpoints(args.project, args.db)

    seen: set[str] = set()
    for agent in agents:
        print(f"\n{DIM}智能体：{agent['agent']}{RESET}")
        voice = ctx.voice_code(agent["voice"])

        for model_id in dict.fromkeys(
                v for k, v in agent.items()
                if k == "llm" and v and v != "NULL"):
            if model_id not in seen:
                seen.add(model_id)
                await check_llm(ctx, model_id)

        tts_id = agent["tts"]
        if tts_id and tts_id != "NULL" and tts_id not in seen:
            seen.add(tts_id)
            await check_tts(ctx, tts_id, voice)

        asr_id = agent["asr"]
        if asr_id and asr_id != "NULL" and asr_id not in seen:
            seen.add(asr_id)
            if args.quick:
                skip(f"ASR {asr_id}", "--quick 模式已跳过")
            elif tts_id and tts_id != "NULL":
                await check_asr(ctx, asr_id, tts_id, voice)
            else:
                skip(f"ASR {asr_id}", "缺少 TTS，无法生成测试音频")

    failures = [item for ok, item, _ in results if not ok]
    print()
    if failures:
        print(f"{RED}自检发现 {len(failures)} 项异常：{'、'.join(failures)}{RESET}")
        print(f"{DIM}设备烧录前请先修复，否则连上后会出现无声或无法识别。{RESET}")
        return 1
    print(f"{GREEN}全部通过，共 {len(results)} 项。{RESET}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(asyncio.run(main()))
    except KeyboardInterrupt:
        sys.exit(130)
