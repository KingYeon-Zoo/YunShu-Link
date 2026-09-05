#!/usr/bin/env bash

set -Eeuo pipefail

if [[ "${DEV_START_SOURCE_ONLY:-0}" != "1" || -z "${ROOT_DIR:-}" ]]; then
  ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi

COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/docker-compose.dev.yml}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
RUNTIME_DIR="$ROOT_DIR/.dev"
LOG_DIR="$RUNTIME_DIR/logs"
PID_DIR="$RUNTIME_DIR/pids"
PYTHON_DIR="$ROOT_DIR/main/xiaozhi-server"
PYTHON_ENV="$PYTHON_DIR/.venv"
PYTHON_REQUIREMENTS="$PYTHON_DIR/requirements.txt"
PYTHON_LOG="$LOG_DIR/xiaozhi-server.log"
PYTHON_PID="$PID_DIR/xiaozhi-server.pid"
MODEL_DIR="$PYTHON_DIR/models/SenseVoiceSmall"
MODEL_FILE="$MODEL_DIR/model.pt"
MODEL_URL="https://modelscope.cn/models/iic/SenseVoiceSmall/resolve/master/model.pt"
WEB_DIR="$ROOT_DIR/main/manager-web"
WEB_LOG="$LOG_DIR/manager-web.log"
WEB_PID="$PID_DIR/manager-web.pid"
DATA_DIR="$PYTHON_DIR/data"
CONFIG_FILE="$DATA_DIR/.config.yaml"
CONFIG_TEMPLATE="$PYTHON_DIR/config_from_api.yaml"
MYSQL_ROOT="$PYTHON_DIR/mysql"
MYSQL_DATA="$MYSQL_ROOT/data"
MYSQL_BACKUPS="$MYSQL_ROOT/backups"
UPLOAD_DIR="$PYTHON_DIR/uploadfile"
MANAGER_URL="http://127.0.0.1:8002/xiaozhi"

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

compose() {
  "$DOCKER_BIN" compose -f "$COMPOSE_FILE" "$@"
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

ensure_directories() {
  mkdir -p "$LOG_DIR" "$PID_DIR" "$DATA_DIR" "$MYSQL_DATA" "$MYSQL_BACKUPS" "$UPLOAD_DIR" "$MODEL_DIR"
}

ensure_docker() {
  if ! command -v "$DOCKER_BIN" >/dev/null 2>&1; then
    error "未找到 Docker，请先安装 Docker Desktop。"
    return 1
  fi
  if ! "$DOCKER_BIN" compose version >/dev/null 2>&1; then
    error "当前 Docker 不包含 Compose 插件。"
    return 1
  fi
  if "$DOCKER_BIN" info >/dev/null 2>&1; then
    return 0
  fi

  if is_macos && command -v open >/dev/null 2>&1; then
    info "Docker Desktop 尚未运行，正在启动……"
    open -a Docker >/dev/null 2>&1 || true
    local attempt
    for attempt in {1..60}; do
      if "$DOCKER_BIN" info >/dev/null 2>&1; then
        success "Docker Desktop 已就绪。"
        return 0
      fi
      sleep 2
    done
  fi

  error "Docker 服务未运行，请先启动 Docker Desktop。"
  return 1
}

database_initialized() {
  [[ -d "$MYSQL_DATA/mysql" ]] && find "$MYSQL_DATA/mysql" -mindepth 1 -print -quit 2>/dev/null | grep -q .
}

choose_database_mode() {
  local requested_mode="${1:-ask}"
  case "$requested_mode" in
    keep|init|demo)
      printf '%s\n' "$requested_mode"
      return
      ;;
    ask) ;;
    *)
      error "未知数据库模式：$requested_mode"
      return 2
      ;;
  esac

  if [[ ! -t 0 ]]; then
    printf '%s\n' "keep"
    return
  fi

  if database_initialized; then
    printf '检测到已有开发数据库。是否备份旧数据并重新初始化？[y/N] ' >&2
    local answer
    read -r answer
    case "$answer" in
      y|Y|yes|YES) printf '%s\n' "init" ;;
      *) printf '%s\n' "keep" ;;
    esac
  else
    printf '未检测到数据库，首次启动将自动初始化。按回车继续，输入 n 取消：[Y/n] ' >&2
    local answer
    read -r answer
    case "$answer" in
      n|N|no|NO) return 1 ;;
      *) printf '%s\n' "keep" ;;
    esac
  fi
}

demo_reset_script() {
  printf '%s\n' "$ROOT_DIR/scripts/demo/reset-demo-db.sh"
}

# 空表结构和演示基线的区别在这里：Liquibase 只建表，登录账号和模型配置来自这个脚本。
write_demo_baseline() {
  local script
  script="$(demo_reset_script)"
  if [[ ! -x "$script" ]]; then
    error "缺少可执行的 scripts/demo/reset-demo-db.sh，无法写入演示基线。"
    return 1
  fi
  info "正在写入演示数据库基线（演示账号、豆包模型、音色、角色模板）……"
  "$script" --yes || return 1
  verify_demo_baseline || return 1
  apply_lan_access_params || return 1
}

detect_lan_ip() {
  local ip=""
  local iface
  for iface in en0 en1 en2; do
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    [[ -n "$ip" ]] && break
  done
  # 虚拟网卡（198.18/16 是常见的代理软件网段）设备连不上，宁可留空让人工确认。
  if [[ "$ip" == 198.18.* || "$ip" == 169.254.* ]]; then
    ip=""
  fi
  printf '%s' "$ip"
}

# reset-demo-db.sh 不管这三个参数，重置后它们是 Liquibase 的 null；
# 为 null 时 manager-api 会自动探测，可能下发旧网络的残留 IP，设备直接连不上。
apply_lan_access_params() {
  local lan_ip
  lan_ip="$(detect_lan_ip)"
  if [[ -z "$lan_ip" ]]; then
    warn "未能探测到局域网 IP；server.websocket / server.ota 仍为 null。"
    warn "烧录设备前请登录控制台，在参数管理里手动填写这两项。"
    return 0
  fi

  local db_user db_password db_name project mysql_container redis_container
  db_user="${DEMO_DB_USER:-root}"
  db_password="${DEMO_DB_PASSWORD:-123456}"
  db_name="${DEMO_DB_NAME:-xiaozhi_esp32_server}"
  project="${DEMO_COMPOSE_PROJECT:-yunshu-link-dev}"
  mysql_container="${project}-mysql-1"
  redis_container="${project}-redis-1"

  info "正在把设备接入地址指向本机局域网 IP $lan_ip ……"
  if ! "$DOCKER_BIN" exec "$mysql_container" mysql -u"$db_user" -p"$db_password" "$db_name" -e "
    UPDATE sys_params SET param_value='ws://${lan_ip}:8000/xiaozhi/v1/' WHERE param_code='server.websocket';
    UPDATE sys_params SET param_value='http://${lan_ip}:8002/xiaozhi/ota/' WHERE param_code='server.ota';
    UPDATE sys_params SET param_value='http://${lan_ip}:8001' WHERE param_code='server.fronted_url';
  " 2>/dev/null; then
    warn "写入接入地址失败；烧录前请在控制台参数管理里手动确认。"
    return 0
  fi

  # 参数走 Redis 缓存，不清理的话新值不生效。
  "$DOCKER_BIN" exec "$redis_container" redis-cli FLUSHALL >/dev/null 2>&1 || true
  success "接入地址已写入：ws://${lan_ip}:8000 / http://${lan_ip}:8002"
  warn "换 Wi-Fi 或换机后 IP 会变，需重新执行演示初始化或手动更新这两项。"
}

# 基线写入后做一次结构性抽查：账号和三类模型缺任何一项，登录页或语音链路就是坏的。
verify_demo_baseline() {
  local db_user db_password db_name project mysql_container
  db_user="${DEMO_DB_USER:-root}"
  db_password="${DEMO_DB_PASSWORD:-123456}"
  db_name="${DEMO_DB_NAME:-xiaozhi_esp32_server}"
  project="${DEMO_COMPOSE_PROJECT:-yunshu-link-dev}"
  mysql_container="${project}-mysql-1"

  # 先单独探活：连不上可以宽容，但"连上了却查不到基线表"正是要拦的故障形态，不能混为一谈。
  if ! "$DOCKER_BIN" exec "$mysql_container" mysql -u"$db_user" -p"$db_password" -N -B -e "SELECT 1;" >/dev/null 2>&1; then
    warn "无法连接数据库校验演示基线，已跳过该检查。"
    warn "开始演示前请自行确认能用演示账号登录 Web 端。"
    return 0
  fi

  local counts
  counts="$("$DOCKER_BIN" exec "$mysql_container" mysql -u"$db_user" -p"$db_password" "$db_name" -N -B -e "
    SELECT
      (SELECT COUNT(*) FROM sys_user),
      (SELECT COUNT(*) FROM ai_agent),
      (SELECT COUNT(*) FROM ai_model_config WHERE id IN ('LLM_DoubaoCharacter','TTS_DoubaoSeedTTS','ASR_DoubaoStreamASRV2') AND is_enabled = 1);
  " 2>/dev/null || true)"

  if [[ -z "$counts" ]]; then
    error "数据库连接正常，但读不到演示基线表（sys_user / ai_agent / ai_model_config）。"
    error "通常意味着只建了空表结构而没写基线；请执行 ./start-dev.sh start --demo。"
    return 1
  fi

  local users agents models
  users="$(printf '%s' "$counts" | awk '{print $1}')"
  agents="$(printf '%s' "$counts" | awk '{print $2}')"
  models="$(printf '%s' "$counts" | awk '{print $3}')"

  local problems=()
  [[ "${users:-0}" -ge 1 ]] || problems+=("没有登录账号（sys_user 为空），Web 端无法登录")
  [[ "${agents:-0}" -ge 1 ]] || problems+=("没有智能体（ai_agent 为空）")
  [[ "${models:-0}" -eq 3 ]] || problems+=("豆包 LLM/TTS/ASR 模型配置不全（已启用 ${models:-0}/3）")

  if ((${#problems[@]} > 0)); then
    error "演示基线校验未通过："
    local problem
    for problem in "${problems[@]}"; do
      printf '  - %s\n' "$problem" >&2
    done
    error "请检查 scripts/demo/reset-demo-db.sh 的输出，不要在这个状态下开始演示或烧录。"
    return 1
  fi

  success "演示基线校验通过：账号、智能体、豆包三类模型齐备。"
}

initialize_database() {
  if database_initialized; then
    local backup_dir="$MYSQL_BACKUPS/data-$(date '+%Y%m%d-%H%M%S')"
    info "正在停止会访问数据库的容器……"
    compose stop manager-api mysql >/dev/null 2>&1 || true
    info "正在备份旧数据库到 $backup_dir"
    mv "$MYSQL_DATA" "$backup_dir"
    mkdir -p "$MYSQL_DATA"
    success "旧数据库已备份，可随时手动恢复。"
  else
    info "未发现旧数据库，将执行首次初始化。"
  fi
}

wait_for_container_health() {
  local service="$1"
  local max_attempts="${2:-60}"
  local attempt status container_id

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    container_id="$(compose ps -q "$service" 2>/dev/null || true)"
    if [[ -n "$container_id" ]]; then
      status="$("$DOCKER_BIN" inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id" 2>/dev/null || true)"
      if [[ "$status" == "healthy" || "$status" == "running" ]]; then
        return 0
      fi
      if [[ "$status" == "unhealthy" || "$status" == "exited" || "$status" == "dead" ]]; then
        error "$service 容器状态异常：$status"
        return 1
      fi
    fi
    sleep 2
  done
  error "等待 $service 就绪超时。"
  return 1
}

start_docker_services() {
  info "正在确保 MySQL、Redis 和 manager-api 运行（已运行的数据库不会重启）……"
  compose up -d --remove-orphans mysql redis manager-api
  wait_for_container_health mysql 60
  wait_for_container_health redis 30
}

wait_for_manager() {
  local attempt
  for attempt in {1..90}; do
    if curl -fsS --max-time 2 "$MANAGER_URL/doc.html" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  error "manager-api 在 180 秒内未就绪。"
  compose logs --tail=120 manager-api >&2 || true
  return 1
}

read_server_secret() {
  compose exec -T mysql mysql \
    -uroot -p123456 -N -s xiaozhi_esp32_server \
    -e "SELECT param_value FROM sys_params WHERE param_code='server.secret' LIMIT 1;" \
    2>/dev/null | tr -d '\r\n'
}

update_manager_config() {
  local config_file="$1"
  local api_url="$2"
  local secret="$3"
  local tmp_file="$config_file.tmp.$$"

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

  cp "$config_file" "$config_file.bak"
  mv "$tmp_file" "$config_file"
}

prepare_server_config() {
  local secret
  secret="$(read_server_secret)"
  if [[ -z "$secret" || "$secret" == "null" ]]; then
    error "manager-api 尚未生成 server.secret，请查看 manager-api 日志。"
    return 1
  fi

  if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
    info "已创建 API 模式配置：main/xiaozhi-server/data/.config.yaml"
  fi

  if ! update_manager_config "$CONFIG_FILE" "$MANAGER_URL" "$secret"; then
    error "现有 data/.config.yaml 不是 API 模式配置，已保持原样。"
    error "请确认它包含 manager-api.url 和 manager-api.secret。"
    return 1
  fi
  success "已同步本地 Python 服务所需的 manager-api 地址与密钥。"
}

file_hash() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$@" | shasum -a 256 | awk '{print $1}'
  else
    sha256sum "$@" | sha256sum | awk '{print $1}'
  fi
}

prepare_python_environment() {
  local python_bin="$PYTHON_ENV/bin/python"
  local ffmpeg_dir=""

  if [[ ! -x "$python_bin" ]]; then
    if command -v conda >/dev/null 2>&1; then
      info "首次运行：正在创建隔离的 Python 3.10 + FFmpeg 环境……"
      conda create --prefix "$PYTHON_ENV" --yes python=3.10 ffmpeg pip
    elif command -v uv >/dev/null 2>&1; then
      info "首次运行：正在用 uv 创建隔离的 Python 3.10 环境……"
      uv venv --python 3.10 "$PYTHON_ENV"
    else
      error "未找到 Conda 或 uv，无法自动创建 Python 3.10 隔离环境。"
      return 1
    fi
  fi

  if ! "$python_bin" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 10) else 1)'; then
    error "$PYTHON_ENV 不是 Python 3.10 环境，请移走该目录后重试。"
    return 1
  fi

  if [[ -x "$PYTHON_ENV/bin/ffmpeg" ]]; then
    ffmpeg_dir="$PYTHON_ENV/bin"
  elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg_dir="$(dirname -- "$(command -v ffmpeg)")"
  else
    error "Python 环境已创建，但未找到 FFmpeg。建议安装 Conda 后移走 $PYTHON_ENV 再运行。"
    return 1
  fi

  local requirements_hash marker
  requirements_hash="$(file_hash "$PYTHON_REQUIREMENTS")"
  marker="$PYTHON_ENV/.requirements.sha256"
  if [[ ! -f "$marker" || "$(<"$marker")" != "$requirements_hash" ]]; then
    info "正在安装或更新 Python 依赖……"
    if command -v uv >/dev/null 2>&1; then
      if ! uv pip install --python "$python_bin" --requirement "$PYTHON_REQUIREMENTS"; then
        unlink "$marker" 2>/dev/null || true
        error "Python 依赖安装失败，未写入成功标记。"
        return 1
      fi
    else
      if ! "$python_bin" -m pip install --requirement "$PYTHON_REQUIREMENTS"; then
        unlink "$marker" 2>/dev/null || true
        error "Python 依赖安装失败，未写入成功标记。"
        return 1
      fi
    fi
    if ! "$python_bin" -c 'import aioconsole, openai, requests, websockets, yaml'; then
      unlink "$marker" 2>/dev/null || true
      error "Python 核心依赖自检失败，未写入成功标记。"
      return 1
    fi
    printf '%s\n' "$requirements_hash" >"$marker"
  else
    info "Python 依赖未变化，跳过安装。"
  fi

  PYTHON_BIN="$python_bin"
  PYTHON_PATH_PREFIX="$ffmpeg_dir"
}

prepare_sensevoice_model() {
  if [[ -s "$MODEL_FILE" ]]; then
    info "SenseVoice 模型已存在，跳过下载。"
    return
  fi

  info "首次运行：正在下载 SenseVoice 模型（约 900 MB，支持断点续传）……"
  if ! curl -fL --retry 3 --connect-timeout 20 -C - \
    --output "$MODEL_FILE.part" "$MODEL_URL"; then
    error "SenseVoice 模型下载失败，保留临时文件供下次续传。"
    return 1
  fi
  if [[ ! -s "$MODEL_FILE.part" ]]; then
    error "下载的 SenseVoice 模型为空。"
    return 1
  fi
  mv "$MODEL_FILE.part" "$MODEL_FILE"
  success "SenseVoice 模型下载完成。"
}

prepare_frontend_environment() {
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    error "未找到 Node.js/npm。manager-web 需要 Node.js 18 或更高版本。"
    return 1
  fi

  local node_major
  node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
  if ((node_major < 18)); then
    error "当前 Node.js 版本过低：$(node --version)，需要 18 或更高版本。"
    return 1
  fi

  local dependency_hash marker
  dependency_hash="$(file_hash "$WEB_DIR/package.json" "$WEB_DIR/package-lock.json")"
  marker="$WEB_DIR/node_modules/.yunshu-dependencies.sha256"
  if [[ ! -x "$WEB_DIR/node_modules/.bin/vue-cli-service" || ! -f "$marker" || "$(<"$marker")" != "$dependency_hash" ]]; then
    info "正在安装或更新前端依赖……"
    (cd "$WEB_DIR" && npm ci)
    printf '%s\n' "$dependency_hash" >"$marker"
  else
    info "前端依赖未变化，跳过安装。"
  fi
}

pid_is_running() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] || return 1
  local pid command_line
  pid="$(<"$pid_file")"
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null || return 1
  command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  case "$pid_file" in
    "$PYTHON_PID") [[ "$command_line" == *"app.py"* ]] ;;
    "$WEB_PID") [[ "$command_line" == *"npm"*"run"*"serve"* || "$command_line" == *"vue-cli-service"*"serve"* ]] ;;
    *) [[ -n "$command_line" ]] ;;
  esac
}

port_is_listening() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  else
    (echo >/dev/tcp/127.0.0.1/"$port") >/dev/null 2>&1
  fi
}

ensure_port_available() {
  local port="$1"
  local service_name="$2"
  local pid_file="$3"
  if pid_is_running "$pid_file"; then
    return 0
  fi
  rm -f "$pid_file"
  if port_is_listening "$port"; then
    error "端口 $port 已被其他进程占用，无法启动 $service_name。"
    return 1
  fi
}

wait_for_port() {
  local port="$1"
  local pid_file="$2"
  local service_name="$3"
  local attempt missing_checks=0
  for attempt in {1..60}; do
    if port_is_listening "$port"; then
      return 0
    fi
    if pid_is_running "$pid_file"; then
      missing_checks=0
    else
      missing_checks=$((missing_checks + 1))
      # npm/nohup 启动时命令行会短暂切换，连续多次无法识别才判定退出。
      if ((missing_checks >= 3)); then
        error "$service_name 启动进程已退出，最近日志如下："
        return 1
      fi
    fi
    sleep 2
  done
  error "等待 $service_name 监听端口 $port 超时。"
  return 1
}

start_python() {
  if pid_is_running "$PYTHON_PID"; then
    info "xiaozhi-server 已在运行，跳过重启。"
    return 0
  fi
  ensure_port_available 8000 "xiaozhi-server" "$PYTHON_PID"
  ensure_port_available 8003 "xiaozhi-server HTTP" "$PYTHON_PID"
  : >"$PYTHON_LOG"
  (
    cd "$PYTHON_DIR"
    nohup env PATH="$PYTHON_PATH_PREFIX:$PATH" "$PYTHON_BIN" app.py </dev/null >>"$PYTHON_LOG" 2>&1 &
    printf '%s\n' "$!" >"$PYTHON_PID"
  )
  if ! wait_for_port 8000 "$PYTHON_PID" "xiaozhi-server"; then
    tail -n 80 "$PYTHON_LOG" >&2 || true
    return 1
  fi
  success "xiaozhi-server 已启动。"
}

start_frontend() {
  if pid_is_running "$WEB_PID"; then
    info "manager-web 已在运行，跳过重启。"
    return 0
  fi
  ensure_port_available 8001 "manager-web" "$WEB_PID"
  : >"$WEB_LOG"
  (
    cd "$WEB_DIR"
    nohup env VUE_APP_DEV_PROXY_TARGET="http://127.0.0.1:8002" \
      npm run serve -- --host 127.0.0.1 </dev/null >>"$WEB_LOG" 2>&1 &
    printf '%s\n' "$!" >"$WEB_PID"
  )
  if ! wait_for_port 8001 "$WEB_PID" "manager-web"; then
    tail -n 80 "$WEB_LOG" >&2 || true
    return 1
  fi
  success "manager-web 热更新服务已启动。"
}

terminate_tree() {
  local pid="$1"
  local child
  if command -v pgrep >/dev/null 2>&1; then
    while read -r child; do
      [[ -n "$child" ]] && terminate_tree "$child"
    done < <(pgrep -P "$pid" 2>/dev/null || true)
  fi
  kill -TERM "$pid" 2>/dev/null || true
}

stop_local_service() {
  local pid_file="$1"
  local service_name="$2"
  if ! pid_is_running "$pid_file"; then
    rm -f "$pid_file"
    info "$service_name 未运行。"
    return
  fi

  local pid
  pid="$(<"$pid_file")"
  terminate_tree "$pid"
  local attempt
  for attempt in {1..20}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
  done
  kill -KILL "$pid" 2>/dev/null || true
  rm -f "$pid_file"
  success "$service_name 已停止。"
}

start_services() {
  local database_mode="${1:-ask}"
  ensure_directories || return 1
  ensure_docker || return 1
  database_mode="$(choose_database_mode "$database_mode")" || return 1
  case "$database_mode" in
    init|demo)
      initialize_database || return 1
      # init 只让 Liquibase 建表，库里没有演示账号和模型配置；demo 会在启动后补写基线。
      if [[ "$database_mode" == "init" ]]; then
        warn "--init-db 只重建空表结构，不写入演示数据：没有登录账号，也没有 LLM/TTS/ASR 模型配置。"
        warn "需要可直接登录和演示的环境，请用 ./start-dev.sh start --demo（等价于菜单选项 2）。"
      fi
      ;;
    *)
      info "保留现有数据库；不会清空数据。"
      ;;
  esac

  start_docker_services || return 1
  info "正在等待 manager-api 完成编译和 Liquibase 迁移……"
  wait_for_manager || return 1
  prepare_server_config || return 1
  prepare_python_environment || return 1
  prepare_sensevoice_model || return 1
  prepare_frontend_environment || return 1
  start_python || return 1
  start_frontend || return 1

  if [[ "$database_mode" == "demo" ]]; then
    printf '\n'
    write_demo_baseline || return 1
  fi

  # 失效的密钥在启动日志里看不出来，只会在设备连上时变成 401。这里主动打一遍真实调用。
  printf '\n'
  if [[ "$database_mode" == "demo" ]]; then
    # 重置刚用 .env 重写了全部模型密钥，这是最容易写进失效凭据的时刻，跑完整版（含 ASR 闭环）。
    if ! diagnose_models; then
      warn "模型链路自检未通过；设备烧录前请先修复上述问题。"
    fi
  elif ! diagnose_models --quick; then
    warn "模型链路自检未通过；设备烧录前请先修复上述问题。"
    warn "完整校验（含 ASR 闭环）：./start-dev.sh check-models"
  fi

  printf '\n'
  success "开发环境已启动。"
  printf '  前端热更新：  http://127.0.0.1:8001\n'
  printf '  管理 API：    http://127.0.0.1:8002/xiaozhi\n'
  printf '  WebSocket：   ws://127.0.0.1:8000/xiaozhi/v1/\n'
  printf '  Vision/HTTP： http://127.0.0.1:8003\n'
  printf '  日志目录：    %s\n\n' "$LOG_DIR"
  printf '返回启动器菜单后，可直接选择查看状态、日志、重启或停止服务。\n'
}

stop_services() {
  stop_local_service "$WEB_PID" "manager-web"
  stop_local_service "$PYTHON_PID" "xiaozhi-server"
  if "$DOCKER_BIN" info >/dev/null 2>&1; then
    info "正在停止 manager-api；MySQL 和 Redis 继续常驻。"
    compose stop manager-api
  else
    warn "Docker 未运行，已跳过 manager-api。"
  fi
}

down_services() {
  stop_local_service "$WEB_PID" "manager-web"
  stop_local_service "$PYTHON_PID" "xiaozhi-server"
  ensure_docker
  info "正在停止全部开发容器；不会删除数据库、Redis 数据或 Maven 缓存。"
  compose down --remove-orphans
}

restart_python() {
  ensure_directories || return 1
  ensure_docker || return 1
  start_docker_services || return 1
  wait_for_manager || return 1
  prepare_server_config || return 1
  prepare_python_environment || return 1
  prepare_sensevoice_model || return 1
  stop_local_service "$PYTHON_PID" "xiaozhi-server"
  start_python || return 1
  printf '\n'
  if ! diagnose_models --quick; then
    warn "模型链路自检未通过；设备烧录前请先修复上述问题。"
  fi
}

restart_web() {
  ensure_directories || return 1
  prepare_frontend_environment || return 1
  stop_local_service "$WEB_PID" "manager-web"
  start_frontend || return 1
}

restart_manager() {
  ensure_docker || return 1
  info "正在重新创建 manager-api 容器并重新编译 Java 源码；数据库保持运行。"
  compose up -d --force-recreate manager-api || return 1
  wait_for_manager || return 1
  prepare_server_config || return 1
}

show_status() {
  printf '本地服务：\n'
  if pid_is_running "$WEB_PID"; then
    printf '  manager-web      运行中 (PID %s)\n' "$(<"$WEB_PID")"
  else
    printf '  manager-web      未运行\n'
  fi
  if pid_is_running "$PYTHON_PID"; then
    printf '  xiaozhi-server   运行中 (PID %s)\n' "$(<"$PYTHON_PID")"
  else
    printf '  xiaozhi-server   未运行\n'
  fi

  printf '\nDocker 服务：\n'
  if "$DOCKER_BIN" info >/dev/null 2>&1; then
    compose ps
  else
    printf '  Docker 未运行\n'
  fi
}

follow_logs() {
  ensure_directories
  touch "$WEB_LOG" "$PYTHON_LOG"
  info "正在跟踪本地日志；manager-api 日志可用 ./start-dev.sh logs-manager 查看。"
  tail -n 100 -F "$PYTHON_LOG" "$WEB_LOG"
}

follow_manager_logs() {
  ensure_docker
  compose logs --tail=200 -f manager-api
}

diagnose_models() {
  local script="$ROOT_DIR/scripts/diagnose-models.py"
  if [[ ! -f "$script" ]]; then
    warn "缺少 scripts/diagnose-models.py，已跳过模型自检。"
    return 0
  fi
  # 单独调用 check-models 时不会走 prepare_python_environment，退回虚拟环境里的解释器。
  local python_bin="${PYTHON_BIN:-$PYTHON_DIR/.venv/bin/python}"
  if [[ ! -x "$python_bin" ]]; then
    warn "未找到 Python 解释器，已跳过模型自检；请先完整启动一次开发环境。"
    return 0
  fi
  env PATH="${PYTHON_PATH_PREFIX:-}:$PATH" "$python_bin" "$script" "$@"
}

doctor() {
  local failed=0
  printf '开发环境检查：\n'
  for command_name in "$DOCKER_BIN" curl node npm; do
    if command -v "$command_name" >/dev/null 2>&1; then
      printf '  [通过] %-10s %s\n' "$command_name" "$(command -v "$command_name")"
    else
      printf '  [缺少] %s\n' "$command_name"
      failed=1
    fi
  done
  if command -v conda >/dev/null 2>&1 || command -v uv >/dev/null 2>&1; then
    printf '  [通过] Python 环境工具（Conda 或 uv）\n'
  else
    printf '  [缺少] Conda 或 uv\n'
    failed=1
  fi
  if "$DOCKER_BIN" compose -f "$COMPOSE_FILE" config -q >/dev/null 2>&1; then
    printf '  [通过] docker-compose.dev.yml\n'
  else
    printf '  [失败] docker-compose.dev.yml 无法解析\n'
    failed=1
  fi

  if "$DOCKER_BIN" info >/dev/null 2>&1 && port_is_listening 8002; then
    printf '\n'
    diagnose_models || failed=1
  else
    printf '\n  [跳过] 模型自检需要先启动开发环境\n'
  fi
  return "$failed"
}

menu_header() {
  printf '\033[2J\033[H'
  printf '\033[1;36m'
  printf '╔══════════════════════════════════════════════╗\n'
  printf '║          YunShu-Link 图形化启动器            ║\n'
  printf '╚══════════════════════════════════════════════╝\n'
  printf '\033[0m\n'
  printf '  1. 一键启动开发环境（保留现有数据库）\n'
  printf '  2. 一键准备演示环境（备份并初始化演示数据）\n'
  printf '  3. 查看服务状态\n'
  printf '  4. 重启语音服务\n'
  printf '  5. 重启前端界面\n'
  printf '  6. 重启管理后端\n'
  printf '  7. 查看运行日志\n'
  printf '  8. 停止应用服务（保留数据库）\n'
  printf '  9. 检查开发环境\n'
  printf '  0. 退出\n\n'
}

menu_pause() {
  printf '\n按回车键返回主菜单……'
  read -r _ || true
}

run_menu_action() {
  local label="$1"
  shift
  printf '\n'
  info "$label"
  if "$@"; then
    success "$label 完成。"
  else
    error "$label 未完成，请根据上方提示处理。"
  fi
  menu_pause
}

prepare_demo_from_menu() {
  printf '\n演示初始化会先备份现有数据库，再清空业务数据并写入固定演示配置。\n'
  printf '  1. 确认继续\n'
  printf '  2. 取消并返回\n\n'
  printf '请选择 [1-2]：'
  local confirmation
  read -r confirmation
  if [[ "$confirmation" != "1" ]]; then
    warn "已取消演示数据库初始化。"
    return 0
  fi

  info "先启动当前源码，确保模型和界面都是最新版本。"
  if ! start_services keep; then
    error "开发环境启动失败，未修改演示数据库。"
    return 1
  fi
  write_demo_baseline || return 1

  # 重置会用 .env 重写全部模型密钥，这是最容易写进失效凭据的时刻，必须实测一遍。
  printf '\n'
  if ! diagnose_models; then
    error "演示数据已写入，但模型自检未通过；设备烧录前必须先修复。"
    return 1
  fi
}

show_logs_menu() {
  printf '\n  1. 查看语音服务和前端日志\n'
  printf '  2. 查看管理后端日志\n'
  printf '  0. 返回\n\n'
  printf '请选择 [0-2]：'
  local choice
  read -r choice
  case "$choice" in
    1) follow_logs ;;
    2) follow_manager_logs ;;
    0) return 0 ;;
    *) warn "无效选项：$choice" ;;
  esac
}

interactive_menu() {
  local choice
  while true; do
    menu_header
    printf '请输入数字 [0-9]：'
    read -r choice || return 0
    case "$choice" in
      1) run_menu_action "启动开发环境" start_services keep ;;
      2) run_menu_action "准备演示环境" prepare_demo_from_menu ;;
      3) run_menu_action "查看服务状态" show_status ;;
      4) run_menu_action "重启语音服务" restart_python ;;
      5) run_menu_action "重启前端界面" restart_web ;;
      6) run_menu_action "重启管理后端" restart_manager ;;
      7) run_menu_action "查看运行日志" show_logs_menu ;;
      8) run_menu_action "停止应用服务" stop_services ;;
      9) run_menu_action "检查开发环境" doctor ;;
      0)
        printf '\n已退出启动器。\n'
        return 0
        ;;
      *)
        warn "无效选项：$choice，请输入 0 到 9。"
        menu_pause
        ;;
    esac
  done
}

print_usage() {
  cat <<'EOF'
YunShu-Link 图形化启动器

日常使用只需要运行：
  ./start-dev.sh                     打开中文数字菜单

以下参数仅供自动化脚本和开发调试使用，无需记忆：
  ./start-dev.sh start
  ./start-dev.sh start --keep-db     保留数据库并启动（适合日常开发）
  ./start-dev.sh start --demo        备份后重建并写入演示基线（等价于菜单选项 2）
  ./start-dev.sh start --init-db     备份后只重建空表结构，不写演示数据（无账号、无模型）
  ./start-dev.sh restart-python      仅重启本地 Python 服务
  ./start-dev.sh restart-web         仅重启本地前端
  ./start-dev.sh restart-manager     仅重编译并重启 Docker 中的 Java API
  ./start-dev.sh stop                停止前端、Python、Java；保留 MySQL/Redis 常驻
  ./start-dev.sh down                停止全部服务，但不删除任何持久化数据
  ./start-dev.sh status              查看状态
  ./start-dev.sh logs                跟踪前端和 Python 日志
  ./start-dev.sh logs-manager        跟踪 Java API 日志
  ./start-dev.sh doctor              检查开发环境（含模型自检）
  ./start-dev.sh check-models        对启用的模型发起真实调用（烧录前建议跑一次）
EOF
}

dispatch() {
  if (($# == 0)); then
    if [[ -t 0 && -t 1 ]]; then
      interactive_menu
    else
      start_services keep
    fi
    return
  fi

  local action="$1"
  shift
  case "$action" in
    start)
      local mode="ask"
      case "${1:-}" in
        "") ;;
        --keep-db) mode="keep" ;;
        --init-db) mode="init" ;;
        --demo) mode="demo" ;;
        *)
          error "start 不支持参数：$1"
          print_usage
          return 2
          ;;
      esac
      start_services "$mode"
      ;;
    check-models) diagnose_models "$@" ;;
    restart-python) restart_python ;;
    restart-web) restart_web ;;
    restart-manager) restart_manager ;;
    stop) stop_services ;;
    down) down_services ;;
    status) show_status ;;
    logs) follow_logs ;;
    logs-manager) follow_manager_logs ;;
    doctor) doctor ;;
    help|-h|--help) print_usage ;;
    *)
      error "未知命令：$action"
      print_usage
      return 2
      ;;
  esac
}

if [[ "${DEV_START_SOURCE_ONLY:-0}" != "1" ]]; then
  dispatch "$@"
fi
