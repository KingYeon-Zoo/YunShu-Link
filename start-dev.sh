#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COMPOSE_FILE=${COMPOSE_FILE:-$ROOT_DIR/docker-compose.dev.yml}
DOCKER_BIN=${DOCKER_BIN:-docker}
MODEL_DIR=$ROOT_DIR/main/xiaozhi-server/models/SenseVoiceSmall
MODEL_FILE=$MODEL_DIR/model.pt
MODEL_URL=https://modelscope.cn/models/iic/SenseVoiceSmall/resolve/master/model.pt
DATA_DIR=$ROOT_DIR/main/xiaozhi-server/data
CONFIG_FILE=$DATA_DIR/.config.yaml
CONFIG_TEMPLATE=$ROOT_DIR/main/xiaozhi-server/config_from_api.yaml
UPLOAD_DIR=$ROOT_DIR/main/xiaozhi-server/uploadfile
MYSQL_DIR=$ROOT_DIR/main/xiaozhi-server/mysql/data
API_URL=http://xiaozhi-esp32-server-web:8002/xiaozhi

info() {
  printf '[信息] %s\n' "$1"
}

error() {
  printf '[错误] %s\n' "$1" >&2
}

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

check_docker() {
  if ! command -v "$DOCKER_BIN" >/dev/null 2>&1; then
    error '未找到 Docker。请先安装并启动 Docker Desktop。'
    return 1
  fi

  if ! "$DOCKER_BIN" compose version >/dev/null 2>&1; then
    error '当前 Docker 不包含 Compose。请升级 Docker Desktop。'
    return 1
  fi

  if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
    error 'Docker 服务未运行，请先启动 Docker Desktop。'
    return 1
  fi
}

prepare_directories() {
  mkdir -p "$MODEL_DIR" "$DATA_DIR" "$UPLOAD_DIR" "$MYSQL_DIR"
}

download_model() {
  if [ -s "$MODEL_FILE" ]; then
    info 'SenseVoice 模型已存在，跳过下载。'
    return 0
  fi

  info '首次运行需要下载 SenseVoice 模型，请耐心等待。'
  rm -f "$MODEL_FILE.part"
  if ! "$DOCKER_BIN" run --rm \
    -v "$MODEL_DIR:/download" \
    curlimages/curl:8.10.1 \
    -fL --retry 3 --connect-timeout 20 \
    -o /download/model.pt.part "$MODEL_URL"; then
    rm -f "$MODEL_FILE.part"
    error 'SenseVoice 模型下载失败，请检查网络后重试。'
    return 1
  fi

  if [ ! -s "$MODEL_FILE.part" ]; then
    rm -f "$MODEL_FILE.part"
    error '下载的 SenseVoice 模型为空，请检查网络后重试。'
    return 1
  fi

  mv "$MODEL_FILE.part" "$MODEL_FILE"
  info 'SenseVoice 模型下载完成。'
}

wait_for_manager() {
  attempts=0
  while [ "$attempts" -lt 90 ]; do
    if compose exec -T manager \
      wget -q -O /dev/null http://127.0.0.1:8002/xiaozhi/doc.html >/dev/null 2>&1; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 2
  done

  return 1
}

read_server_secret() {
  compose exec -T mysql mysql \
    -uroot -p123456 -N -s xiaozhi_esp32_server \
    -e "SELECT param_value FROM sys_params WHERE param_code='server.secret' LIMIT 1;" \
    2>/dev/null | tr -d '\r\n'
}

prepare_config() {
  secret=$1

  if [ -z "$secret" ] || [ "$secret" = null ]; then
    error 'manager-api 尚未生成 server.secret。'
    return 1
  fi

  if [ ! -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
    info '已从 API 模式模板创建 data/.config.yaml。'
  fi

  if ! update_manager_config "$CONFIG_FILE" "$API_URL" "$secret"; then
    error 'data/.config.yaml 不是可安全更新的 API 模式配置，已保留原文件。'
    error '请确认其中包含 manager-api.url 和 manager-api.secret。'
    return 1
  fi

  info '已同步 manager-api 地址和 server.secret。'
}

wait_for_server() {
  attempts=0
  while [ "$attempts" -lt 60 ]; do
    if compose exec -T server python -c \
      "import socket; a=socket.create_connection(('127.0.0.1',8000),2); a.close(); b=socket.create_connection(('127.0.0.1',8003),2); b.close()" \
      >/dev/null 2>&1; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 2
  done

  return 1
}

show_failure_logs() {
  compose ps >&2 || true
  compose logs --tail=120 manager mysql redis server >&2 || true
}

start_services() {
  check_docker
  prepare_directories
  download_model

  info '正在构建并启动 MySQL、Redis、前端和 Java 后端……'
  compose up -d --build mysql redis manager

  info '正在等待 manager-api 初始化……'
  if ! wait_for_manager; then
    error 'manager-api 在 180 秒内未就绪。'
    show_failure_logs
    return 1
  fi

  secret=$(read_server_secret) || {
    error '无法从 MySQL 读取 server.secret。'
    show_failure_logs
    return 1
  }
  prepare_config "$secret"

  info '正在构建并启动 Python 核心服务……'
  compose up -d --build server

  info '正在等待 Python 核心服务就绪……'
  if ! wait_for_server; then
    error 'Python 核心服务在 120 秒内未就绪。'
    show_failure_logs
    return 1
  fi

  printf '\n完整开发环境已启动：\n'
  printf '  控制台：  http://localhost:8002\n'
  printf '  WebSocket：ws://localhost:8000/xiaozhi/v1/\n'
  printf '  HTTP：     http://localhost:8003\n\n'
  printf '查看日志：./start-dev.sh logs\n'
  printf '停止服务：./start-dev.sh stop\n'
}

stop_services() {
  check_docker
  info '正在停止开发环境（不会删除持久化数据）……'
  compose down --remove-orphans
}

restart_services() {
  stop_services
  start_services
}

show_status() {
  check_docker
  compose ps
}

follow_logs() {
  check_docker
  compose logs --tail=200 -f
}

print_usage() {
  printf '用法：%s [start|stop|restart|status|logs]\n' "$0" >&2
}

dispatch() {
  case ${1:-start} in
    ''|start) start_services ;;
    stop) stop_services ;;
    restart) restart_services ;;
    status) show_status ;;
    logs) follow_logs ;;
    *)
      print_usage
      return 2
      ;;
  esac
}

if [ "${DOCKER_DEV_SOURCE_ONLY:-0}" != 1 ]; then
  dispatch "${1:-start}"
fi
