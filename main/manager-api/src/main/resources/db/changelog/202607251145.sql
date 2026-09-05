-- 1. 更新本地总结记忆 (Memory_mem_local_short) 的配置，默认使用小模型 (LLM_DoubaoLite) 进行记忆总结
UPDATE `ai_model_config` 
SET `config_json` = '{"type": "mem_local_short", "llm": "LLM_DoubaoLite"}'
WHERE `id` = 'Memory_mem_local_short';

-- 2. 将本地总结记忆 (Memory_mem_local_short) 设置为默认模型 (is_default = 1) 且 sort = 1，将无记忆 (Memory_nomem) 等设为非默认 (is_default = 0) 且 sort = 99
UPDATE `ai_model_config` SET `is_default` = 0 WHERE `model_type` = 'Memory';
UPDATE `ai_model_config` SET `is_default` = 1, `sort` = 1 WHERE `id` = 'Memory_mem_local_short';
UPDATE `ai_model_provider` SET `sort` = 1 WHERE `id` = 'SYSTEM_Memory_mem_local_short';

UPDATE `ai_model_config` SET `sort` = 99 WHERE `id` = 'Memory_nomem';
UPDATE `ai_model_provider` SET `sort` = 99 WHERE `id` = 'SYSTEM_Memory_nomem';

-- 3. 将大模型自主函数调用意图识别 (Intent_function_call) 设置为默认模型 (is_default = 1) 且 sort = 1，无意图识别 (Intent_nointent) 设为非默认 (is_default = 0) 且 sort = 99
UPDATE `ai_model_config` SET `is_default` = 0 WHERE `model_type` = 'Intent';
UPDATE `ai_model_config` SET `is_default` = 1, `sort` = 1 WHERE `id` = 'Intent_function_call';
UPDATE `ai_model_provider` SET `sort` = 1 WHERE `id` = 'SYSTEM_Intent_function_call';

UPDATE `ai_model_config` SET `sort` = 99 WHERE `id` = 'Intent_nointent';
UPDATE `ai_model_provider` SET `sort` = 99 WHERE `id` = 'SYSTEM_Intent_nointent';
