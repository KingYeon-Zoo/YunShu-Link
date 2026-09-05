#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
web_src="$repo_root/main/manager-web/src"

test -f "$web_src/assets/brand/yunshu-link-logo.png"
test -f "$web_src/assets/brand/yunshu-link-icon.png"

if rg -n "@/assets/(xiaozhi-logo\.png|xiaozhi-ai[^\"']*\.png)" "$web_src" --glob '*.{vue,js,ts}'; then
  echo "检测到仍在使用的旧品牌资源" >&2
  exit 1
fi

rg -q "@/assets/brand/yunshu-link-logo\.png" "$web_src/views/login.vue"
rg -q "@/assets/brand/yunshu-link-logo\.png" "$web_src/views/register.vue"
rg -q "@/assets/brand/yunshu-link-logo\.png" "$web_src/views/retrievePassword.vue"
rg -q "@/assets/brand/yunshu-link-logo\.png" "$web_src/components/HeaderBar.vue"
rg -q "@/assets/brand/yunshu-link-icon\.png" "$web_src/components/SidebarNav.vue"
rg -q "@/assets/brand/yunshu-link-icon\.png" "$web_src/components/ChatHistoryDialog.vue"

echo "manager-web 品牌资源引用检查通过"
