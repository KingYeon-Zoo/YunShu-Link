# 前端热更新轻量启动器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使用独立 Docker 前端开发容器提供 8001 热更新，避免前端改动触发 Java/Web 组合镜像重建。

**Architecture:** `web-dev` 使用 Node 20、源码 bind mount 和独立 `node_modules` 命名卷运行 Vue CLI；API 请求代理到 Compose 网络中的 `manager:8002`。`start-fast-dev.sh` 只启动或重启现有容器，不带 `--build`；现有 `start-dev.sh` 继续负责首次初始化和全量重建。

**Tech Stack:** POSIX Shell、Docker Compose、Node 20、Vue CLI 5

## Global Constraints

- 所有用户可见输出和注释使用简体中文。
- 不删除 MySQL 数据、模型、配置、上传文件或前端依赖卷。
- 日常 `start` 和 `restart-web` 不触发 Docker 镜像构建。
- 宿主机不创建或管理 Node 后台进程。
- 保存前端源码后必须能通过 Docker bind mount 触发热更新。

---

### Task 1: 定义失败测试

**Files:**
- Create: `scripts/tests/test-start-fast-dev.sh`

**Interfaces:**
- Consumes: `start_services()`、`restart_frontend()`。
- Produces: 无构建启动与独立热更新服务的回归测试。

- [x] **Step 1: 验证轻量启动命令**

使用替身 Docker 命令验证 `start_services` 执行 `compose up -d mysql redis manager server web-dev` 且不包含 `--build`。

- [x] **Step 2: 验证 Compose 热更新结构**

运行 `docker compose -f docker-compose.dev.yml config`，验证存在 `web-dev`、`VUE_APP_DEV_PROXY_TARGET=http://manager:8002` 和 `/app/node_modules` 命名卷挂载。

- [x] **Step 3: 观察测试失败**

Run: `sh scripts/tests/test-start-fast-dev.sh`

Expected: `start_services: command not found` 或缺少 `web-dev`。

### Task 2: 实现独立热更新服务与脚本

**Files:**
- Modify: `docker-compose.dev.yml`
- Modify: `main/manager-web/vue.config.js`
- Create: `start-fast-dev.sh`
- Modify: `README.md`

**Interfaces:**
- `start_services()`：无构建启动 `mysql redis manager server web-dev`。
- `restart_frontend()`：只执行 `compose restart web-dev`。
- `dispatch()`：支持 `start|stop|restart-web|status|logs|rebuild`。

- [x] **Step 1: 添加 `web-dev` Compose 服务**

使用 `node:20`，挂载 `./main/manager-web:/app` 与 `manager_web_node_modules:/app/node_modules`；首次缺少 Vue CLI 时运行 `npm install`，随后在 `0.0.0.0:8001` 启动 Vue CLI。

- [x] **Step 2: 支持容器内 API 代理**

将 `vue.config.js` 的代理目标改为 `process.env.VUE_APP_DEV_PROXY_TARGET || 'http://127.0.0.1:8002'`。

- [x] **Step 3: 实现轻量命令分发**

`start` 无构建启动全部开发服务；`restart-web` 只重启 `web-dev`；`rebuild` 调用原有全量脚本后启动 `web-dev`。

- [x] **Step 4: 验证**

Run:

```bash
sh -n start-fast-dev.sh
sh scripts/tests/test-start-fast-dev.sh
./start-fast-dev.sh start
curl -I http://127.0.0.1:8001
./start-fast-dev.sh restart-web
```

Expected: 测试通过，8001 返回 HTTP 200，`restart-web` 后容器恢复运行且未构建镜像。
