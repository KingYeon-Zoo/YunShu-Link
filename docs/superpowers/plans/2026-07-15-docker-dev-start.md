# Docker 全源码开发一键启动脚本实施计划

> **面向执行者：** 必须使用 `superpowers:executing-plans` 按任务逐项执行；每一步使用复选框跟踪，并严格遵循测试先行。

**目标：** 提供只依赖 Docker 的一键开发启动器，使 Vue、Java 和 Python 服务均从当前工作区源码构建运行。

**架构：** 根目录开发 Compose 文件负责本地构建两个应用镜像并运行 MySQL/Redis；根目录 POSIX Shell 启动器负责模型准备、分阶段启动、密钥同步、健康检查和运维子命令。Shell 逻辑允许在测试中仅加载函数，以便用临时目录和替身命令验证而不启动真实容器。

**技术栈：** POSIX Shell、Docker Compose、Docker 多阶段构建、Vue 2、Spring Boot 3.4、Python 3.10、MySQL、Redis。

## 全局约束

- 所有用户可见输出、注释和文档使用简体中文。
- 宿主机只要求 Docker 与 Docker Compose，不安装 Java、Maven、Node.js、Python 或 FFmpeg。
- 不修改 `docker-compose_all.yml`、`config.yaml`、`config_from_api.yaml` 的现有行为。
- 不删除数据库、模型、配置、上传文件或其他持久化数据。
- 无参数等同于 `start`；支持 `start`、`stop`、`restart`、`status`、`logs`。
- 实际配置写入忽略版本控制的 `main/xiaozhi-server/data/.config.yaml`。
- 应用镜像必须使用本地源码构建和独立开发标签。

---

## 文件结构

- 新建 `docker-compose.dev.yml`：定义开发环境四个容器、本地构建、端口、卷、依赖与健康检查。
- 新建 `start-dev.sh`：唯一用户入口；包含可测试的配置处理、Docker 编排、等待和命令分发函数。
- 新建 `scripts/tests/test-start-dev.sh`：不依赖第三方测试框架的 Shell 回归测试。
- 修改 `README.md`：增加 Docker 全源码开发启动说明。

### 任务 1：开发 Compose 拓扑

**文件：**

- 新建：`docker-compose.dev.yml`
- 新建：`scripts/tests/test-start-dev.sh`

**接口：**

- 产出 Compose 服务名：`server`、`manager`、`mysql`、`redis`。
- `manager` 提供网络别名 `xiaozhi-esp32-server-web`，供 Python 配置使用。
- `server` 暴露 `8000`、`8003`，`manager` 暴露 `8002`。

- [ ] **步骤 1：写 Compose 结构失败测试**

在 `scripts/tests/test-start-dev.sh` 中建立最小测试框架，并验证 Compose 渲染结果：

```sh
#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TEST_COUNT=0

pass() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf '通过：%s\n' "$1"
}

fail() {
  printf '失败：%s\n' "$1" >&2
  exit 1
}

test_compose_config() {
  output=$(docker compose -f "$ROOT_DIR/docker-compose.dev.yml" config 2>&1) || {
    printf '%s\n' "$output" >&2
    fail '开发 Compose 配置应可渲染'
  }
  printf '%s\n' "$output" | grep -q 'dockerfile: Dockerfile-web' || fail 'manager 应使用 Dockerfile-web'
  printf '%s\n' "$output" | grep -q 'dockerfile: Dockerfile-server' || fail 'server 应使用 Dockerfile-server'
  printf '%s\n' "$output" | grep -q 'yunshu-link/manager-web-api:dev' || fail 'manager 应使用开发镜像标签'
  printf '%s\n' "$output" | grep -q 'yunshu-link/xiaozhi-server:dev' || fail 'server 应使用开发镜像标签'
  pass '开发 Compose 使用本地源码镜像'
}

test_compose_config
printf '共通过 %s 项测试。\n' "$TEST_COUNT"
```

- [ ] **步骤 2：运行测试并确认正确失败**

运行：

```bash
sh scripts/tests/test-start-dev.sh
```

预期：失败，提示 `docker-compose.dev.yml` 不存在或无法渲染。

- [ ] **步骤 3：编写最小 Compose 配置**

新建 `docker-compose.dev.yml`，完整内容如下：

```yaml
name: yunshu-link-dev

services:
  server:
    image: yunshu-link/xiaozhi-server:dev
    build:
      context: .
      dockerfile: Dockerfile-server
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      manager:
        condition: service_started
    restart: unless-stopped
    ports:
      - "8000:8000"
      - "8003:8003"
    security_opt:
      - seccomp:unconfined
    environment:
      TZ: Asia/Shanghai
    volumes:
      - ./main/xiaozhi-server/data:/opt/xiaozhi-esp32-server/data
      - ./main/xiaozhi-server/models/SenseVoiceSmall/model.pt:/opt/xiaozhi-esp32-server/models/SenseVoiceSmall/model.pt

  manager:
    image: yunshu-link/manager-web-api:dev
    build:
      context: .
      dockerfile: Dockerfile-web
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    ports:
      - "8002:8002"
    environment:
      TZ: Asia/Shanghai
      SPRING_DATASOURCE_DRUID_URL: jdbc:mysql://mysql:3306/xiaozhi_esp32_server?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai&nullCatalogMeansCurrent=true&connectTimeout=30000&socketTimeout=30000&autoReconnect=true&failOverReadOnly=false&maxReconnects=10
      SPRING_DATASOURCE_DRUID_USERNAME: root
      SPRING_DATASOURCE_DRUID_PASSWORD: "123456"
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PASSWORD: ""
      SPRING_DATA_REDIS_PORT: "6379"
    volumes:
      - ./main/xiaozhi-server/uploadfile:/uploadfile
    networks:
      default:
        aliases:
          - xiaozhi-esp32-server-web

  mysql:
    image: mysql:latest
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-p123456"]
      timeout: 5s
      interval: 5s
      retries: 20
    environment:
      TZ: Asia/Shanghai
      MYSQL_ROOT_PASSWORD: "123456"
      MYSQL_DATABASE: xiaozhi_esp32_server
    volumes:
      - ./main/xiaozhi-server/mysql/data:/var/lib/mysql

  redis:
    image: redis:8.0
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 10
```

- [ ] **步骤 4：运行测试并确认通过**

运行：`sh scripts/tests/test-start-dev.sh`

预期：输出 `通过：开发 Compose 使用本地源码镜像`，退出码为 0。

- [ ] **步骤 5：提交 Compose 与测试**

```bash
git add docker-compose.dev.yml scripts/tests/test-start-dev.sh
git commit -m "feat: 添加 Docker 全源码开发编排"
```

### 任务 2：一键启动与安全配置同步

**文件：**

- 新建：`start-dev.sh`
- 修改：`scripts/tests/test-start-dev.sh`

**接口：**

- `update_manager_config CONFIG_FILE API_URL SECRET`：安全更新现有 API 模式 YAML，成功返回 0，结构不符返回非零。
- `dispatch COMMAND`：分发 `start|stop|restart|status|logs`；空字符串视为 `start`。
- 环境变量 `DOCKER_DEV_SOURCE_ONLY=1`：加载函数但不自动执行入口，供测试使用。
- 环境变量 `DOCKER_BIN`、`COMPOSE_FILE`：测试可注入替身路径。

- [ ] **步骤 1：写配置同步与命令分发失败测试**

在已有测试脚本追加：

```sh
test_config_update() {
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
  config="$tmp_dir/.config.yaml"
  cat >"$config" <<'YAML'
server:
  port: 8000
manager-api:
  url: http://old.example/xiaozhi
  secret: old-secret
prompt_template: agent-base-prompt.txt
YAML

  DOCKER_DEV_SOURCE_ONLY=1 . "$ROOT_DIR/start-dev.sh"
  update_manager_config "$config" 'http://xiaozhi-esp32-server-web:8002/xiaozhi' 'new-secret'

  grep -q '^  url: http://xiaozhi-esp32-server-web:8002/xiaozhi$' "$config" || fail '应更新 manager-api.url'
  grep -q '^  secret: new-secret$' "$config" || fail '应更新 manager-api.secret'
  grep -q '^  port: 8000$' "$config" || fail '应保留其他配置'
  pass '配置同步只更新 manager-api 字段'
  rm -rf "$tmp_dir"
  trap - EXIT HUP INT TERM
}

test_invalid_config_is_preserved() {
  tmp_dir=$(mktemp -d)
  config="$tmp_dir/.config.yaml"
  printf 'server:\n  port: 8000\n' >"$config"
  before=$(cat "$config")
  if update_manager_config "$config" 'http://manager:8002/xiaozhi' 'secret'; then
    fail '缺少 manager-api 节点时应拒绝更新'
  fi
  [ "$(cat "$config")" = "$before" ] || fail '失败时不得改写原配置'
  pass '不安全的配置结构保持原样'
  rm -rf "$tmp_dir"
}

test_dispatch() {
  ACTION=''
  start_services() { ACTION=start; }
  stop_services() { ACTION=stop; }
  restart_services() { ACTION=restart; }
  show_status() { ACTION=status; }
  follow_logs() { ACTION=logs; }

  dispatch ''
  [ "$ACTION" = start ] || fail '空命令应执行 start'
  dispatch status
  [ "$ACTION" = status ] || fail 'status 应显示状态'
  if (dispatch invalid >/dev/null 2>&1); then
    fail '非法命令应失败'
  fi
  pass '命令分发行为正确'
}
```

并在测试入口依次调用三个新函数。

- [ ] **步骤 2：运行测试并确认正确失败**

运行：`sh scripts/tests/test-start-dev.sh`

预期：失败，提示 `start-dev.sh` 不存在或 `update_manager_config` 未定义。

- [ ] **步骤 3：实现最小启动脚本**

新建 `start-dev.sh`。实现以下函数，并保持每个函数只承担一个职责：

```sh
#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COMPOSE_FILE=${COMPOSE_FILE:-$ROOT_DIR/docker-compose.dev.yml}
DOCKER_BIN=${DOCKER_BIN:-docker}
MODEL_DIR=$ROOT_DIR/main/xiaozhi-server/models/SenseVoiceSmall
MODEL_FILE=$MODEL_DIR/model.pt
DATA_DIR=$ROOT_DIR/main/xiaozhi-server/data
CONFIG_FILE=$DATA_DIR/.config.yaml
CONFIG_TEMPLATE=$ROOT_DIR/main/xiaozhi-server/config_from_api.yaml
API_URL=http://xiaozhi-esp32-server-web:8002/xiaozhi

compose() {
  "$DOCKER_BIN" compose -f "$COMPOSE_FILE" "$@"
}

update_manager_config() {
  config_file=$1
  api_url=$2
  secret=$3
  tmp_file=$config_file.tmp.$$
  backup_file=$config_file.bak

  if ! awk -v api_url="$api_url" -v secret="$secret" '
    BEGIN { in_manager=0; manager=0; url=0; key=0 }
    /^manager-api:[[:space:]]*$/ { in_manager=1; manager=1; print; next }
    in_manager && /^[^[:space:]#][^:]*:/ { in_manager=0 }
    in_manager && /^  url:[[:space:]]*/ { print "  url: " api_url; url=1; next }
    in_manager && /^  secret:[[:space:]]*/ { print "  secret: " secret; key=1; next }
    { print }
    END { if (!manager || !url || !key) exit 42 }
  ' "$config_file" >"$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  cp "$config_file" "$backup_file"
  mv "$tmp_file" "$config_file"
}
```

同一文件继续实现：

- `check_docker`：用 `command -v` 和 `docker info` 检查唯一系统依赖。
- `prepare_directories`：创建 data、模型、上传目录。
- `download_model`：不存在时以 `model.pt.part` 下载，成功后原子重命名。
- `wait_for_manager`：最多等待 180 秒，在 manager 容器内用 `wget` 检查 `http://127.0.0.1:8002/`。
- `read_server_secret`：通过 `compose exec -T mysql mysql ...` 查询 `sys_params`。
- `prepare_config`：不存在时复制模板，再调用 `update_manager_config`。
- `wait_for_server`：最多等待 120 秒，在 server 容器内用 Python socket 检查 8000 和 8003。
- `start_services`：执行检查与准备，`compose up -d --build mysql redis manager`，同步配置，再 `compose up -d --build server`。
- `stop_services`：执行 `compose down --remove-orphans`，不传 `--volumes`。
- `restart_services`、`show_status`、`follow_logs` 和 `dispatch`。

入口必须是：

```sh
if [ "${DOCKER_DEV_SOURCE_ONLY:-0}" != 1 ]; then
  dispatch "${1:-start}"
fi
```

- [ ] **步骤 4：运行测试并确认通过**

运行：`sh scripts/tests/test-start-dev.sh`

预期：Compose、配置同步、失败保护和命令分发测试全部通过。

- [ ] **步骤 5：检查 Shell 语法与权限**

运行：

```bash
sh -n start-dev.sh
sh -n scripts/tests/test-start-dev.sh
chmod +x start-dev.sh scripts/tests/test-start-dev.sh
```

预期：两个语法检查均无输出并返回 0；两个文件均可执行。

- [ ] **步骤 6：提交启动器**

```bash
git add start-dev.sh scripts/tests/test-start-dev.sh
git commit -m "feat: 添加 Docker 开发一键启动器"
```

### 任务 3：使用说明与完整验证

**文件：**

- 修改：`README.md`
- 修改：`scripts/tests/test-start-dev.sh`

**接口：**

- README 明确唯一宿主机依赖、首次启动耗时、源码修改后的重建命令、访问地址和停止/日志命令。

- [ ] **步骤 1：写 README 内容失败测试**

在测试脚本追加：

```sh
test_readme_usage() {
  grep -q './start-dev.sh' "$ROOT_DIR/README.md" || fail 'README 应说明启动命令'
  grep -q 'http://localhost:8002' "$ROOT_DIR/README.md" || fail 'README 应说明控制台地址'
  grep -q './start-dev.sh logs' "$ROOT_DIR/README.md" || fail 'README 应说明日志命令'
  pass 'README 包含开发启动说明'
}
```

- [ ] **步骤 2：运行测试并确认正确失败**

运行：`sh scripts/tests/test-start-dev.sh`

预期：失败并提示 README 缺少 Docker 开发启动说明。

- [ ] **步骤 3：补充 README**

在 README 的部署章节增加“Docker 全源码开发”小节，写明：

```markdown
### Docker 全源码开发

宿主机只需安装并启动 Docker Desktop，无需安装 Java、Maven、Node.js、Python 或 FFmpeg。

```bash
./start-dev.sh
```

首次运行会构建当前工作区的前端、Java 后端和 Python 服务镜像，并下载缺失的语音识别模型。修改任一端源码后再次运行同一命令即可利用 Docker 缓存重建。

- 控制台：`http://localhost:8002`
- WebSocket：`ws://localhost:8000/xiaozhi/v1/`
- HTTP/Vision：`http://localhost:8003`
- 查看日志：`./start-dev.sh logs`
- 查看状态：`./start-dev.sh status`
- 停止服务：`./start-dev.sh stop`
```

- [ ] **步骤 4：运行静态完整验证**

运行：

```bash
sh scripts/tests/test-start-dev.sh
sh -n start-dev.sh
docker compose -f docker-compose.dev.yml config --quiet
git diff --check
```

预期：测试全部通过；其余命令无输出并返回 0。

- [ ] **步骤 5：执行真实 Docker 启动验证**

运行：

```bash
./start-dev.sh start
./start-dev.sh status
```

预期：四个服务均为运行状态；脚本打印控制台、WebSocket 和 HTTP 地址。随后运行：

```bash
curl -fsS http://localhost:8002/ >/dev/null
curl -fsS http://localhost:8003/ >/dev/null
```

预期：两个请求成功。若外部镜像仓库或模型下载网络不可用，保留原始错误并在交付中明确说明，不能宣称真实启动验证通过。

- [ ] **步骤 6：停止验证环境并确认数据未删除**

运行：

```bash
./start-dev.sh stop
test -d main/xiaozhi-server/mysql/data
test -f main/xiaozhi-server/models/SenseVoiceSmall/model.pt
```

预期：容器停止；MySQL 数据目录和模型文件仍存在。

- [ ] **步骤 7：提交文档与最终测试**

```bash
git add README.md scripts/tests/test-start-dev.sh
git commit -m "docs: 说明 Docker 全源码开发启动方式"
```
