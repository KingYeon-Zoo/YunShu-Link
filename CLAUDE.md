# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目定位

YunShu-Link（云枢）是面向 ESP32 智能语音硬件的自研后端，多语言 monorepo，代码全部位于 `main/` 下：

| 子系统 | 目录 | 技术栈 | 端口 |
|--------|------|--------|------|
| 语音核心服务 | `main/xiaozhi-server` | Python 3.10 · asyncio | WS 8000 / HTTP 8003 |
| 控制台后端 | `main/manager-api` | Java 21 · Spring Boot 3.4 | 8002（context-path `/xiaozhi`） |
| 控制台 Web | `main/manager-web` | Vue 2 · Element UI · vue-cli | 8001 |
| 控制台移动端 | `main/manager-mobile` | uni-app（Vue 3 + TS）· pnpm | — |
| 音频调试工具 | `main/digital-human` | Python + 静态页 | — |

回复与文档使用简体中文，与仓库其余部分保持一致。

## 日常开发：优先用图形化启动器

根目录 `./start-dev.sh` 是唯一推荐入口，混合模式运行：MySQL/Redis/manager-api 在 Docker（`docker-compose.dev.yml`，项目名 `yunshu-link-dev`），manager-web 与 xiaozhi-server 在宿主机热更新。

```bash
./start-dev.sh
```

交互菜单：`1` 保留数据库启动、`2` 备份并初始化演示数据、`3` 状态、`4/5/6` 分别重启语音服务/前端/管理后端、`7` 日志、`8` 停止应用（保留数据库）、`9` 环境检查。

非交互参数（自动化/调试用）：`start [--keep-db|--init-db]`、`restart-python`、`restart-web`、`restart-manager`、`stop`、`down`、`status`、`logs`、`logs-manager`、`doctor`。

启动器行为需要知道的几点：

- Python 环境隔离在 `main/xiaozhi-server/.venv`，优先用 Conda（同时隔离 FFmpeg），无 Conda 时退回 uv。依赖安装以 `requirements.txt` 的 sha256 打标记（`.venv/.requirements.sha256`），未变化则跳过。
- SenseVoice 模型（约 900MB）首次自动下载到 `main/xiaozhi-server/models/SenseVoiceSmall/model.pt`，支持断点续传。
- 运行日志与 PID 在根目录 `.dev/logs`、`.dev/pids`。
- manager-api 在 `maven:3.9.9-eclipse-temurin-21` 容器里跑 `spring-boot:run`，Maven 缓存与宿主机隔离；改 Java 代码后用菜单 `6` 重启。

开发地址：前端 `http://127.0.0.1:8001`、API `http://127.0.0.1:8002/xiaozhi`（文档 `/doc.html`）、WebSocket `ws://127.0.0.1:8000/xiaozhi/v1/`、Vision/OTA HTTP `http://127.0.0.1:8003`。

## 单独启动各子系统

```bash
cd main/xiaozhi-server && python app.py          # 需 data/.config.yaml 与 ffmpeg
cd main/manager-api    && mvn spring-boot:run
cd main/manager-web    && npm install && npm run serve
cd main/manager-mobile && pnpm install && pnpm dev:h5   # 强制 pnpm（only-allow）
```

## 测试

Python 侧用标准库 `unittest`，无 pytest 依赖：

```bash
cd main/xiaozhi-server && python -m unittest discover -s tests -v
```

```bash
cd main/xiaozhi-server && python -m unittest tests.test_doubao_v3_tts -v
```

前端动效单测是裸 Node 脚本：`cd main/manager-web && npm run test:motion`。

Shell 层测试（`DEV_START_SOURCE_ONLY=1` 只 source 不执行启动器）。`test-start-dev.sh` 会在临时目录里真跑一次备份逻辑，属正常行为；`test-manager-web-brand.sh` 依赖 `rg`（ripgrep），未安装会静默失败：

```bash
bash scripts/tests/test-start-dev.sh && bash scripts/tests/test-manager-web-brand.sh
```

Java 侧无自定义测试套件，只有 JUnit 5 依赖；`mvn -DskipTests` 是容器里的默认行为。

模块性能基准：`cd main/xiaozhi-server && python performance_tester.py`。

## 演示环境重置

`scripts/demo/reset-demo-db.sh`（通常经菜单 `2` 调用，命令行参数仅留给自动化）会备份现有库、重建并等 Liquibase 迁移、写入固定基线：演示管理员、豆包 LLM/ASR/TTS、20 个 Seed-TTS 2.0 音色、`prompt-example/` 下五套角色模板（默认琉璃）、保留全部记忆模型与 RAGFlow 选项，最后清 Redis 并重启 API 与语音服务。基线固定为 2026-07-26 确认版，脚本结束会用 `verify-current-baseline.sql` 自校验。

密钥从根目录 `.env` 读（模板 `.env.demo.example`），不入库不打日志。备份落在 `.demo-db-backups/` 或 `main/xiaozhi-server/mysql/backups/`，只作人工回滚，绝不当初始化数据源。

## 架构要点

### 配置双模式（改配置前必须先分清）

`xiaozhi-server/config/config_loader.py` 的 `load_config()` 决定运行形态：读 `config.yaml` 作默认值，再读 `data/.config.yaml`；若后者含 `manager-api.url`，则走 `get_config_from_api_async()` 从 Java 侧拉全量配置（Bearer 认证用 `manager-api.secret`，对应控制台参数管理里的 `server.secret`），否则本地 merge 独立运行。配置结果进 `cache_manager`。

- 本地模式：改 `data/.config.yaml`（模板 `config.yaml`）。
- 控制台模式：模板是 `config_from_api.yaml`，模型与音色改动应落在数据库/控制台，不要改 YAML。
- `server.auth_key` 优先级：`config.server.auth_key` > `manager-api.secret` > 随机 uuid，用于 OTA token 与 Vision 接口 JWT。

### Provider 可插拔体系

`core/providers/` 下 `asr`、`tts`、`llm`、`vllm`、`vad`、`memory`、`intent`、`tools` 各有 `base.py` 抽象基类与多平台实现，由配置 `selected_module`（VAD/ASR/LLM/VLLM/TTS/Memory/Intent）选择具体实现。新增平台 = 加一个实现文件 + 配置项，不改核心。`core/utils/modules_initialize.py` 负责按需实例化。

### 连接级编排

`core/connection.py` 的 `ConnectionHandler` 是核心：每个设备连接独立持有对话状态与模块实例。`_initialize_components()` 后 `_initialize_private_config_async()` 会用设备私有配置覆盖 `selected_module` 各项（每台设备可用不同智能体/模型/音色）。`chat()` 驱动 LLM 流式输出、工具调用与 TTS 分句；`handle_restart` 支持热重启，`WebSocketServer.update_config()` 支持配置热更新并重建 VAD/ASR/LLM/Memory/Intent 实例。

消息入口：`core/websocket_server.py` 解析 `/xiaozhi/v1/` 握手与鉴权，`core/handle/` 下按职责分文件（收发音频、文本消息注册表、意图、打断、上报），`core/api/` 提供 OTA 与 Vision 的 aiohttp 路由。

### 端到端语音（S2S）走 ASR 槽位

`core/providers/s2s/` 是豆包端到端实时语音（RealtimeAPI）的接入层（协议编解码 / WebSocket 客户端 / StartSession 配置 / 工具桥接），编排器是 `core/providers/asr/doubao_realtime.py`，通过 `selected_module.ASR: DoubaoRealtime` 启用。

它占用 ASR 槽位而非新增槽位，因为音频入口就是 `conn.asr.receive_audio`；模型返回的音频重新塞回 `conn.tts.tts_audio_queue`，从而复用既有流控、字幕、情绪消息与上报链路——**设备侧协议与前端零改动**。启用后 TTS 不参与实时链路，LLM 仅用于记忆总结、聊天标题与工具路由。端到端模型不支持 function_call，工具由旁路 LLM 判定后经 `ChatRAGText` 注入，期间模型的闲聊音频先缓存在 `DefaultAudioGate` 里，判定超时/缓存满/本轮已结束三种情况都会放行。详见 `docs/doubao-realtime-s2s-integration.md`。

### 工具体系两层

`plugins_func/` 是插件层：`loadplugins.py` 启动时自动导入 `functions/` 下全部模块，函数用 `@register_function(name, desc, type)` 装饰即注册，`ToolType` 决定调用后行为（NONE/WAIT/CHANGE_SYS_PROMPT/SYSTEM_CTL/IOT_CTL/MCP_CLIENT，后三者需传 `conn`）。新增工具只需在 `functions/` 加文件。

`core/providers/tools/` 是统一调度层：`unified_tool_manager.py` 按 `ToolType` 注册各 executor（`server_plugins`、`device_iot`、`device_mcp`、`server_mcp`、`mcp_endpoint`），对 LLM 暴露统一的 function 列表。

### manager-api 结构约定

`xiaozhi/common/` 放框架层（BaseEntity/BaseDao/CrudService、Shiro 鉴权、Redis、XSS、SM2/AES、统一 `Result`），`xiaozhi/modules/` 按业务分包（agent、device、model、timbre、voiceclone、knowledge、correctword、llm、sms、sys、security），每包内 controller/service/dao/entity/dto/vo 分层。MyBatis-Plus mapper XML 在 `resources/mapper/`。

数据库结构由 Liquibase 管理：`resources/db/changelog/db.changelog-master.yaml` 引用按日期命名的 SQL（如 `202607260900.sql`）。改表结构必须新增 changelog 文件并注册到 master，不要改历史文件、不要手工改库。

### 前端约定

`manager-web` 走 vue-cli，devServer 把 `/xiaozhi` 代理到 `VUE_APP_DEV_PROXY_TARGET`（默认 `http://127.0.0.1:8002`）。API 按业务拆在 `src/apis/module/*.js`，统一走 `httpRequest.js`。生产构建可选 CDN 外链（`VUE_APP_USE_CDN=true`，Vue/Element/axios 走 unpkg）与 Workbox Service Worker，改依赖版本时注意 `vue.config.js` 里的 `cdnResources` 需同步。

`manager-mobile` 用 alova 请求、pinia 状态、wot-design-uni 组件；`pnpm type-check`、`pnpm lint:fix` 可用。

## 其它

- 集成类文档都在 `docs/`（MCP 接入点、RAGFlow、声纹、MQTT 网关、OTA、各家 TTS 等），排查第三方接入优先查这里。
- `prompt-example/` 是演示基线用到的角色提示词，改动会影响演示初始化校验。
- 上游参考项目为 `xiaozhi-esp32-server`（MIT），本仓库已大量重构，遇到与上游文档不一致时以本仓库代码为准。
