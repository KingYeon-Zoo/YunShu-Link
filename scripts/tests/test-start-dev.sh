#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_COUNT=0

pass() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf '通过：%s\n' "$1"
}

fail() {
  printf '失败：%s\n' "$1" >&2
  exit 1
}

DEV_START_SOURCE_ONLY=1 source "$ROOT_DIR/start-dev.sh"

test_shell_syntax() {
  bash -n "$ROOT_DIR/start-dev.sh" || fail '启动脚本应通过 Bash 语法检查'
  pass '启动脚本 Bash 语法正确'
}

test_compose_config() {
  local output
  output="$(docker compose -f "$ROOT_DIR/docker-compose.dev.yml" config 2>&1)" || {
    printf '%s\n' "$output" >&2
    fail '开发 Compose 配置应可渲染'
  }

  grep -q 'image: mysql:latest' <<<"$output" || fail 'MySQL 应在 Docker 中'
  grep -q 'image: redis:8.0' <<<"$output" || fail 'Redis 应在 Docker 中'
  grep -q 'image: maven:3.9.9-eclipse-temurin-21' <<<"$output" || fail 'manager-api 应使用隔离的 Java 21/Maven 容器'
  grep -q 'source: .*main/manager-api' <<<"$output" || fail 'manager-api 应挂载本地 Java 源码'
  if grep -qE 'server:|web-dev:' <<<"$output"; then
    fail '频繁修改的 Python 和前端不应在开发 Compose 中运行'
  fi
  pass 'Compose 仅承载基础设施和 Java API'
}

test_config_update() {
  local tmp_dir config
  tmp_dir="$(mktemp -d)"
  config="$tmp_dir/.config.yaml"
  printf '%s\n' \
    'server:' \
    '  port: 8000' \
    'manager-api:' \
    '  url: http://old.example/xiaozhi' \
    '  secret: old-secret' \
    'prompt_template: agent-base-prompt.txt' >"$config"

  update_manager_config "$config" 'http://127.0.0.1:8002/xiaozhi' 'new-secret'
  grep -q '^  url: http://127.0.0.1:8002/xiaozhi$' "$config" || fail '应更新本地 manager-api.url'
  grep -q '^  secret: new-secret$' "$config" || fail '应更新 manager-api.secret'
  grep -q '^  port: 8000$' "$config" || fail '应保留其他配置'
  [[ -f "$config.bak" ]] || fail '更新配置前应创建备份'
  rm -rf "$tmp_dir"
  pass 'Python API 模式配置可安全同步'
}

test_invalid_config_is_preserved() {
  local tmp_dir config before
  tmp_dir="$(mktemp -d)"
  config="$tmp_dir/.config.yaml"
  printf 'server:\n  port: 8000\n' >"$config"
  before="$(<"$config")"

  if update_manager_config "$config" 'http://127.0.0.1:8002/xiaozhi' 'secret'; then
    fail '缺少 manager-api 节点时应拒绝更新'
  fi
  [[ "$(<"$config")" == "$before" ]] || fail '配置更新失败时不得改写原文件'
  rm -rf "$tmp_dir"
  pass '不安全的配置结构保持原样'
}

test_database_backup() {
  local tmp_dir old_mysql_root old_mysql_data old_mysql_backups old_compose_definition
  tmp_dir="$(mktemp -d)"
  old_mysql_root="$MYSQL_ROOT"
  old_mysql_data="$MYSQL_DATA"
  old_mysql_backups="$MYSQL_BACKUPS"
  MYSQL_ROOT="$tmp_dir/mysql"
  MYSQL_DATA="$MYSQL_ROOT/data"
  MYSQL_BACKUPS="$MYSQL_ROOT/backups"
  mkdir -p "$MYSQL_DATA/mysql" "$MYSQL_BACKUPS"
  printf '保留我\n' >"$MYSQL_DATA/mysql/user-data"
  old_compose_definition="$(declare -f compose)"
  compose() { return 0; }

  initialize_database
  [[ -d "$MYSQL_DATA" ]] || fail '初始化后应创建空数据目录'
  [[ ! -e "$MYSQL_DATA/mysql/user-data" ]] || fail '旧数据不应留在新库目录'
  find "$MYSQL_BACKUPS" -name user-data -print -quit | grep -q . || fail '旧数据库应被备份而非删除'

  MYSQL_ROOT="$old_mysql_root"
  MYSQL_DATA="$old_mysql_data"
  MYSQL_BACKUPS="$old_mysql_backups"
  unset -f compose
  eval "$old_compose_definition"
  rm -rf "$tmp_dir"
  pass '重新初始化前会完整备份旧数据库'
}

test_start_does_not_force_restart_database() {
  grep -q 'compose up -d --remove-orphans mysql redis manager-api' "$ROOT_DIR/start-dev.sh" || \
    fail '启动应使用幂等的 compose up'
  if grep -q 'compose restart mysql' "$ROOT_DIR/start-dev.sh"; then
    fail '日常启动不得重启 MySQL'
  fi
  pass '日常启动不会强制重启数据库'
}

test_usage_and_docs() {
  local usage menu
  usage="$(DEV_START_SOURCE_ONLY=0 "$ROOT_DIR/start-dev.sh" help)"
  menu="$(menu_header)"
  grep -q '图形化启动器' <<<"$menu" || fail '启动器应显示中文图形化标题'
  grep -q '1. 一键启动开发环境' <<<"$menu" || fail '菜单应提供一键启动'
  grep -q '2. 一键准备演示环境' <<<"$menu" || fail '菜单应提供演示初始化'
  grep -q './start-dev.sh.*打开中文数字菜单' <<<"$usage" || fail '帮助应优先说明数字菜单'
  grep -q '输入 `1`' "$ROOT_DIR/README.md" || fail 'README 应说明数字菜单'
  grep -q 'mysql/backups' "$ROOT_DIR/README.md" || fail 'README 应说明数据库备份位置'
  pass '图形化菜单、帮助与 README 已覆盖开发工作流'
}

test_shell_syntax
test_compose_config
test_config_update
test_invalid_config_is_preserved
test_database_backup
test_start_does_not_force_restart_database
test_usage_and_docs
printf '共通过 %s 项测试。\n' "$TEST_COUNT"
