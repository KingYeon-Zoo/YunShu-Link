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
