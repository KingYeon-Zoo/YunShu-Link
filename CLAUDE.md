# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

本项目为开源硬件项目 [xiaozhi-esp32](https://github.com/78/xiaozhi-esp32) 提供后端服务，是一个多语言 monorepo，实现了完整的语音交互链路（ASR → LLM/VLLM → TTS）、控制台管理与设备接入。

## 仓库结构

代码分布在 `main/` 下的四个独立子项目，每个有各自的技术栈和构建方式：

| 目录 | 语言/框架 | 职责 |
|------|-----------|------|
| `main/xiaozhi-server` | Python 3.10 (asyncio) | 核心实时服务：WebSocket/MQTT+UDP 语音管线、OTA/Vision HTTP 接口 |
| `main/manager-api` | Java 21 / Spring Boot 3.4 | 控制台后端：用户/设备/智能体管理、配置下发、鉴权 |
| `main/manager-web` | Vue 2 + Element UI | 智控台 Web 界面 |
| `main/manager-mobile` | uni-app (Vue 3 + TS) | 智控台移动端（App/H5/各家小程序） |
| `main/digital-human` | Python + 静态页面 | 数字人/音频交互测试工具 |

## 部署模式（理解架构的关键）

项目有两种部署形态，直接决定了 `xiaozhi-server` 的配置来源：

- **最简化安装**：只运行 `xiaozhi-server`，配置全部来自本地 `data/.config.yaml`，无需数据库。
- **全模块安装**：`xiaozhi-server` + `manager-api` + `manager-web` + MySQL + Redis。此时 `xiaozhi-server` 通过 `manager-api` 动态拉取配置。

配置加载逻辑见 [config_loader.py](main/xiaozhi-server/config/config_loader.py)：若 `data/.config.yaml` 中配置了 `manager-api.url`，则调用 [get_config_from_api_async](main/xiaozhi-server/config/config_loader.py:55) 从 Java 侧拉取配置（`read_config_from_api=True`）；否则将默认 `config.yaml` 与本地 `.config.yaml` 合并。**两种模式互斥**——同时存在 `manager-api` 配置和 `selected_module` 本地配置会报错（见 [settings.py](main/xiaozhi-server/config/settings.py)）。

模板文件：`config.yaml`（默认全量配置，勿直接改）、`config_from_api.yaml`（全模块模式下复制为 `data/.config.yaml` 的模板）。**实际运行配置放在 `data/.config.yaml`，不进版本库。**

## 常用命令

### xiaozhi-server (Python)
```bash
cd main/xiaozhi-server
conda create -n xiaozhi-esp32-server python=3.10 -y   # 推荐 python3.10
pip install -r requirements.txt
python app.py                     # 启动服务（默认 ws :8000, http :8003）
python performance_tester.py      # 测试 ASR/LLM/VLLM/TTS 各模块响应速度
```
需系统安装 `ffmpeg`（[app.py](main/xiaozhi-server/app.py) 启动时会 `check_ffmpeg_installed`）。

### manager-api (Java / Maven)
```bash
cd main/manager-api
mvn spring-boot:run               # 启动，服务在 http://localhost:8002/xiaozhi
mvn test                          # 全部测试
mvn test -Dtest=AESUtilsTest      # 单个测试类
mvn test -Dtest=DeviceTest#methodName   # 单个测试方法
mvn clean package                 # 打包 jar
```
入口类 [AdminApplication.java](main/manager-api/src/main/java/xiaozhi/AdminApplication.java)。API 文档：`http://localhost:8002/xiaozhi/doc.html`（Knife4j）。数据库 schema 由 Liquibase 管理，变更脚本在 `src/main/resources/db/changelog/`（按日期命名，新增迁移需追加到 changelog）。

### manager-web (Vue 2)
```bash
cd main/manager-web
npm install
npm run serve                     # 开发服务器 :8001，代理 /xiaozhi -> 127.0.0.1:8002
npm run build
```

### manager-mobile (uni-app)
```bash
cd main/manager-mobile
pnpm install                      # 强制使用 pnpm（preinstall 有 only-allow）
pnpm dev:h5                       # H5 开发
pnpm dev:mp-weixin                # 微信小程序
pnpm dev:app                      # App
```

### Docker
根目录 `docker-setup.sh` 为交互式部署脚本。Compose 文件在 `main/xiaozhi-server/`：`docker-compose.yml`（仅 server）与 `docker-compose_all.yml`（server + web + mysql + redis）。镜像构建见 `Dockerfile-server` / `Dockerfile-web`。

## xiaozhi-server 内部架构

这是最复杂的子系统，采用**提供者（Provider）+ 插件（Plugin）**的可插拔模式。

### 连接与管线
- [app.py](main/xiaozhi-server/app.py) 同时启动 `WebSocketServer` 和 `SimpleHttpServer`（OTA + Vision 接口）。
- [core/connection.py](main/xiaozhi-server/core/connection.py) 是单个设备连接的核心编排器：每个连接持有独立的 ASR/LLM/TTS/Memory/Intent 实例，管理对话状态、工具调用、TTS 流式输出。
- [core/websocket_server.py](main/xiaozhi-server/core/websocket_server.py) 处理 WebSocket 握手与鉴权（[core/auth.py](main/xiaozhi-server/core/auth.py)）。

### Provider 体系（`core/providers/`）
每类能力有一个抽象 `base.py` 和多个平台实现，通过配置的 `selected_module` 选择：
- `asr/` 语音识别、`tts/` 语音合成（含多种流式实现，如 `huoshan_double_stream`、`xunfei_stream`）、`vad/` 语音活动检测、`llm/` 大模型、`vllm/` 视觉模型、`memory/`（`mem_local_short`/`mem0ai`/`powermem`/`nomem`）、`intent/`（`function_call`/`intent_llm`/`nointent`）、`tools/` 统一工具处理。
- 新增一个平台支持 = 在对应目录下继承 `base.py` 新建实现文件，无需改动核心。

### 消息处理（`core/handle/`）
文本消息经由 `textMessageHandlerRegistry` + `textMessageProcessor` 分发；音频收发在 `receiveAudioHandle.py` / `sendAudioHandle.py`；意图路由在 `intentHandler.py`。

### 插件/函数调用（`plugins_func/`）
- [loadplugins.py](main/xiaozhi-server/plugins_func/loadplugins.py) 通过 `auto_import_modules("plugins_func.functions")` 在启动时**自动导入并注册** `functions/` 下的所有插件（天气、新闻、音乐、HomeAssistant、RAGFlow 检索、Web 搜索等）。
- 新增工具函数 = 在 `plugins_func/functions/` 下新建文件并用 [register.py](main/xiaozhi-server/plugins_func/register.py) 的装饰器注册，即被 LLM 的 function_call 意图识别调用。

## manager-api 内部架构（Spring Boot）

- 按业务模块分包：`src/main/java/xiaozhi/modules/`（`agent` 智能体、`device` 设备、`model` 模型配置、`sys` 系统、`timbre` 音色、`knowledge` 知识库、`voiceclone` 声纹克隆、`sms`、`llm`、`config` 等）；通用能力在 `xiaozhi/common/`。
- 鉴权用 **Apache Shiro**，ORM 用 **MyBatis-Plus**（Mapper XML 在 `resources/mapper/`），缓存用 Redis，连接池用 Druid。
- `xiaozhi-server` 通过 [manage_api_client.py](main/xiaozhi-server/config/manage_api_client.py) 用 `manager-api.secret` 调用本模块拉取设备私有配置。

## 约定与注意事项

- **语言**：Python 端代码与注释多为中文；Java 端遵循标准 Spring 分层（controller/service/dao/entity/dto）。修改时保持各子项目既有风格。
- **端口约定**：server ws `8000` / http `8003`，manager-api `8002`，manager-web dev `8001`，digital-human 测试 `8006`。
- **不要提交**：`data/.config.yaml`（含密钥与选型），各子项目的构建产物、`node_modules`、`target/`。
- **数据库变更**：只通过新增 Liquibase changelog 脚本，不手改已有脚本。
- 详细的模型选型、平台接入说明见根目录 [README.md](README.md) 与 `docs/` 下各集成文档（如 `mcp-endpoint-integration.md`、`ragflow-integration.md`、`voiceprint-integration.md`）。
