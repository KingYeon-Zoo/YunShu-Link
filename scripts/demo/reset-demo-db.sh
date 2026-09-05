#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SEED_SQL="$ROOT_DIR/scripts/demo/seed-demo.sql"
# 演示展示数据：多厂商模型目录、五个智能体与设备/聊天记录、知识库语料影子表。
# 知识库那份由 scripts/demo/fetch-demo-corpus.py 从开源语料生成，已提交进仓库，
# 因此重置流程本身不需要联网。
SHOWCASE_SQL_FILES=(
  "$ROOT_DIR/scripts/demo/seed-demo-models.sql"
  "$ROOT_DIR/scripts/demo/seed-demo-showcase.sql"
  "$ROOT_DIR/scripts/demo/seed-demo-knowledge.sql"
)
BASELINE_VERIFY_SQL="$ROOT_DIR/scripts/demo/verify-current-baseline.sql"
BACKUP_DIR="$ROOT_DIR/.demo-db-backups"
SERVER_CONFIG="$ROOT_DIR/main/xiaozhi-server/data/.config.yaml"
SERVER_CONFIG_TEMPLATE="$ROOT_DIR/main/xiaozhi-server/config_from_api.yaml"
HOST_SERVER_PID_FILE="$ROOT_DIR/.dev/pids/xiaozhi-server.pid"

ASSUME_YES=0
CHECK_ONLY=0
ENV_FILE=""
STOPPED_CONTAINERS=()
HOST_SERVER_WAS_RUNNING=0

info() {
  printf '\033[1;34m[信息]\033[0m %s\n' "$*"
}

success() {
  printf '\033[1;32m[完成]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[注意]\033[0m %s\n' "$*" >&2
}

error() {
  printf '\033[1;31m[错误]\033[0m %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
用法：
  ./scripts/demo/reset-demo-db.sh [--yes] [--check] [--env-file PATH]

选项：
  --yes            跳过破坏性操作确认
  --check          只检查环境、凭据和容器，不修改数据库
  --env-file PATH  指定 dotenv 文件；默认读取项目根目录 .env，
                   并从同级 EduLoom/.env 补齐缺失的豆包变量
EOF
}

while (($# > 0)); do
  case "$1" in
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --check)
      CHECK_ONLY=1
      shift
      ;;
    --env-file)
      if (($# < 2)); then
        error "--env-file 缺少路径"
        exit 2
      fi
      ENV_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "未知参数：$1"
      usage
      exit 2
      ;;
  esac
done

set_if_empty() {
  local key="$1"
  local value="$2"
  if [[ -z "${!key:-}" ]]; then
    export "$key=$value"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_env_value() {
  local value
  value="$(trim "$1")"
  if [[ ${#value} -ge 2 ]]; then
    if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi
  printf '%s' "$value"
}

load_env_file() {
  local file="$1"
  local line key value
  [[ -f "$file" ]] || return 0
  info "读取环境变量：$file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == export\ * ]]; then
      line="$(trim "${line#export }")"
    fi
    if [[ "$line" =~ ^X-Api-Key[[:space:]]*= ]]; then
      value="${line#*=}"
      value="$(normalize_env_value "$value")"
      # 豆包 ASR 与 Seed-TTS 共用同一个火山引擎 X-Api-Key，两者必须一起推导：
      # 只给 ASR 会让 TTS 回退到其它 .env（如同目录的兄弟项目）里不相干的密钥。
      set_if_empty "DOUBAO_ASR_API_KEY" "$value"
      set_if_empty "DOUBAO_TTS_API_KEY" "$value"
    elif [[ "$line" =~ ^X-Api-Resource-Id[[:space:]]*= ]]; then
      value="${line#*=}"
      value="$(normalize_env_value "$value")"
      set_if_empty "DOUBAO_ASR_RESOURCE_ID" "$value"
    elif [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*= ]]; then
      key="${line%%=*}"
      key="$(trim "$key")"
      value="${line#*=}"
      value="$(normalize_env_value "$value")"
      set_if_empty "$key" "$value"
    elif [[ "$line" == ark-* && -z "${ARK_API_KEY:-}" ]]; then
      set_if_empty "ARK_API_KEY" "$line"
      warn "$file 使用了旧的单行 Key 格式，已兼容；建议改成 ARK_API_KEY=..."
    else
      warn "$file 中有一行不是标准 KEY=VALUE 格式，已忽略且未回显内容"
    fi
  done < "$file"
}

if [[ -n "$ENV_FILE" ]]; then
  load_env_file "$ENV_FILE"
else
  load_env_file "$ROOT_DIR/.env"
  # 兄弟项目仅作缺失变量的兜底来源，其中的豆包密钥属于另一个账号，可能与本项目不同步。
  if [[ -f "$ROOT_DIR/../EduLoom/.env" ]]; then
    warn "将从同级 EduLoom/.env 兜底补齐缺失变量；如遇模型鉴权失败，请优先在本仓库 .env 中显式配置。"
    load_env_file "$ROOT_DIR/../EduLoom/.env"
  fi
fi

set_if_empty "ARK_BASE_URL" "https://ark.cn-beijing.volces.com/api/v3"
set_if_empty "DOUBAO_CHARACTER_MODEL" "doubao-seed-character-260628"
set_if_empty "DOUBAO_SLM_MODEL" "doubao-seed-2-0-lite-260428"
set_if_empty "DOUBAO_ASR_RESOURCE_ID" "volc.seedasr.sauc.duration"
set_if_empty "DOUBAO_TTS_ENDPOINT" "https://openspeech.bytedance.com/api/v3/tts/unidirectional"
set_if_empty "DOUBAO_TTS_RESOURCE_ID" "seed-tts-2.0"
set_if_empty "DOUBAO_TTS_SPEAKER" "zh_female_yingyujiaoxue_uranus_bigtts"
set_if_empty "DOUBAO_TTS_API_KEY" ""
set_if_empty "DOUBAO_TTS_APP_ID" ""
set_if_empty "DOUBAO_TTS_ACCESS_TOKEN" ""
set_if_empty "DEMO_USERNAME" "demo"
set_if_empty "DEMO_PASSWORD" "Demo@123456"
set_if_empty "DEMO_DB_NAME" "xiaozhi_esp32_server"
set_if_empty "DEMO_DB_USER" "root"
set_if_empty "DEMO_DB_PASSWORD" "123456"
set_if_empty "DEMO_COMPOSE_PROJECT" "yunshu-link-dev"

if [[ ! "$DEMO_DB_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
  error "DEMO_DB_NAME 只能包含字母、数字和下划线"
  exit 2
fi

missing=()
[[ -n "${ARK_API_KEY:-}" ]] || missing+=("ARK_API_KEY")
[[ -n "${DOUBAO_ASR_API_KEY:-}" ]] || missing+=("DOUBAO_ASR_API_KEY（也兼容 .env 中的 X-Api-Key）")
[[ -n "${DOUBAO_ASR_RESOURCE_ID:-}" ]] || missing+=("DOUBAO_ASR_RESOURCE_ID（也兼容 .env 中的 X-Api-Resource-Id）")
if [[ -z "$DOUBAO_TTS_API_KEY" && ( -z "$DOUBAO_TTS_APP_ID" || -z "$DOUBAO_TTS_ACCESS_TOKEN" ) ]]; then
  missing+=("DOUBAO_TTS_API_KEY（或 DOUBAO_TTS_APP_ID + DOUBAO_TTS_ACCESS_TOKEN）")
fi

# 两者同属一个火山引擎账号，取值不同通常意味着某一份来自别处且已失效（TTS 会 401）。
if [[ -n "$DOUBAO_TTS_API_KEY" && -n "${DOUBAO_ASR_API_KEY:-}" \
      && "$DOUBAO_TTS_API_KEY" != "$DOUBAO_ASR_API_KEY" ]]; then
  warn "DOUBAO_TTS_API_KEY 与 DOUBAO_ASR_API_KEY 不一致；二者应共用同一个 X-Api-Key。"
  warn "若 TTS 合成返回 401，请删除多余的 DOUBAO_TTS_API_KEY，改由 .env 的 X-Api-Key 统一推导。"
fi

if ((${#missing[@]} > 0)); then
  error "缺少以下演示凭据："
  for key in "${missing[@]}"; do
    printf '  - %s\n' "$key" >&2
  done
  error "请参考 .env.demo.example 补齐；脚本不会写入半配置状态。"
  exit 1
fi

for command_name in docker curl gzip htpasswd; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    error "缺少命令：$command_name"
    exit 1
  fi
done

find_container() {
  local service_regex="$1"
  local container
  while IFS= read -r container; do
    [[ -n "$container" ]] || continue
    local service
    service="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}}' "$container" 2>/dev/null || true)"
    if [[ "$service" =~ $service_regex ]]; then
      printf '%s' "$container"
      return 0
    fi
  done < <(docker ps -a \
    --filter "label=com.docker.compose.project=$DEMO_COMPOSE_PROJECT" \
    --format '{{.ID}}')
  return 1
}

host_server_pid() {
  [[ -f "$HOST_SERVER_PID_FILE" ]] || return 1
  local pid command_line
  pid="$(<"$HOST_SERVER_PID_FILE")"
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null || return 1
  command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  [[ "$command_line" == *"app.py"* ]] || return 1
  printf '%s' "$pid"
}

terminate_process_tree() {
  local pid="$1"
  if command -v pgrep >/dev/null 2>&1; then
    local child
    while IFS= read -r child; do
      [[ -n "$child" ]] && terminate_process_tree "$child"
    done < <(pgrep -P "$pid" 2>/dev/null || true)
  fi
  kill -TERM "$pid" 2>/dev/null || true
}

stop_host_server() {
  local pid
  pid="$(host_server_pid)" || return 1
  terminate_process_tree "$pid"
  for _ in {1..20}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
  done
  kill -KILL "$pid" 2>/dev/null || true
  unlink "$HOST_SERVER_PID_FILE" 2>/dev/null || true
}

sync_server_secret() {
  local secret="$1"
  local config_file="$SERVER_CONFIG"
  local tmp_file

  if [[ ! -f "$config_file" ]]; then
    cp "$SERVER_CONFIG_TEMPLATE" "$config_file"
  fi
  tmp_file="$(mktemp "$config_file.tmp.XXXXXX")"
  if ! YUNSHU_MANAGER_SECRET="$secret" awk '
    BEGIN { in_manager=0; manager=0; key=0 }
    /^manager-api:[[:space:]]*$/ { in_manager=1; manager=1; print; next }
    in_manager && /^[^[:space:]#][^:]*:/ { in_manager=0 }
    in_manager && /^  secret:[[:space:]]*/ {
      print "  secret: " ENVIRON["YUNSHU_MANAGER_SECRET"]
      key=1
      next
    }
    { print }
    END { if (!manager || !key) exit 42 }
  ' "$config_file" >"$tmp_file"; then
    unlink "$tmp_file" 2>/dev/null || true
    error "无法更新 data/.config.yaml 中的 manager-api.secret"
    return 1
  fi
  mv "$tmp_file" "$config_file"
}

validate_server_config() {
  local config_file="$SERVER_CONFIG"
  [[ -f "$config_file" ]] || config_file="$SERVER_CONFIG_TEMPLATE"
  awk '
    BEGIN { in_manager=0; manager=0; key=0 }
    /^manager-api:[[:space:]]*$/ { in_manager=1; manager=1; next }
    in_manager && /^[^[:space:]#][^:]*:/ { in_manager=0 }
    in_manager && /^  secret:[[:space:]]*/ { key=1 }
    END { exit !manager || !key }
  ' "$config_file"
}

MYSQL_CONTAINER="$(find_container '^mysql$' || true)"
MANAGER_CONTAINER="$(find_container '^(manager|manager-api)$' || true)"
SERVER_CONTAINER="$(find_container '^(server|xiaozhi-server)$' || true)"
REDIS_CONTAINER="$(find_container '^redis$' || true)"

[[ -n "$MYSQL_CONTAINER" ]] || { error "未找到 $DEMO_COMPOSE_PROJECT 项目的 MySQL 容器"; exit 1; }
[[ -n "$MANAGER_CONTAINER" ]] || { error "未找到 manager-api 容器"; exit 1; }
if ! validate_server_config; then
  error "data/.config.yaml 不是 manager-api 模式配置，无法安全同步新的 server.secret"
  exit 1
fi
if [[ -n "$SERVER_CONTAINER" ]] \
  && ! docker exec "$SERVER_CONTAINER" sh -lc \
    'test -f core/providers/tts/doubao_v3.py' >/dev/null 2>&1; then
  error "当前 xiaozhi-server 容器还是旧代码，不包含豆包 TTS 2.0 Provider"
  error "请先运行 ./start-dev.sh start --keep-db（或重建服务镜像），再执行重置"
  exit 1
fi

if [[ "$(docker inspect -f '{{.State.Running}}' "$MYSQL_CONTAINER")" != "true" ]]; then
  docker start "$MYSQL_CONTAINER" >/dev/null
fi

mysql_exec() {
  docker exec -e "MYSQL_PWD=$DEMO_DB_PASSWORD" -i "$MYSQL_CONTAINER" \
    mysql --default-character-set=utf8mb4 -u"$DEMO_DB_USER" "$@"
}

if ! mysql_exec -N -s -e "SELECT 1" >/dev/null 2>&1; then
  error "无法连接 MySQL，请检查 DEMO_DB_USER / DEMO_DB_PASSWORD"
  exit 1
fi

for seed_file in "$SEED_SQL" "${SHOWCASE_SQL_FILES[@]}" "$BASELINE_VERIFY_SQL"; do
  if [[ ! -f "$seed_file" ]]; then
    error "缺少初始化脚本：$seed_file"
    if [[ "$seed_file" == *seed-demo-knowledge.sql ]]; then
      error "该文件由 scripts/demo/fetch-demo-corpus.py 生成，请先运行一次（需联网）。"
    fi
    exit 1
  fi
done

success "凭据格式、Docker 容器和数据库连接检查通过。"
if ((CHECK_ONLY == 1)); then
  exit 0
fi

if ((ASSUME_YES == 0)); then
  if [[ ! -t 0 ]]; then
    error "非交互环境必须显式传入 --yes"
    exit 2
  fi
  printf '即将备份并重建数据库 %s，现有业务数据会被清空。输入 RESET 确认：' "$DEMO_DB_NAME"
  read -r confirmation
  if [[ "$confirmation" != "RESET" ]]; then
    warn "已取消，数据库未修改。"
    exit 0
  fi
fi

mkdir -p "$BACKUP_DIR"
backup_file="$BACKUP_DIR/${DEMO_DB_NAME}-$(date '+%Y%m%d-%H%M%S').sql.gz"
info "备份当前数据库到 $backup_file"
docker exec -e "MYSQL_PWD=$DEMO_DB_PASSWORD" "$MYSQL_CONTAINER" \
  mysqldump --single-transaction --routines --triggers --set-gtid-purged=OFF \
  -u"$DEMO_DB_USER" "$DEMO_DB_NAME" | gzip -9 > "$backup_file"
success "数据库备份完成。"

for container in "$MANAGER_CONTAINER" "$SERVER_CONTAINER"; do
  [[ -n "$container" ]] || continue
  if [[ "$(docker inspect -f '{{.State.Running}}' "$container")" == "true" ]]; then
    docker stop "$container" >/dev/null
    STOPPED_CONTAINERS+=("$container")
  fi
done
if stop_host_server; then
  HOST_SERVER_WAS_RUNNING=1
fi

restart_stopped_on_error() {
  local exit_code=$?
  if ((exit_code != 0 && ${#STOPPED_CONTAINERS[@]} > 0)); then
    warn "重置未完成，正在恢复已停止的应用容器；备份保留在 $backup_file"
    docker start "${STOPPED_CONTAINERS[@]}" >/dev/null 2>&1 || true
  fi
  if ((exit_code != 0 && HOST_SERVER_WAS_RUNNING == 1)); then
    warn "正在恢复本地 xiaozhi-server"
    "$ROOT_DIR/start-dev.sh" restart-python >/dev/null 2>&1 || true
  fi
  exit "$exit_code"
}
trap restart_stopped_on_error EXIT

info "重建空数据库并运行 Liquibase 迁移……"
mysql_exec -e "DROP DATABASE IF EXISTS \`$DEMO_DB_NAME\`; CREATE DATABASE \`$DEMO_DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
docker start "$MANAGER_CONTAINER" >/dev/null

manager_ready=0
for _ in {1..120}; do
  if curl -fsS --max-time 2 "http://127.0.0.1:8002/xiaozhi/doc.html" >/dev/null 2>&1; then
    manager_ready=1
    break
  fi
  sleep 2
done
if ((manager_ready == 0)); then
  error "manager-api 在 240 秒内未完成数据库迁移"
  docker logs --tail=120 "$MANAGER_CONTAINER" >&2 || true
  exit 1
fi
server_secret="$(mysql_exec -N -s "$DEMO_DB_NAME" \
  -e "SELECT param_value FROM sys_params WHERE param_code='server.secret' LIMIT 1;" \
  | tr -d '\r\n')"
if [[ -z "$server_secret" || "$server_secret" == "null" ]]; then
  error "manager-api 未生成新的 server.secret"
  exit 1
fi
sync_server_secret "$server_secret"
docker stop "$MANAGER_CONTAINER" >/dev/null
if [[ ! " ${STOPPED_CONTAINERS[*]} " =~ " $MANAGER_CONTAINER " ]]; then
  STOPPED_CONTAINERS+=("$MANAGER_CONTAINER")
fi

password_hash="$(htpasswd -bnBC 10 '' "$DEMO_PASSWORD" | tr -d ':\n')"
password_hash="${password_hash/\$2y\$/\$2a\$}"

reject_control_chars() {
  local key="$1"
  local value="${!key}"
  # Bash 变量本身无法保存 NUL，只需拦截会破坏逐行 SQL 注入的换行符。
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    error "$key 含不支持的控制字符"
    exit 1
  fi
}

sql_literal() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

for key in ARK_API_KEY ARK_BASE_URL DOUBAO_CHARACTER_MODEL DOUBAO_SLM_MODEL \
  DOUBAO_ASR_API_KEY DOUBAO_ASR_RESOURCE_ID \
  DOUBAO_TTS_API_KEY DOUBAO_TTS_APP_ID DOUBAO_TTS_ACCESS_TOKEN \
  DOUBAO_TTS_ENDPOINT DOUBAO_TTS_RESOURCE_ID DOUBAO_TTS_SPEAKER \
  DEMO_USERNAME DEMO_PASSWORD; do
  reject_control_chars "$key"
done

info "写入当前已确认的演示数据库基线（2026-07-27）……"
{
  printf "SET SESSION sql_mode = CONCAT_WS(',', @@sql_mode, 'NO_BACKSLASH_ESCAPES');\n"
  printf "SET @demo_user_id = 900000000000000001;\n"
  printf "SET @demo_username = %s;\n" "$(sql_literal "$DEMO_USERNAME")"
  printf "SET @demo_password_hash = %s;\n" "$(sql_literal "$password_hash")"
  printf "SET @ark_api_key = %s;\n" "$(sql_literal "$ARK_API_KEY")"
  printf "SET @ark_base_url = %s;\n" "$(sql_literal "$ARK_BASE_URL")"
  printf "SET @doubao_character_model = %s;\n" "$(sql_literal "$DOUBAO_CHARACTER_MODEL")"
  printf "SET @doubao_slm_model = %s;\n" "$(sql_literal "$DOUBAO_SLM_MODEL")"
  printf "SET @doubao_asr_api_key = %s;\n" "$(sql_literal "$DOUBAO_ASR_API_KEY")"
  printf "SET @doubao_asr_resource_id = %s;\n" "$(sql_literal "$DOUBAO_ASR_RESOURCE_ID")"
  printf "SET @doubao_tts_api_key = %s;\n" "$(sql_literal "$DOUBAO_TTS_API_KEY")"
  printf "SET @doubao_tts_app_id = %s;\n" "$(sql_literal "$DOUBAO_TTS_APP_ID")"
  printf "SET @doubao_tts_access_token = %s;\n" "$(sql_literal "$DOUBAO_TTS_ACCESS_TOKEN")"
  printf "SET @doubao_tts_endpoint = %s;\n" "$(sql_literal "$DOUBAO_TTS_ENDPOINT")"
  printf "SET @doubao_tts_resource_id = %s;\n" "$(sql_literal "$DOUBAO_TTS_RESOURCE_ID")"
  printf "SET @doubao_tts_speaker = %s;\n" "$(sql_literal "$DOUBAO_TTS_SPEAKER")"
  # 基线在同一会话里先跑（内含 START TRANSACTION/COMMIT），随后追加演示展示数据。
  # 顺序不能改：展示数据引用基线建立的用户、模型与角色模板。
  for seed_file in "$SEED_SQL" "${SHOWCASE_SQL_FILES[@]}"; do
    printf -- "-- >>> %s\n" "$(basename "$seed_file")"
    cat "$seed_file"
    printf "\n"
  done
} | mysql_exec "$DEMO_DB_NAME"

baseline_status="$(
  mysql_exec -N -s "$DEMO_DB_NAME" <"$BASELINE_VERIFY_SQL" | tr -d '\r\n'
)"
if [[ "$baseline_status" != "CURRENT_DEMO_BASELINE_OK" ]]; then
  error "初始化结果与当前演示基线不一致，已停止启动，避免使用旧版或半配置数据库。"
  exit 1
fi
success "当前演示数据库基线校验通过。"

if [[ -n "$REDIS_CONTAINER" ]]; then
  docker exec "$REDIS_CONTAINER" redis-cli FLUSHDB >/dev/null
fi

docker restart "$MANAGER_CONTAINER" >/dev/null
if [[ -n "$SERVER_CONTAINER" ]]; then
  docker start "$SERVER_CONTAINER" >/dev/null
  docker restart "$SERVER_CONTAINER" >/dev/null
fi
if ((HOST_SERVER_WAS_RUNNING == 1)); then
  "$ROOT_DIR/start-dev.sh" restart-python
fi

STOPPED_CONTAINERS=()
trap - EXIT

success "演示数据库初始化完成。"
printf '  基线版本：2026-07-27（当前确认版）\n'
printf '  账号：%s\n' "$DEMO_USERNAME"
if [[ "$DEMO_PASSWORD" == "Demo@123456" ]]; then
  printf '  默认密码：Demo@123456（可在 .env 中通过 DEMO_PASSWORD 修改）\n'
else
  printf '  密码：使用 .env 中的 DEMO_PASSWORD（不会回显）\n'
fi
printf '  主模型：%s\n' "$DOUBAO_CHARACTER_MODEL"
printf '  小参数模型：%s\n' "$DOUBAO_SLM_MODEL"
printf '  备份：%s\n' "$backup_file"
