-- 当前已确认的演示数据库基线（2026-07-27）。
-- 只输出状态，不输出模型密钥、密码或 server.secret。
--
-- 基线分两层：
--   1. 固定层 —— 演示账号、默认智能体琉璃、五套角色模板、豆包模型链路、20 个
--      Seed-TTS 音色。这些用 SHA2 逐字段校验，任何改动都会被发现。
--   2. 展示层 —— 多厂商模型目录、五个智能体实例、设备、聊天记录、知识库语料。
--      这些只校验规模与关键不变量（外键完整、知识库不触发 RAGFlow 同步、
--      智能体只绑豆包），因为具体条数会随语料更新变化。
SET SESSION group_concat_max_len = 1048576;

SELECT IF(
    (SELECT COUNT(*) FROM `sys_user`) = 1
    AND (
        SELECT COUNT(*)
        FROM `sys_user`
        WHERE `username` = 'demo' AND `status` = 1 AND `super_admin` = 1
    ) = 1
    -- 默认智能体逐字段校验；其余四个由模板派生，只查数量。
    AND (
        SELECT COUNT(*)
        FROM `ai_agent` a
        JOIN `sys_user` u ON u.`id` = a.`user_id`
        WHERE a.`id` = 'agent_ruri_default_000000000001'
          AND a.`agent_code` = 'RURI_CATGIRL'
          AND a.`agent_name` = '琉璃 (中二猫娘)'
          AND u.`username` = 'demo'
          AND a.`asr_model_id` = 'ASR_DoubaoStreamASRV2'
          AND a.`llm_model_id` = 'LLM_DoubaoCharacter'
          AND a.`slm_model_id` = 'LLM_DoubaoLite'
          AND a.`tts_model_id` = 'TTS_DoubaoSeedTTS'
          AND a.`tts_voice_id` = 'TTS_DoubaoSeedTTS_0008'
    ) = 1
    AND (
        SELECT SHA2(CONCAT_WS(
            '|', `agent_code`, `agent_name`, `asr_model_id`, `vad_model_id`,
            `llm_model_id`, `slm_model_id`, COALESCE(`vllm_model_id`, ''),
            `tts_model_id`, `tts_voice_id`, `tts_language`, `tts_volume`,
            `tts_rate`, `tts_pitch`, `mem_model_id`, `intent_model_id`,
            `system_prompt`, COALESCE(`summary_memory`, ''), `chat_history_conf`,
            `lang_code`, `language`, `sort`
        ), 256)
        FROM `ai_agent`
        WHERE `id` = 'agent_ruri_default_000000000001'
    ) = '7cbe2626a539a8d253bc0414acdd1cb1a63fa90146d4cb454a2b8ff59c5a153b'
    AND (SELECT COUNT(*) FROM `ai_agent`) = 5
    -- 全部智能体都得有记忆模型，否则前端「聊天记录」入口是灰的。
    AND (
        SELECT COUNT(*) FROM `ai_agent`
        WHERE `mem_model_id` = 'Memory_nomem' OR `chat_history_conf` = 0
    ) = 0
    -- 智能体只能绑豆包：check-models 会对绑定的模型发真实请求。
    AND (
        SELECT COUNT(*) FROM `ai_agent`
        WHERE `llm_model_id` NOT IN ('LLM_DoubaoCharacter', 'LLM_DoubaoLite')
           OR `tts_model_id` <> 'TTS_DoubaoSeedTTS'
           OR `asr_model_id` <> 'ASR_DoubaoStreamASRV2'
    ) = 0
    AND (SELECT COUNT(*) FROM `ai_agent_template`) = 5
    AND (
        SELECT SHA2(GROUP_CONCAT(CONCAT_WS(
            '|', `id`, `agent_code`, `agent_name`, `asr_model_id`, `vad_model_id`,
            `llm_model_id`, `slm_model_id`, COALESCE(`vllm_model_id`, ''),
            `tts_model_id`, `tts_voice_id`, `tts_language`, `tts_volume`,
            `tts_rate`, `tts_pitch`, `mem_model_id`, `intent_model_id`,
            `system_prompt`, COALESCE(`summary_memory`, ''), `chat_history_conf`,
            `lang_code`, `language`, `sort`
        ) ORDER BY `id` SEPARATOR ';'), 256)
        FROM `ai_agent_template`
    ) = '9154cfe873242a9c2e7dbfb3aab22248e71d27dbd74ac616e06046219a1414d6'
    AND (SELECT COUNT(*) FROM `ai_tts_voice`) = 25
    AND (
        SELECT SHA2(GROUP_CONCAT(CONCAT_WS(
            '|', `id`, `tts_model_id`, `name`, `tts_voice`, `languages`,
            COALESCE(`voice_demo`, ''), COALESCE(`remark`, ''),
            COALESCE(`reference_audio`, ''), COALESCE(`reference_text`, ''), `sort`
        ) ORDER BY `id` SEPARATOR ';'), 256)
        FROM `ai_tts_voice`
    ) = 'a0e11620e139726557bfd9e180b7319ae0f19534fe7592a7b8b7e70250b78bc6'
    AND (
        SELECT GROUP_CONCAT(`id` ORDER BY `id` SEPARATOR ',')
        FROM `ai_model_config`
    ) = 'ASR_DoubaoStreamASRV2,ASR_FunASRLocal,Intent_function_call,Intent_nointent,LLM_DeepSeekChat,LLM_DoubaoCharacter,LLM_DoubaoLite,LLM_DoubaoPro,LLM_GLM4Flash,LLM_OllamaQwen,LLM_QwenPlus,Memory_mem_local_short,Memory_mem_report_only,Memory_mem0ai,Memory_nomem,Memory_powermem,RAG_RAGFlow,TTS_DoubaoSeedTTS,TTS_EdgeTTS,VAD_SileroVAD,VLLM_DoubaoVision'
    AND (
        SELECT GROUP_CONCAT(`id` ORDER BY `id` SEPARATOR ',')
        FROM `ai_model_provider`
    ) = 'SYSTEM_ASR_DoubaoSeedASR,SYSTEM_ASR_FunASRLocal,SYSTEM_Intent_function_call,SYSTEM_Intent_nointent,SYSTEM_LLM_DoubaoArk,SYSTEM_LLM_OllamaLocal,SYSTEM_Memory_mem_local_short,SYSTEM_Memory_mem_report_only,SYSTEM_Memory_mem0ai,SYSTEM_Memory_nomem,SYSTEM_Memory_powermem,SYSTEM_PLUGIN_CALL_DEVICE,SYSTEM_PLUGIN_HA_GET_STATE,SYSTEM_PLUGIN_HA_PLAY_MUSIC,SYSTEM_PLUGIN_HA_SET_STATE,SYSTEM_PLUGIN_MUSIC,SYSTEM_PLUGIN_NEWS_CHINANEWS,SYSTEM_PLUGIN_NEWS_NEWSNOW,SYSTEM_PLUGIN_WEATHER,SYSTEM_PLUGIN_WEB_SEARCH,SYSTEM_RAG_ragflow,SYSTEM_TTS_DoubaoSeedTTS,SYSTEM_TTS_EdgeTTS,SYSTEM_VAD_SileroVAD,SYSTEM_VLLM_DoubaoVision'
    -- 每个模型类型恰好一个默认模型，且默认全部留给豆包。
    AND (
        SELECT COUNT(*)
        FROM `ai_model_config`
        WHERE (`id` = 'ASR_DoubaoStreamASRV2' AND `is_default` = 1 AND `is_enabled` = 1)
           OR (`id` = 'LLM_DoubaoCharacter' AND `is_default` = 1 AND `is_enabled` = 1)
           OR (`id` = 'LLM_DoubaoLite' AND `is_default` = 0 AND `is_enabled` = 1)
           OR (`id` = 'Memory_mem_local_short' AND `is_default` = 1 AND `is_enabled` = 1)
           OR (`id` = 'RAG_RAGFlow' AND `is_default` = 1 AND `is_enabled` = 1)
           OR (`id` = 'TTS_DoubaoSeedTTS' AND `is_default` = 1 AND `is_enabled` = 1)
           OR (`id` = 'VAD_SileroVAD' AND `is_default` = 1 AND `is_enabled` = 1)
           OR (`id` = 'VLLM_DoubaoVision' AND `is_default` = 1 AND `is_enabled` = 1)
           OR (`id` = 'Intent_function_call' AND `is_default` = 1 AND `is_enabled` = 1)
    ) = 9
    AND (
        SELECT COUNT(*) FROM (
            SELECT `model_type` FROM `ai_model_config`
            WHERE `is_default` = 1
            GROUP BY `model_type` HAVING COUNT(*) > 1
        ) `dup`
    ) = 0
    -- config_json.type 必须能在同类型 provider 里找到，否则模型配置页会报错。
    AND (
        SELECT COUNT(*) FROM `ai_model_config` c
        WHERE JSON_EXTRACT(c.`config_json`, '$.type') IS NULL
           OR NOT EXISTS (
               SELECT 1 FROM `ai_model_provider` p
               WHERE p.`model_type` = c.`model_type`
                 AND p.`provider_code` = JSON_UNQUOTE(JSON_EXTRACT(c.`config_json`, '$.type'))
           )
    ) = 0
    -- 演示展示数据的规模与引用完整性。
    AND (SELECT COUNT(*) FROM `ai_device`) = 10
    AND (
        SELECT COUNT(*) FROM `ai_device` d
        LEFT JOIN `ai_agent` a ON a.`id` = d.`agent_id`
        WHERE a.`id` IS NULL
    ) = 0
    AND (
        SELECT COUNT(*) FROM `ai_device` d
        WHERE NOT EXISTS (
            SELECT 1 FROM `sys_dict_data` dd
            JOIN `sys_dict_type` dt ON dt.`id` = dd.`dict_type_id`
            WHERE dt.`dict_type` = 'FIRMWARE_TYPE' AND dd.`dict_value` = d.`board`
        )
    ) = 0
    AND (SELECT COUNT(*) FROM `ai_agent_tag`) = 5
    AND (SELECT COUNT(*) FROM `ai_agent_tag_relation`) = 8
    AND (SELECT COUNT(*) FROM `ai_agent_chat_title`) = 6
    AND (SELECT COUNT(*) FROM `ai_agent_chat_history`) = 36
    AND (
        SELECT COUNT(*) FROM `ai_agent_chat_history` h
        LEFT JOIN `ai_agent` a ON a.`id` = h.`agent_id`
        WHERE a.`id` IS NULL
    ) = 0
    AND (SELECT COUNT(*) FROM `ai_rag_dataset`) = 4
    AND (SELECT COUNT(*) FROM `ai_rag_knowledge_document`) = 45
    -- rag_model_id 必须留空，否则无 RAGFlow 时知识库卡片会标红报异常。
    AND (
        SELECT COUNT(*) FROM `ai_rag_dataset`
        WHERE `rag_model_id` IS NOT NULL AND `rag_model_id` <> ''
    ) = 0
    AND (
        SELECT COUNT(*) FROM `ai_rag_knowledge_document` WHERE `run` <> 'DONE'
    ) = 0
    AND (
        SELECT COUNT(*) FROM `ai_rag_knowledge_document` d
        LEFT JOIN `ai_rag_dataset` s ON s.`dataset_id` = d.`dataset_id`
        WHERE s.`dataset_id` IS NULL
    ) = 0
    AND (
        SELECT JSON_UNQUOTE(JSON_EXTRACT(`param_value`, '$.features.knowledgeBase.enabled'))
        FROM `sys_params`
        WHERE `param_code` = 'system-web.menu'
        LIMIT 1
    ) = 'true'
    AND (SELECT COUNT(*) FROM `sys_dict_type`) = 2
    AND (SELECT COUNT(*) FROM `sys_dict_data`) = 92
    AND (SELECT COUNT(*) FROM `sys_params`) = 47,
    'CURRENT_DEMO_BASELINE_OK',
    'CURRENT_DEMO_BASELINE_INVALID'
) AS `baseline_status`;
