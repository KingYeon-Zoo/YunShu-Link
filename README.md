<p align="center">
  <img src="main/manager-web/src/assets/brand/yunshu-link-logo.png" width="240" alt="YunShu-Link 云枢" />
</p>

# YunShu-Link 云枢

**面向 ESP32 智能硬件的交互服务端：在一个控制台中配置设备、智能体、模型与知识库，运行实时语音和工具调用。**

设备接入后，系统为会话装配模型与工具，将声音交给推理服务，再把语音回复或设备控制指令送回终端。云枢同时提供管理控制台，方便维护不同设备使用的角色与能力配置。

<p align="center">
  <img src="web%20端图片/首页（控制台界面）.png" width="100%" alt="实际控制台：智能体列表、设备关联与模型配置" />
</p>

[观看演示](https://github.com/KingYeon-Zoo/YunShu-Link/releases/tag/demo-2026) · [机器人固件](https://github.com/KingYeon-Zoo/YunShu-Link-Firmware) · [核心设计](#核心设计) · [部署入口](#部署入口)

## 从控制台到设备

<table>
  <tr>
    <td width="50%"><img src="web%20端图片/角色配置界面.png" alt="配置智能体角色与能力" /></td>
    <td width="50%"><img src="web%20端图片/知识库界面.png" alt="管理知识库与检索内容" /></td>
  </tr>
  <tr>
    <td align="center">为设备选择角色、模型与工具</td>
    <td align="center">维护可供对话使用的知识库</td>
  </tr>
</table>

<p align="center">
  <img src="实物图片/1.jpg" width="24%" alt="机器人实物正面" />
  <img src="实物图片/2.jpg" width="24%" alt="机器人实物侧面" />
  <img src="实物图片/3.jpg" width="24%" alt="机器人交互状态" />
</p>

演示展示了控制台、实时语音与终端动作。更多界面见 [Web 截图](web%20端图片/)，硬件实现见[固件仓库](https://github.com/KingYeon-Zoo/YunShu-Link-Firmware)。

## 核心设计

### 实时交互与管理业务分开运行

Python 服务维护设备连接、对话上下文、流式音频和模型调用。Spring Boot 服务处理设备、用户、智能体配置与管理数据，Vue 控制台提供操作入口。

两部分按接口交换配置与消息，便于分别调整模型接入和管理功能。只需要语音交互时，也可以使用本地配置运行 Python 服务。

### 模型与工具按配置装配

语音识别、语言模型、语音合成、记忆和意图处理使用 Provider 接口。设备会话读取对应配置，选择实现并初始化模块。

工具层统一管理函数调用、服务端 MCP 与设备端 MCP。业务可以更换模型服务或增加工具，设备通信链路沿用已有协议。

### 设备执行与云端推理解耦

服务端处理 ASR、LLM、TTS 与工具决策，设备固件处理音频播放、显示和执行。设备 MCP 负责发现并调用终端公开的能力；工具结果回到会话继续处理。

公开实现包含多设备与多智能体的配置管理，以及连接级的独立会话处理。具体的跨设备联动需要结合对应设备工具与业务逻辑配置。

## 代码导览

| 模块 | 实现入口 |
| --- | --- |
| 设备连接、会话状态与模块初始化 | [connection.py](main/xiaozhi-server/core/connection.py) |
| 模型与能力接入 | [providers/](main/xiaozhi-server/core/providers/) |
| 统一工具管理 | [unified_tool_manager.py](main/xiaozhi-server/core/providers/tools/unified_tool_manager.py) |
| 设备 MCP 调用 | [device_mcp/](main/xiaozhi-server/core/providers/tools/device_mcp/) |
| Spring Boot 管理服务 | [manager-api/](main/manager-api/) |
| Web 控制台 | [manager-web/](main/manager-web/) |

主要技术为 Python、Spring Boot、Vue、WebSocket、MQTT / UDP 与 MCP。知识库、记忆及不同模型接入的配置说明保留在 `docs/`。

## 部署入口

```bash
git clone https://github.com/KingYeon-Zoo/YunShu-Link.git
cd YunShu-Link
```

按使用目的选择部署方式：

| 方式 | 适用场景 | 操作说明 |
| --- | --- | --- |
| 最简化服务 | 先连通一台设备，使用本地配置运行语音链路 | [最简化部署](docs/Deployment.md) |
| 全模块部署 | 使用管理控制台、数据库和多设备配置 | [全模块部署](docs/Deployment_all.md) |
| 开发环境 | 修改前端或 Python 模型接口 | [开发与运维说明](docs/dev-ops-integration.md) |

仓库提供 [docker-setup.sh](docker-setup.sh) 和 [start-dev.sh](start-dev.sh)。运行前先阅读对应部署说明，准备模型服务凭证、数据库与设备连接地址；离线语音识别还需要对应模型文件。

## 项目来源与改造

项目基于 [xiaozhi-esp32-server](https://github.com/xinnan-tech/xiaozhi-esp32-server) 二次开发。云枢的工作围绕机器人演示场景展开，包括模型接入、实时语音服务集成、工具与知识库配置、控制台设计和部署流程整理。

保留上游通用通信与服务框架，并在代码导览中给出各模块入口。设备端适配单独放在 [YunShu-Link-Firmware](https://github.com/KingYeon-Zoo/YunShu-Link-Firmware) 中。许可证与版权声明见 [LICENSE](LICENSE)。

进一步了解：[实时语音接入](docs/doubao-realtime-s2s-integration.md)、[知识库接入](docs/ragflow-integration.md)、[设备视觉与 MCP](docs/mcp-vision-integration.md)。
