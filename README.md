<h1 align="center">YunShu-Link-Server（云枢·链）</h1>

<p align="center">
面向 ESP32 智能语音硬件的自研后端服务<br/>
打通「语音识别 → 大模型 → 语音合成」全链路，支持声纹识别、意图理解、工具调用与知识库<br/>
基于人机共生智能理念，提供 WebSocket、MQTT+UDP、MCP 多协议接入
</p>

<p align="center">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-black">
  <img alt="python" src="https://img.shields.io/badge/Python-3.10-blue">
  <img alt="java" src="https://img.shields.io/badge/Java-21-orange">
  <img alt="springboot" src="https://img.shields.io/badge/Spring%20Boot-3.4-green">
  <img alt="vue" src="https://img.shields.io/badge/Vue-2%20%2F%203-42b883">
</p>

---

## 项目简介

**YunShu-Link-Server** 是一套面向 [ESP32](https://github.com/78/xiaozhi-esp32) 智能语音硬件的自研后端服务，为语音终端提供完整的实时对话能力与设备管理能力。

项目采用「实时语音管线」与「控制台管理」分层解耦的架构：Python 侧负责低延迟的语音交互链路，Java 侧负责多用户 / 多智能体 / 多设备的配置管理与下发，前端提供 Web 与移动端两套控制台。整体面向**可插拔、可扩展**设计——ASR、LLM、TTS、记忆、意图等每一类能力都以「提供者（Provider）」形式接入，新增一个平台无需改动核心逻辑。

> 本项目在开源社区方案的基础上进行了大量二次开发与重构，后端交互逻辑、模块编排、工具调用与配置体系均为独立实现。仅供学习与研究使用，未经安全评测，请勿直接用于生产环境。

---

## 核心特性

| 能力 | 说明 |
|------|------|
| 🎙️ 实时语音交互 | 流式 ASR + 流式 TTS + VAD 语音活动检测，支持多语言与实时打断 |
| 🧠 智能对话 | 兼容任意 OpenAI 接口协议的 LLM，支持 Ollama / Dify / Coze / FastGPT / Xinference |
| 👁️ 视觉感知 | 接入 VLLM 视觉大模型，实现拍照识物等多模态交互 |
| 🗣️ 声纹识别 | 多用户声纹注册与识别，与 ASR 并行，实时区分说话人并个性化回应 |
| 🎯 意图理解 | 大模型函数调用（function_call）/ 独立意图识别 / 无意图三种模式 |
| 🧩 工具调用 | 支持 IoT 协议、客户端 MCP、服务端 MCP、MCP 接入点，以及自定义插件函数 |
| 💾 记忆系统 | 本地短期记忆 / mem0ai / PowerMem 智能记忆，具备记忆总结能力 |
| 📚 知识库 | 接入 RAGFlow，让模型自主判断是否检索知识库后再回答 |
| 📡 指令下发 | 依托 MQTT 从控制台向 ESP32 设备下发 MCP 指令 |
| 🖥️ 控制台 | Web + 移动端双端管理，支持用户 / 设备 / 智能体 / 模型配置，多语言界面 |
| 🔌 插件热加载 | 启动时自动扫描注册插件函数，支持自定义扩展 |

---

## 技术架构

项目为多语言 monorepo，代码位于 `main/` 下的四个子系统：

| 子系统 | 目录 | 技术栈 | 职责 |
|--------|------|--------|------|
| 语音核心服务 | `main/xiaozhi-server` | Python 3.10 · asyncio | WebSocket / MQTT+UDP 语音管线、OTA 与视觉 HTTP 接口 |
| 控制台后端 | `main/manager-api` | Java 21 · Spring Boot 3.4 | 用户 / 设备 / 智能体管理、配置下发、鉴权 |
| 控制台 Web | `main/manager-web` | Vue 2 · Element UI | 智控台 Web 界面 |
| 控制台移动端 | `main/manager-mobile` | uni-app（Vue 3 + TS） | App / H5 / 各平台小程序 |
| 音频测试工具 | `main/digital-human` | Python · 静态页面 | 数字人与音频交互调试 |

### 设计要点

- **Provider 可插拔体系**：`xiaozhi-server/core/providers/` 下 `asr`、`tts`、`vad`、`llm`、`vllm`、`memory`、`intent` 各有抽象基类与多平台实现，通过配置的 `selected_module` 选择，热插拔无侵入。
- **连接级编排**：`core/connection.py` 为每个设备连接维护独立的对话状态与模块实例，统一调度语音收发、工具调用与流式输出。
- **插件自动注册**：`plugins_func/` 在启动时自动导入 `functions/` 下全部插件（天气、新闻、音乐、HomeAssistant、Web 搜索、RAGFlow 检索等），新增工具函数即插即用。
- **配置双模式**：语音服务既可读取本地 `data/.config.yaml` 独立运行，也可通过 `manager-api` 从控制台动态拉取配置，适配「最简化」与「全模块」两种部署形态。

---

## 快速开始

项目支持两种部署形态：

- **最简化安装**：仅运行 `xiaozhi-server`，配置存于本地文件，无需数据库，适合个人 / 单智能体场景。
- **全模块安装**：`xiaozhi-server` + `manager-api` + `manager-web` + MySQL + Redis，支持多用户、多智能体与控制台管理。

### 1. 语音核心服务（Python）

```bash
cd main/xiaozhi-server
conda create -n yunshu-link python=3.10 -y
conda activate yunshu-link
pip install -r requirements.txt

# 将根目录 config.yaml（或 config_from_api.yaml）复制为 data/.config.yaml 并填好密钥
python app.py                    # 默认 WebSocket :8000, HTTP :8003
```
> 需预先安装 `ffmpeg`。可用 `python performance_tester.py` 测试各模块响应速度。

### 2. 控制台后端（Java / Maven）

```bash
cd main/manager-api
mvn spring-boot:run              # http://localhost:8002/xiaozhi
# API 文档：http://localhost:8002/xiaozhi/doc.html
```

### 3. 控制台 Web（Vue）

```bash
cd main/manager-web
npm install
npm run serve                    # 开发服务器 :8001，代理至后端 :8002
```

### 4. 控制台移动端（uni-app）

```bash
cd main/manager-mobile
pnpm install                     # 强制使用 pnpm
pnpm dev:h5                      # 或 pnpm dev:mp-weixin / pnpm dev:app
```

### Docker 部署

根目录提供 `docker-setup.sh` 交互式脚本；`main/xiaozhi-server/` 下有 `docker-compose.yml`（仅服务）与 `docker-compose_all.yml`（服务 + Web + MySQL + Redis）。

---

## 支持的模型与平台

| 类别 | 支持 |
|------|------|
| **LLM** | 阿里百炼、火山引擎、DeepSeek、智谱、Gemini、讯飞、Ollama、Dify、FastGPT、Coze、Xinference、HomeAssistant（及任意 OpenAI 兼容接口） |
| **VLLM** | 阿里百炼、智谱 ChatGLM VLLM（及任意 OpenAI 兼容接口） |
| **TTS** | EdgeTTS、讯飞、火山引擎、腾讯云、阿里云 / 百炼、Minimax、灵犀流式、OpenAI TTS、FishSpeech、GPT-SoVITS、Index-TTS、PaddleSpeech 等 |
| **ASR** | FunASR、SherpaASR（本地）；火山、讯飞、腾讯、阿里、百度、OpenAI（接口） |
| **VAD** | SileroVAD（本地） |
| **声纹** | 3D-Speaker（本地） |
| **记忆** | mem_local_short、mem0ai、PowerMem、nomem |
| **意图** | function_call、intent_llm、nointent |
| **知识库** | RAGFlow |

---

## 目录结构

```
YunShu-Link/
├── main/
│   ├── xiaozhi-server/     # Python 语音核心服务
│   │   ├── app.py          # 启动入口（WebSocket + HTTP）
│   │   ├── core/           # 连接编排、providers、handle、api
│   │   └── plugins_func/   # 可扩展工具函数插件
│   ├── manager-api/        # Spring Boot 控制台后端
│   ├── manager-web/        # Vue 控制台 Web
│   ├── manager-mobile/     # uni-app 控制台移动端
│   └── digital-human/      # 音频交互测试工具
├── docs/                   # 各能力集成文档
├── docker-setup.sh         # 一键部署脚本
└── CLAUDE.md               # 面向开发者的架构说明
```

更多集成细节见 `docs/` 目录（如 `mcp-endpoint-integration.md`、`ragflow-integration.md`、`voiceprint-integration.md` 等）。

---

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

本项目为独立二次开发作品，其架构参考并衍生自开源项目 [xiaozhi-esp32-server](https://github.com/xinnan-tech/xiaozhi-esp32-server)（MIT License）。按照 MIT 许可要求，已在 LICENSE 中保留原始版权声明。
