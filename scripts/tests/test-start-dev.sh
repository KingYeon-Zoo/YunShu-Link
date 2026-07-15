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

test_config_update() {
  tmp_dir=$(mktemp -d)
  config=$tmp_dir/.config.yaml
  printf '%s\n' \
    'server:' \
    '  port: 8000' \
    'manager-api:' \
    '  url: http://old.example/xiaozhi' \
    '  secret: old-secret' \
    'prompt_template: agent-base-prompt.txt' >"$config"

  DOCKER_DEV_SOURCE_ONLY=1 . "$ROOT_DIR/start-dev.sh"
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

test_compose_config
test_config_update
test_invalid_config_is_preserved
test_dispatch
printf '共通过 %s 项测试。\n' "$TEST_COUNT"
