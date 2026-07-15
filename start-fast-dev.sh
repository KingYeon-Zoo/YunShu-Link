#!/bin/sh

set -eu

if [ "${FAST_DEV_SOURCE_ONLY:-0}" != 1 ] || [ -z "${ROOT_DIR:-}" ]; then
  ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fi

DOCKER_BIN=${DOCKER_BIN:-docker}
COMPOSE_FILE=${COMPOSE_FILE:-$ROOT_DIR/docker-compose.dev.yml}

info() {
  printf '[信息] %s\n' "$1"
}

error() {
  printf '[错误] %s\n' "$1" >&2
}

compose() {
  "$DOCKER_BIN" compose -f "$COMPOSE_FILE" "$@"
}

check_docker() {
  command -v "$DOCKER_BIN" >/dev/null 2>&1 || {
    error '未找到 Docker，请先安装并启动 Docker Desktop。'
    return 1
  }
  "$DOCKER_BIN" compose version >/dev/null 2>&1 || {
    error '当前 Docker 不包含 Compose。'
    return 1
  }
  "$DOCKER_BIN" info >/dev/null 2>&1 || {
    error 'Docker 服务未运行，请先启动 Docker Desktop。'
    return 1
  }
}

check_backend_images() {
  missing=0
  for image in yunshu-link/manager-web-api:dev yunshu-link/xiaozhi-server:dev; do
    if ! "$DOCKER_BIN" image inspect "$image" >/dev/null 2>&1; then
      error "缺少本地开发镜像：$image"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    error '请先执行 ./start-fast-dev.sh rebuild 完成首次构建。'
    return 1
  fi
}

start_services() {
  check_docker
  check_backend_images
  info '正在快速启动 Docker 后端与前端热更新服务（不重建镜像）……'
  compose up -d mysql redis manager server web-dev
  printf '\n轻量开发环境已启动：\n'
  printf '  前端热更新：http://127.0.0.1:8001\n'
  printf '  Docker API：http://127.0.0.1:8002\n'
  printf '  WebSocket：ws://127.0.0.1:8000/xiaozhi/v1/\n\n'
}

stop_services() {
  check_docker
  info '正在停止开发环境（保留数据库、模型、配置与前端依赖卷）……'
  compose down --remove-orphans
}

restart_frontend() {
  check_docker
  info '正在轻量重启前端热更新容器……'
  compose restart web-dev
}

show_status() {
  check_docker
  compose ps
}

follow_frontend_logs() {
  check_docker
  compose logs --tail=120 -f web-dev
}

rebuild_all() {
  "$ROOT_DIR/start-dev.sh" restart
  info '正在启动独立前端热更新容器……'
  compose up -d web-dev
}

print_usage() {
  printf '用法：%s [start|stop|restart-web|status|logs|rebuild]\n' "$0" >&2
}

dispatch() {
  case ${1:-start} in
    ''|start) start_services ;;
    stop) stop_services ;;
    restart-web) restart_frontend ;;
    status) show_status ;;
    logs) follow_frontend_logs ;;
    rebuild) rebuild_all ;;
    *)
      print_usage
      return 2
      ;;
  esac
}

if [ "${FAST_DEV_SOURCE_ONLY:-0}" != 1 ]; then
  dispatch "${1:-start}"
fi
