#!/usr/bin/env bash
#
# 在一个临时数据库里跑完整套演示初始化 SQL，验证语法、外键长度与最终行数。
# 不碰真实的 xiaozhi_esp32_server，也不需要密钥（模型密钥字段全部塞占位值）。
#
#   bash scripts/tests/test-demo-seed.sh
#
# 依赖开发环境的 MySQL 容器已启动（./start-dev.sh start --keep-db）。

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="${DEMO_COMPOSE_PROJECT:-yunshu-link-dev}"
SOURCE_DB="${DEMO_DB_NAME:-xiaozhi_esp32_server}"
TEST_DB="demo_seed_selftest"
DB_PASSWORD="${DEMO_DB_PASSWORD:-123456}"

fail() {
  printf '\033[1;31m[失败]\033[0m %s\n' "$*" >&2
  exit 1
}

pass() {
  printf '\033[1;32m[通过]\033[0m %s\n' "$*"
}

container="$(docker ps --filter "label=com.docker.compose.project=$PROJECT" \
  --filter "label=com.docker.compose.service=mysql" --format '{{.ID}}' | head -1)"
[[ -n "$container" ]] || fail "未找到 $PROJECT 的 MySQL 容器，请先启动开发环境"

mysql_run() {
  docker exec -e "MYSQL_PWD=$DB_PASSWORD" -i "$container" \
    mysql --default-character-set=utf8mb4 -uroot "$@"
}

mysql_dump() {
  docker exec -e "MYSQL_PWD=$DB_PASSWORD" "$container" \
    mysqldump --single-transaction --set-gtid-purged=OFF -uroot "$@" 2>/dev/null
}

cleanup() {
  mysql_run -e "DROP DATABASE IF EXISTS \`$TEST_DB\`;" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# 用真实库的结构 + Liquibase 初始化数据搭一个空壳，等价于重置流程里迁移刚跑完的状态。
mysql_run -e "DROP DATABASE IF EXISTS \`$TEST_DB\`;
  CREATE DATABASE \`$TEST_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql_dump --no-data "$SOURCE_DB" | mysql_run "$TEST_DB"
mysql_dump --no-create-info "$SOURCE_DB" \
  sys_dict_type sys_dict_data sys_params ai_model_config ai_model_provider \
  | mysql_run "$TEST_DB"

seed_output="$(
  {
    printf "SET SESSION sql_mode = CONCAT_WS(',', @@sql_mode, 'NO_BACKSLASH_ESCAPES');\n"
    printf "SET @demo_user_id = 900000000000000001;\n"
    printf "SET @demo_username = 'demo';\n"
    printf "SET @demo_password_hash = 'selftest-placeholder-hash';\n"
    for name in ark_api_key ark_base_url doubao_character_model doubao_slm_model \
      doubao_asr_api_key doubao_asr_resource_id doubao_tts_api_key \
      doubao_tts_app_id doubao_tts_access_token doubao_tts_endpoint \
      doubao_tts_resource_id doubao_tts_speaker; do
      printf "SET @%s = 'selftest';\n" "$name"
    done
    for seed_file in \
      "$ROOT_DIR/scripts/demo/seed-demo.sql" \
      "$ROOT_DIR/scripts/demo/seed-demo-models.sql" \
      "$ROOT_DIR/scripts/demo/seed-demo-showcase.sql" \
      "$ROOT_DIR/scripts/demo/seed-demo-knowledge.sql"; do
      [[ -f "$seed_file" ]] || fail "缺少 $seed_file"
      cat "$seed_file"
      printf "\n"
    done
  } | mysql_run "$TEST_DB" 2>&1
)"

# seed-demo.sql 里补 slm_model_id 列的 PREPARE 分支会输出 "1"，属正常回显。
if grep -qiE '^(ERROR|Warning)' <<<"$seed_output"; then
  printf '%s\n' "$seed_output" >&2
  fail "初始化 SQL 报错"
fi
pass "四份初始化 SQL 全部执行成功"

expect_count() {
  local table="$1" minimum="$2" actual
  actual="$(mysql_run -N -s "$TEST_DB" -e "SELECT COUNT(*) FROM \`$table\`;")"
  ((actual >= minimum)) || fail "$table 只有 $actual 行，至少应有 $minimum 行"
  pass "${table}：$actual 行"
}

expect_count ai_agent 5
expect_count ai_device 10
expect_count ai_agent_tag 5
expect_count ai_agent_tag_relation 8
expect_count ai_agent_chat_history 30
expect_count ai_agent_chat_title 6
expect_count ai_rag_dataset 4
expect_count ai_rag_knowledge_document 40
expect_count ai_model_config 20
expect_count ai_tts_voice 25

# 每台设备都必须挂在真实存在的智能体上，否则设备列表按 agentId 过滤会查不到。
orphan_devices="$(mysql_run -N -s "$TEST_DB" -e "
  SELECT COUNT(*) FROM ai_device d
  LEFT JOIN ai_agent a ON a.id = d.agent_id
  WHERE a.id IS NULL;")"
((orphan_devices == 0)) || fail "有 $orphan_devices 台设备指向不存在的智能体"
pass "设备与智能体的外键引用完整"

# board 必须能在固件字典里翻译，否则设备型号列显示英文串。
unknown_boards="$(mysql_run -N -s "$TEST_DB" -e "
  SELECT COUNT(*) FROM ai_device d
  WHERE NOT EXISTS (
    SELECT 1 FROM sys_dict_data dd
    JOIN sys_dict_type dt ON dt.id = dd.dict_type_id
    WHERE dt.dict_type = 'FIRMWARE_TYPE' AND dd.dict_value = d.board);")"
((unknown_boards == 0)) || fail "有 $unknown_boards 台设备的 board 不在 FIRMWARE_TYPE 字典里"
pass "设备型号全部取自固件字典"

# 聊天记录必须挂在真实智能体上，且智能体不能是 Memory_nomem（前端会禁用入口）。
bad_history="$(mysql_run -N -s "$TEST_DB" -e "
  SELECT COUNT(*) FROM ai_agent_chat_history h
  LEFT JOIN ai_agent a ON a.id = h.agent_id
  WHERE a.id IS NULL OR a.mem_model_id = 'Memory_nomem';")"
((bad_history == 0)) || fail "有 $bad_history 条聊天记录挂在不存在或无记忆的智能体上"
pass "聊天记录可在前端打开"

# 知识库若填了 rag_model_id，列表接口会去 RAGFlow 核对并把卡片标红。
leaky_datasets="$(mysql_run -N -s "$TEST_DB" -e "
  SELECT COUNT(*) FROM ai_rag_dataset WHERE rag_model_id IS NOT NULL AND rag_model_id <> '';")"
((leaky_datasets == 0)) || fail "有 $leaky_datasets 个知识库填了 rag_model_id，无 RAGFlow 时会显示异常"
pass "知识库跳过 RAGFlow 同步"

unfinished_docs="$(mysql_run -N -s "$TEST_DB" -e "
  SELECT COUNT(*) FROM ai_rag_knowledge_document WHERE run <> 'DONE';")"
((unfinished_docs == 0)) || fail "有 $unfinished_docs 篇文档不是 DONE 状态"
pass "知识库文档全部为已解析状态"

# 文档必须挂在存在的知识库上，否则点开知识库看不到任何文档。
orphan_docs="$(mysql_run -N -s "$TEST_DB" -e "
  SELECT COUNT(*) FROM ai_rag_knowledge_document d
  LEFT JOIN ai_rag_dataset s ON s.dataset_id = d.dataset_id
  WHERE s.dataset_id IS NULL;")"
((orphan_docs == 0)) || fail "有 $orphan_docs 篇文档指向不存在的知识库"
pass "文档与知识库的引用完整"

# config_json.type 必须匹配同类型的 provider，否则模型配置页读空指针。
bad_models="$(mysql_run -N -s "$TEST_DB" -e "
  SELECT COUNT(*) FROM ai_model_config c
  WHERE JSON_EXTRACT(c.config_json, '\$.type') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM ai_model_provider p
       WHERE p.model_type = c.model_type
         AND p.provider_code = JSON_UNQUOTE(JSON_EXTRACT(c.config_json, '\$.type')));")"
((bad_models == 0)) || fail "有 $bad_models 个模型的 config_json.type 找不到对应 provider"
pass "模型与 provider 的接口类型全部匹配"

# 每个模型类型只能有一个默认，多个默认会让列表排序与智能体模板不一致。
multi_default="$(mysql_run -N -s "$TEST_DB" -e "
  SELECT COUNT(*) FROM (
    SELECT model_type FROM ai_model_config WHERE is_default = 1
    GROUP BY model_type HAVING COUNT(*) > 1) t;")"
((multi_default == 0)) || fail "有 $multi_default 个模型类型存在多个默认模型"
pass "每个模型类型恰好一个默认模型"

# 智能体只能绑定豆包那套，否则 check-models 会去调没有密钥的第三方模型。
foreign_bindings="$(mysql_run -N -s "$TEST_DB" -e "
  SELECT COUNT(*) FROM ai_agent
  WHERE llm_model_id NOT IN ('LLM_DoubaoCharacter', 'LLM_DoubaoLite')
     OR tts_model_id <> 'TTS_DoubaoSeedTTS'
     OR asr_model_id <> 'ASR_DoubaoStreamASRV2';")"
((foreign_bindings == 0)) || fail "有 $foreign_bindings 个智能体绑定了非豆包模型，自检会失败"
pass "智能体只绑定豆包模型链路"

# 最后跑一遍重置脚本用的同一份基线校验，确保两者不会各自漂移。
baseline_status="$(
  mysql_run -N -s "$TEST_DB" <"$ROOT_DIR/scripts/demo/verify-current-baseline.sql" | tr -d '\r\n'
)"
[[ "$baseline_status" == "CURRENT_DEMO_BASELINE_OK" ]] \
  || fail "verify-current-baseline.sql 返回 $baseline_status"
pass "基线校验与初始化结果一致"

printf '\n\033[1;32m演示数据自检全部通过。\033[0m\n'
