#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
SCRIPT=$ROOT_DIR/start-fast-dev.sh

[ -f "$SCRIPT" ] || {
  printf '失败：缺少 start-fast-dev.sh\n' >&2
  exit 1
}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
DOCKER_LOG=$TMP_DIR/docker.log
FAKE_DOCKER=$TMP_DIR/docker

cat >"$FAKE_DOCKER" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$DOCKER_LOG"
exit 0
SH
chmod +x "$FAKE_DOCKER"

export DOCKER_LOG
export DOCKER_BIN=$FAKE_DOCKER
export FAST_DEV_SOURCE_ONLY=1
. "$SCRIPT"

start_services
grep -q 'compose -f .*docker-compose.dev.yml up -d mysql redis manager server web-dev' "$DOCKER_LOG"
if grep -q -- '--build' "$DOCKER_LOG"; then
  printf '失败：轻量启动不得触发 Docker 构建\n' >&2
  exit 1
fi

restart_frontend
grep -q 'compose -f .*docker-compose.dev.yml restart web-dev' "$DOCKER_LOG"

compose_config=$(docker compose -f "$ROOT_DIR/docker-compose.dev.yml" config)
printf '%s\n' "$compose_config" | grep -q 'web-dev:'
printf '%s\n' "$compose_config" | grep -q 'image: node:20'
printf '%s\n' "$compose_config" | grep -q 'VUE_APP_API_BASE_URL: /xiaozhi'
printf '%s\n' "$compose_config" | grep -q 'VUE_APP_DEV_PROXY_TARGET: http://manager:8002'
printf '%s\n' "$compose_config" | grep -q 'target: /app/node_modules'

printf '通过：轻量启动不重建镜像、web-dev 独立热更新、restart-web 仅重启前端容器\n'
