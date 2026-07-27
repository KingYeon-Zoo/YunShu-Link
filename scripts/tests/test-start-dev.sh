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

# --init-db 曾被误当成菜单选项 2 的等价物，结果建出没有账号和模型的空库。
test_demo_mode_is_distinct_from_init() {
  local usage
  usage="$(DEV_START_SOURCE_ONLY=0 "$ROOT_DIR/start-dev.sh" help)"
  grep -q -- '--demo' <<<"$usage" || fail '帮助应提供写入演示基线的 --demo'
  grep -q -- '--demo.*菜单选项 2' <<<"$usage" || fail '帮助应说明 --demo 等价于菜单选项 2'
  grep -qE -- '--init-db.*(不写演示数据|空表)' <<<"$usage" \
    || fail '帮助应说明 --init-db 不写入演示数据'

  grep -q 'demo) mode="demo"' "$ROOT_DIR/start-dev.sh" || fail 'start 应接受 --demo 参数'
  grep -q 'keep|init|demo)' "$ROOT_DIR/start-dev.sh" || fail 'choose_database_mode 应接受 demo'

  # 菜单和 --demo 必须共用同一个实现，否则两条路径又会各自漂移。
  local baseline_calls
  baseline_calls="$(grep -c 'write_demo_baseline || return 1' "$ROOT_DIR/start-dev.sh")"
  [[ "$baseline_calls" -ge 2 ]] \
    || fail '菜单选项 2 与 --demo 应共用 write_demo_baseline'
  grep -q 'reset-demo-db.sh" --yes' "$ROOT_DIR/start-dev.sh" \
    && fail '菜单不应再直接调用 reset-demo-db.sh，应统一走 write_demo_baseline'

  pass '--demo 写入演示基线，--init-db 只建空表且已明确告警'
}

test_baseline_verification_distinguishes_failures() {
  # 连不上数据库可以宽容跳过，但连上却读不到基线正是要拦的故障，必须失败。
  local output status
  set +e
  output="$(DEMO_COMPOSE_PROJECT=definitely-no-such-project verify_demo_baseline 2>&1)"
  status=$?
  set -e
  [[ "$status" -eq 0 ]] || fail '数据库连不上时应跳过校验而非报错'
  grep -q '无法连接数据库' <<<"$output" || fail '数据库连不上时应给出提示'

  grep -q '读不到演示基线表' "$ROOT_DIR/start-dev.sh" \
    || fail '连上数据库但缺基线表时应报错而非静默跳过'
  grep -q '没有登录账号' "$ROOT_DIR/start-dev.sh" \
    || fail '校验应明确指出缺少登录账号的后果'
  pass '演示基线校验区分"连不上"与"连上但没基线"'
}

# 这三个参数重置后是 null，manager-api 会自动探测并可能下发旧网络的残留 IP。
test_lan_access_params_are_applied() {
  grep -q 'apply_lan_access_params' "$ROOT_DIR/start-dev.sh" \
    || fail '演示初始化后应写入设备接入地址'
  grep -q "param_code='server.websocket'" "$ROOT_DIR/start-dev.sh" \
    || fail '应写入 server.websocket'
  grep -q "param_code='server.ota'" "$ROOT_DIR/start-dev.sh" \
    || fail '应写入 server.ota'
  grep -q 'redis-cli FLUSHALL' "$ROOT_DIR/start-dev.sh" \
    || fail '写完参数应清 Redis 缓存才能生效'

  # 代理软件的虚拟网卡地址设备连不上，探测到也不能用。
  grep -q '198.18' "$ROOT_DIR/start-dev.sh" \
    || fail 'detect_lan_ip 应排除虚拟网卡网段'

  local ip
  ip="$(detect_lan_ip)"
  if [[ -n "$ip" ]]; then
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "detect_lan_ip 应返回合法 IPv4，实际：$ip"
    [[ "$ip" != 198.18.* ]] || fail 'detect_lan_ip 不应返回虚拟网卡地址'
  fi
  pass '演示初始化会写入设备接入地址并清理缓存'
}

test_shell_syntax
test_compose_config
test_config_update
test_invalid_config_is_preserved
test_database_backup
test_start_does_not_force_restart_database
test_usage_and_docs
test_demo_mode_is_distinct_from_init
test_baseline_verification_distinguishes_failures
test_lan_access_params_are_applied
printf '共通过 %s 项测试。\n' "$TEST_COUNT"
