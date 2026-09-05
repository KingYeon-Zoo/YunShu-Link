# Docker 全源码开发一键启动脚本设计

## 目标

为 YunShu-Link 提供一个面向 macOS/Linux 的一键开发启动脚本。宿主机只依赖 Docker 与 Docker Compose，不要求安装 Java、Maven、Node.js、Python 或 FFmpeg。启动后的前端、Java 管理后端和 Python 核心服务均来自当前工作区源码，便于进行简单的前后端修改。

## 使用界面

根目录新增 `start-dev.sh`，支持以下命令：

```bash
./start-dev.sh
./start-dev.sh start
./start-dev.sh stop
./start-dev.sh restart
./start-dev.sh status
./start-dev.sh logs
```

无参数时等同于 `start`。`start` 会基于 Docker 缓存构建本地源码镜像、初始化运行配置并以后台方式启动完整服务。修改源码后再次运行 `start`，即可重建受影响的镜像并更新容器。

## 架构

新增开发专用 Compose 文件，复用现有生产 Compose 的服务拓扑，但将应用服务切换为本地构建：

- `manager-web` 与 `manager-api` 继续由一个容器承载，使用根目录 `Dockerfile-web` 构建。该镜像在构建阶段用 Node 编译当前 Vue 源码、用 Maven 编译当前 Java 源码，运行阶段由 Nginx 提供前端并代理 Java API。
- `xiaozhi-server` 使用根目录 `Dockerfile-server` 构建，代码来自当前 Python 源码。Python、依赖和 FFmpeg 均位于镜像内。
- MySQL 与 Redis 沿用现有镜像、卷和健康检查。

开发镜像使用独立的本地标签，避免覆盖或误用仓库默认的远程发布镜像。数据库和上传文件继续使用现有持久化目录，停止、重建应用镜像不会删除数据。

## 启动流程

脚本按以下顺序执行：

1. 定位仓库根目录，检查 Docker CLI、Docker Compose 和 Docker daemon。
2. 创建必要的 `data`、模型、上传文件和运行目录。
3. 若缺少 `models/SenseVoiceSmall/model.pt`，通过临时 Docker 容器下载模型，不依赖宿主机 `curl`。
4. 构建并启动 MySQL、Redis 以及包含本地前端和 Java 源码的 Web/API 容器。
5. 等待数据库健康且 manager-api 可访问；超时则输出相关容器日志并以非零状态退出。
6. 从 MySQL 的 `sys_params` 表读取 manager-api 自动生成的 `server.secret`。
7. 若 `data/.config.yaml` 不存在，则从 `config_from_api.yaml` 创建；随后只更新 `manager-api.url` 与 `manager-api.secret`，保留其他用户配置。
8. 构建并启动包含本地 Python 源码的 `xiaozhi-server` 容器。
9. 等待控制台、WebSocket 端口和 HTTP 接口就绪，最后打印访问地址与常用命令。

`stop` 只停止并移除本开发 Compose 项目的容器和网络，不删除数据库卷、模型、配置或上传文件。`restart` 等同于先停止再执行完整启动。`status` 显示 Compose 服务状态，`logs` 跟随完整服务日志。

## 配置处理

实际运行配置仍位于 `main/xiaozhi-server/data/.config.yaml`，并继续受 `.gitignore` 保护。

脚本不改动默认模板 `config.yaml` 和 `config_from_api.yaml`。首次运行时复制 API 模式模板；后续运行只同步以下两个字段：

- `manager-api.url` 固定为容器网络内的 `http://xiaozhi-esp32-server-web:8002/xiaozhi`。
- `manager-api.secret` 使用当前数据库中的 `server.secret`。

更新前保存一份临时备份；若配置结构不符合 API 模式或无法安全更新，脚本停止并给出中文错误，不覆盖现有配置。

## 构建缓存与修改反馈

运行 `start` 时始终调用 Compose 的 `--build`，由 Docker 判断缓存是否可复用：

- 仅修改 Python 代码时，server 基础依赖层复用，只更新应用代码层。
- 修改 Vue 或 Java 代码时，Web/API 镜像会重新执行对应构建阶段。
- 未修改源码时，各构建层直接命中缓存。

本方案不提供宿主机热更新。它以“不向宿主机安装开发运行时”为优先目标，代码修改后的反馈方式是重新执行同一个启动命令。

## 错误处理

- Docker 未安装或 daemon 未启动：立即退出，提示用户启动 Docker Desktop。
- 镜像构建失败：保留 Docker 原始构建输出并退出，不继续启动旧容器冒充新代码。
- 模型下载失败：删除不完整临时文件，保留已有有效模型。
- manager-api 初始化超时：打印 Web/API、MySQL、Redis 的近期日志。
- 无法读取 `server.secret`：不启动 Python 服务，提示查看 manager-api 日志。
- 端口冲突或服务健康检查失败：返回非零状态并列出 Compose 状态。
- 用户中断：不删除持久化数据；已经启动的后台容器保持可检查状态。

## 验证策略

实现采用可注入环境变量和小型 shell 函数，使关键路径能在不真正下载镜像的情况下测试。验证包括：

- Shell 语法检查。
- 命令分发测试：默认命令、`start`、`stop`、`restart`、`status`、`logs` 和非法命令。
- 前置条件失败测试：Docker 缺失、daemon 不可用、配置结构不安全。
- 配置初始化测试：从模板创建配置、写入容器 API 地址和密钥、再次运行保持幂等。
- Compose 合并配置检查，确认应用服务使用本地 `build`，端口、卷和依赖关系正确。
- 在可用 Docker 环境下执行构建/启动验证；若受镜像网络或运行时资源限制，明确报告未完成的实机验证项及原始错误。

## 非目标

- 不自动安装或升级 Docker Desktop。
- 不向宿主机安装 Java、Maven、Node.js、Python、FFmpeg 或其他开发工具。
- 不修改现有生产 Compose 文件及远程镜像部署行为。
- 不删除数据库、模型、密钥、上传文件或其他持久化数据。
- 不提供源码热更新或断点调试容器；简单修改通过缓存重建生效。
