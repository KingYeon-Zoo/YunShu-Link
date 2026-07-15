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

test_dockerignore_runtime_data() {
  dockerignore=$ROOT_DIR/.dockerignore
  grep -Fxq 'main/xiaozhi-server/data' "$dockerignore" || fail '.dockerignore 应排除运行配置'
  grep -Fxq 'main/xiaozhi-server/models/SenseVoiceSmall/model.pt' "$dockerignore" || fail '.dockerignore 应排除大模型'
  grep -Fxq 'main/xiaozhi-server/mysql' "$dockerignore" || fail '.dockerignore 应排除 MySQL 数据'
  grep -Fxq 'main/xiaozhi-server/uploadfile' "$dockerignore" || fail '.dockerignore 应排除上传文件'
  grep -Fxq 'main/manager-web/node_modules' "$dockerignore" || fail '.dockerignore 应排除前端依赖目录'
  pass 'Docker 构建上下文排除运行时和私有数据'
}

test_config_update() {
  tmp_dir=$(mktemp -d)
  config=$tmp_dir/.config.yaml
  expected_root=$ROOT_DIR
  printf '%s\n' \
    'server:' \
    '  port: 8000' \
    'manager-api:' \
    '  url: http://old.example/xiaozhi' \
    '  secret: old-secret' \
    'prompt_template: agent-base-prompt.txt' >"$config"

  DOCKER_DEV_SOURCE_ONLY=1 . "$ROOT_DIR/start-dev.sh"
  [ "$ROOT_DIR" = "$expected_root" ] || fail '加载启动器时不应覆盖调用者提供的 ROOT_DIR'
  update_manager_config "$config" 'http://xiaozhi-esp32-server-web:8002/xiaozhi' 'new-secret'

  grep -q '^  url: http://xiaozhi-esp32-server-web:8002/xiaozhi$' "$config" || fail '应更新 manager-api.url'
  grep -q '^  secret: new-secret$' "$config" || fail '应更新 manager-api.secret'
  grep -q '^  port: 8000$' "$config" || fail '应保留其他配置'
  pass '配置同步只更新 manager-api 字段'
  rm -rf "$tmp_dir"
}

test_invalid_config_is_preserved() {
  tmp_dir=$(mktemp -d)
  config=$tmp_dir/.config.yaml
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

test_server_start_keeps_manager_running() {
  grep -q 'compose up -d --build --no-deps server' "$ROOT_DIR/start-dev.sh" || \
    fail '启动 server 时不应重建已就绪的 manager 依赖'
  pass '启动 Python 服务不会重启 manager'
}

test_readme_usage() {
  grep -q './start-dev.sh' "$ROOT_DIR/README.md" || fail 'README 应说明启动命令'
  grep -q 'http://localhost:8002' "$ROOT_DIR/README.md" || fail 'README 应说明控制台地址'
  grep -q './start-dev.sh logs' "$ROOT_DIR/README.md" || fail 'README 应说明日志命令'
  pass 'README 包含开发启动说明'
}

test_compose_config
test_dockerignore_runtime_data
test_config_update
test_invalid_config_is_preserved
test_dispatch
test_server_start_keeps_manager_running
test_readme_usage
printf '共通过 %s 项测试。\n' "$TEST_COUNT"
