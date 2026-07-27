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

交互菜单：`1` 保留数据库启动、`2` 备份并初始化演示数据、`3` 状态、`4/5/6` 分别重启语音服务/前端/管理后端、`7` 日志、`8` 停止应用（保留数据库）、`9` 环境检查（含模型自检）。

非交互参数（自动化/调试用）：`start [--keep-db|--demo|--init-db]`、`restart-python`、`restart-web`、`restart-manager`、`stop`、`down`、`status`、`logs`、`logs-manager`、`doctor`、`check-models`。

三种数据库模式别混用，`--init-db` 的名字最容易误导：

| 参数 | 行为 | 对应菜单 |
|------|------|----------|
| `--keep-db` | 保留现有库，日常开发用 | `1` |
| `--demo` | 备份、重建、**写入演示基线**（账号/模型/音色/角色），再跑完整自检 | `2` |
| `--init-db` | 备份、重建、只让 Liquibase 建空表——**没有登录账号，也没有模型配置** | 无 |

`--init-db` 产出的库无法登录 Web 端、语音链路也是空的，只适合要从零验证迁移脚本的场景；要能直接演示的环境一律用 `--demo`。脚本在 `--init-db` 时会主动告警并指向 `--demo`。

启动器行为需要知道的几点：

- Python 环境隔离在 `main/xiaozhi-server/.venv`，优先用 Conda（同时隔离 FFmpeg），无 Conda 时退回 uv。依赖安装以 `requirements.txt` 的 sha256 打标记（`.venv/.requirements.sha256`），未变化则跳过。
- SenseVoice 模型（约 900MB）首次自动下载到 `main/xiaozhi-server/models/SenseVoiceSmall/model.pt`，支持断点续传。
- 运行日志与 PID 在根目录 `.dev/logs`、`.dev/pids`。
- manager-api 在 `maven:3.9.9-eclipse-temurin-21` 容器里跑 `spring-boot:run`，Maven 缓存与宿主机隔离；改 Java 代码后用菜单 `6` 重启。

开发地址：前端 `http://127.0.0.1:8001`、API `http://127.0.0.1:8002/xiaozhi`（文档 `/doc.html`）、WebSocket `ws://127.0.0.1:8000/xiaozhi/v1/`、Vision/OTA HTTP `http://127.0.0.1:8003`。

## 模型链路自检（烧录前必跑）

`scripts/diagnose-models.py`（入口 `./start-dev.sh check-models`）用 provider 本体逐个真实调用控制台里启用的 LLM/TTS/ASR，并检查 `server.websocket`、`server.ota` 是否指向设备可访问的局域网地址。ASR 用 TTS 合成的音频做闭环识别，`--quick` 跳过该闭环。有失败项时退出码为 1。

启动、`restart-python`、菜单 `9` 会自动跑 `--quick` 版（失败只告警不中断，因为服务本身没问题、坏的是配置）；演示重置（菜单 `2` 或 `--demo`）后跑完整版，因为那一刻刚用 `.env` 重写了全部模型密钥，是最容易写进失效凭据的时机。**给设备烧录前手动跑一次完整版。**

存在的理由：校验字段非空抓不到失效密钥——坏密钥同样非空，只在设备连上的那一刻变成 401，表现为设备完全无声。

改这个脚本时注意两个约束：provider 模块导入时会同步 `asyncio.run(load_config())`，首次导入必须在事件循环之外；`create_instance` 用相对路径 `core/providers/...` 定位实现，因此脚本会 `os.chdir` 到 `main/xiaozhi-server`。

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

以上都是离线单测，不碰外部接口。要验证模型密钥和接入地址真的可用，跑 `./start-dev.sh check-models`（见上文「模型链路自检」）——它会发真实请求，需要开发环境已启动。

## 演示环境重置

`scripts/demo/reset-demo-db.sh`（经菜单 `2` 或 `start --demo` 调用，命令行参数仅留给自动化）会备份现有库、重建并等 Liquibase 迁移、写入固定基线，最后清 Redis 并重启 API 与语音服务。基线固定为 2026-07-27 确认版，脚本结束会用 `verify-current-baseline.sql` 自校验。

基线由四份 SQL 依次写入，顺序不能改（后三份引用第一份建立的用户、模型与模板）：

| 文件 | 内容 |
|------|------|
| `seed-demo.sql` | 固定层：演示管理员、豆包 LLM/ASR/TTS、20 个 Seed-TTS 音色、五套角色模板（默认琉璃）、保留记忆模型与 RAGFlow 选项 |
| `seed-demo-models.sql` | 多厂商模型目录（通义千问/DeepSeek/智谱/Ollama/FunASR/Edge TTS/豆包视觉），仅供页面展示 |
| `seed-demo-showcase.sql` | 五个智能体实例、标签、10 台设备、6 段会话共 36 条聊天记录 |
| `seed-demo-knowledge.sql` | 4 个知识库与 45 篇文档影子记录，由 `fetch-demo-corpus.py` 生成 |

展示数据有几条约束，改的时候容易踩：

- 智能体的 `mem_model_id` 不能是 `Memory_nomem` —— 前端据此禁用「聊天记录」入口，插了历史也点不开。
- 知识库的 `rag_model_id` 必须留空。它非空时列表接口会去 RAGFlow 核对，演示环境没有 RAGFlow，核对失败会让卡片变红并弹出英文异常；留空则整条同步链路短路。文档的 `run` 同理必须是 `DONE`。
- 设备的 `board` 必须取 `sys_dict_data` 里 `FIRMWARE_TYPE` 的真实 `dict_value`，否则设备型号列显示原始英文串。
- 只有豆包那套模型能被智能体绑定 —— `check-models` 只对被绑定的模型发真实请求，绑上没配密钥的第三方模型会让自检失败。
- 设备列表的「在线/离线」列查的是 MQTT 网关（`server.mqtt_manager_api`），假数据造不出来，没网关时该列不渲染。首页的「在线设备」统计另走 `last_connected_at` 是否在 24 小时内，这个能造。

知识库语料来自 MIT 协议的 `pwxcoo/chinese-xinhua`（成语、歇后语）与 `chinese-poetry/chinese-poetry`（论语、元曲、幽梦影），加上本仓库 `docs/` 下的产品文档。正文在 `scripts/demo/corpus/`，已提交进仓库，**重置流程不需要联网**；只有更新语料时才跑 `python3 scripts/demo/fetch-demo-corpus.py`（需联网），跑完要同步更新基线校验里的文档条数。

改动这些 SQL 后，先跑离线自检再动真实库 —— 它在临时库里跑完整套初始化并校验引用完整性，不需要密钥：

```bash
bash scripts/tests/test-demo-seed.sh
```

启动器不直接调这个脚本，而是经 `write_demo_baseline` 调用，菜单 `2` 与 `--demo` 共用这一条路径（避免两者再次漂移，测试有断言）。它在重置之后还补了两步 `reset-demo-db.sh` 本身不做的事：

- `verify_demo_baseline` 抽查登录账号、智能体、豆包三类模型是否齐备，缺任何一项即失败。注意区分两种情况——数据库连不上会宽容跳过，但连上却读不到基线表会直接报错，因为后者正是「只建了空表没写基线」的故障形态。
- `apply_lan_access_params` 探测本机局域网 IP 写入 `server.websocket`、`server.ota`、`server.fronted_url` 并清 Redis。**`reset-demo-db.sh` 从不碰这三个参数**，重置后它们是 Liquibase 的 `null`，manager-api 会自动探测并可能下发旧网络的残留 IP（见下文「设备接入地址由控制台参数决定」）。探测会排除 `198.18/16`（代理软件虚拟网卡）和 `169.254/16`，探测不到时留空并提示手动填写，而不是写个坏地址进去。

密钥从根目录 `.env` 读，不入库不打日志。备份落在 `.demo-db-backups/` 或 `main/xiaozhi-server/mysql/backups/`，只作人工回滚，绝不当初始化数据源。

密钥来源有两个坑，改 `reset-demo-db.sh` 时别踩回去：

- 豆包 ASR 与 Seed-TTS 共用同一个火山引擎 `X-Api-Key`，脚本从 `.env` 的这一个键同时推导出 `DOUBAO_ASR_API_KEY` 和 `DOUBAO_TTS_API_KEY`。不要单独再填 `DOUBAO_TTS_API_KEY`；两者取值不同时脚本会告警，且通常意味着有一份已失效（TTS 报 401）。
- 本仓库 `.env` 缺变量时，脚本会兜底读同级 `../EduLoom/.env` 并打印提示。那属于另一个账号的凭据，可能早已失效——鉴权失败时优先在本仓库 `.env` 里显式配置。这个兜底真的会生效：`load_env_file` 是「先读到的赢」，本仓库漏一个键，EduLoom 就静默补上另一个账号的值，而自检当时可能照样全绿，等那份凭据失效才暴露。
- 本仓库 `.env` 现在有 `ARK_API_KEY`、`X-Api-Key`、`X-Api-Resource-Id` 三个键，只读它一份即可通过全部凭据校验（`--env-file .env` 可验证）。历史上曾出现两种写坏的形式，都被脚本的兼容分支悄悄接住了，别写回去：ARK key 写成不带键名的裸 `ark-...` 行，以及键名带尾随空格（`X-Api-Key =`）。
- `.env.demo.example` 列的 `DOUBAO_*` 键名多数并无必要——`ARK_BASE_URL`、`DOUBAO_TTS_ENDPOINT`、`DOUBAO_TTS_RESOURCE_ID` 等脚本里都有内置默认值，照模板全填反而更容易配错。

## 架构要点

### 配置双模式（改配置前必须先分清）

`xiaozhi-server/config/config_loader.py` 的 `load_config()` 决定运行形态：读 `config.yaml` 作默认值，再读 `data/.config.yaml`；若后者含 `manager-api.url`，则走 `get_config_from_api_async()` 从 Java 侧拉全量配置（Bearer 认证用 `manager-api.secret`，对应控制台参数管理里的 `server.secret`），否则本地 merge 独立运行。配置结果进 `cache_manager`。

- 本地模式：改 `data/.config.yaml`（模板 `config.yaml`）。
- 控制台模式：模板是 `config_from_api.yaml`，模型与音色改动应落在数据库/控制台，不要改 YAML。
- `server.auth_key` 优先级：`config.server.auth_key` > `manager-api.secret` > 随机 uuid，用于 OTA token 与 Vision 接口 JWT。

### 设备接入地址由控制台参数决定

控制台模式下 OTA 由 manager-api 提供（8003 上没有 `/xiaozhi/ota/`，返回 404 是正常的），设备用的地址来自参数管理里的 `server.websocket`、`server.ota`。这两项为 `null` 时 manager-api 会自动探测，可能下发旧网络的残留 IP，设备直接连不上；`server.websocket` 为空时 OTA 的 GET 自检还会报「缺少 websocket 地址」。换 Wi-Fi 或换机后要重新核对，改完清 Redis 生效。

演示重置（菜单 `2` 或 `--demo`）会自动按本机局域网 IP 填好这三项，所以正常流程下不用手填；但**换网络之后必须重新核对**——IP 变了，库里存的还是旧的。单独跑 `scripts/demo/reset-demo-db.sh` 则不会填，它们会停在 `null`。

语音服务启动日志里打印的 WebSocket 地址只是它本机的探测结果（可能是 `198.18.0.1` 之类的虚拟网卡地址），设备不读这个，别据此判断配置有没有问题。自检方式：`curl http://127.0.0.1:8002/xiaozhi/ota/` 应返回「OTA接口运行正常」，或直接跑 `./start-dev.sh check-models`。

### Provider 可插拔体系

`core/providers/` 下 `asr`、`tts`、`llm`、`vllm`、`vad`、`memory`、`intent`、`tools` 各有 `base.py` 抽象基类与多平台实现，由配置 `selected_module`（VAD/ASR/LLM/VLLM/TTS/Memory/Intent）选择具体实现。新增平台 = 加一个实现文件 + 配置项，不改核心。`core/utils/modules_initialize.py` 负责按需实例化。

### 连接级编排

`core/connection.py` 的 `ConnectionHandler` 是核心：每个设备连接独立持有对话状态与模块实例。`_initialize_components()` 后 `_initialize_private_config_async()` 会用设备私有配置覆盖 `selected_module` 各项（每台设备可用不同智能体/模型/音色）。`chat()` 驱动 LLM 流式输出、工具调用与 TTS 分句；`handle_restart` 支持热重启，`WebSocketServer.update_config()` 支持配置热更新并重建 VAD/ASR/LLM/Memory/Intent 实例。

消息入口：`core/websocket_server.py` 解析 `/xiaozhi/v1/` 握手与鉴权，`core/handle/` 下按职责分文件（收发音频、文本消息注册表、意图、打断、上报），`core/api/` 提供 OTA 与 Vision 的 aiohttp 路由。

### 端到端语音（S2S）走 ASR 槽位

`core/providers/s2s/` 是豆包端到端实时语音（RealtimeAPI）的接入层（协议编解码 / WebSocket 客户端 / StartSession 配置 / 工具桥接），编排器是 `core/providers/asr/doubao_realtime.py`，通过 `selected_module.ASR: DoubaoRealtime` 启用。详见 `docs/doubao-realtime-s2s-integration.md`。

它占用 ASR 槽位而非新增槽位，因为音频入口就是 `conn.asr.receive_audio`；模型返回的音频重新塞回 `conn.tts.tts_audio_queue`，从而复用既有流控、字幕、情绪消息与上报链路——**设备侧协议与前端零改动**。启用后 TTS 不参与实时链路，LLM 仅用于记忆总结、聊天标题与工具路由。端到端模型不支持 function_call，工具由旁路 LLM 判定后经 `ChatRAGText` 注入，期间模型的闲聊音频先缓存在 `DefaultAudioGate` 里，判定超时/缓存满/本轮已结束三种情况都会放行。

### 工具体系两层

`plugins_func/` 是插件层：`loadplugins.py` 启动时自动导入 `functions/` 下全部模块，函数用 `@register_function(name, desc, type)` 装饰即注册，`ToolType` 决定调用后行为（NONE/WAIT/CHANGE_SYS_PROMPT/SYSTEM_CTL/IOT_CTL/MCP_CLIENT，后三者需传 `conn`）。新增工具只需在 `functions/` 加文件。

`core/providers/tools/` 是统一调度层：`unified_tool_manager.py` 按 `ToolType` 注册各 executor（`server_plugins`、`device_iot`、`device_mcp`、`server_mcp`、`mcp_endpoint`），对 LLM 暴露统一的 function 列表。

### manager-api 结构约定

`xiaozhi/common/` 放框架层（BaseEntity/BaseDao/CrudService、Shiro 鉴权、Redis、XSS、SM2/AES、统一 `Result`），`xiaozhi/modules/` 按业务分包（agent、config、device、model、timbre、voiceclone、knowledge、correctword、llm、sms、sys、security），每包内 controller/service/dao/entity/dto/vo 分层。MyBatis-Plus mapper XML 在 `resources/mapper/`。

数据库结构由 Liquibase 管理：`resources/db/changelog/db.changelog-master.yaml` 引用按日期命名的 SQL（如 `202607260900.sql`）。改表结构必须新增 changelog 文件并注册到 master，不要改历史文件、不要手工改库。

### 前端约定

`manager-web` 走 vue-cli，devServer 把 `/xiaozhi` 代理到 `VUE_APP_DEV_PROXY_TARGET`（默认 `http://127.0.0.1:8002`）。API 按业务拆在 `src/apis/module/*.js`，统一走 `httpRequest.js`。生产构建可选 CDN 外链（`VUE_APP_USE_CDN=true`，Vue/Element/axios 走 unpkg）与 Workbox Service Worker，改依赖版本时注意 `vue.config.js` 里的 `cdnResources` 需同步。

`manager-mobile` 用 alova 请求、pinia 状态、wot-design-uni 组件；`pnpm type-check`、`pnpm lint:fix` 可用。

## 其它

- 集成类文档都在 `docs/`（MCP 接入点、RAGFlow、声纹、MQTT 网关、OTA、各家 TTS 等），排查第三方接入优先查这里。
- `prompt-example/` 是演示基线用到的角色提示词，改动会影响演示初始化校验。
- 上游参考项目为 `xiaozhi-esp32-server`（MIT），本仓库已大量重构，遇到与上游文档不一致时以本仓库代码为准。
