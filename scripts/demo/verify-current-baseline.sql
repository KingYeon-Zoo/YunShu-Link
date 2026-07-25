-- 当前已确认的演示数据库基线（2026-07-26）。
-- 只输出状态，不输出模型密钥、密码或 server.secret。
SET SESSION group_concat_max_len = 65535;

SELECT IF(
    (SELECT COUNT(*) FROM `sys_user`) = 1
    AND (
        SELECT COUNT(*)
        FROM `sys_user`
        WHERE `username` = 'demo' AND `status` = 1 AND `super_admin` = 1
    ) = 1
    AND (SELECT COUNT(*) FROM `ai_agent`) = 1
    AND (
        SELECT COUNT(*)
        FROM `ai_agent` a
        JOIN `sys_user` u ON u.`id` = a.`user_id`
        WHERE a.`agent_code` = 'RURI_CATGIRL'
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
        LIMIT 1
    ) = '77016ac0916c527e3a6271d5a53f8c86029ba31d3d2cc18d2699a00848ef28e6'
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
    AND (SELECT COUNT(*) FROM `ai_tts_voice`) = 20
    AND (
        SELECT SHA2(GROUP_CONCAT(CONCAT_WS(
            '|', `id`, `tts_model_id`, `name`, `tts_voice`, `languages`,
            COALESCE(`voice_demo`, ''), COALESCE(`remark`, ''),
            COALESCE(`reference_audio`, ''), COALESCE(`reference_text`, ''), `sort`
        ) ORDER BY `id` SEPARATOR ';'), 256)
        FROM `ai_tts_voice`
    ) = 'f5acc9ff93fdbe7b9897249e7142d9e915c6aa63c8e28f1f4e9db4965f07fcba'
    AND (
        SELECT GROUP_CONCAT(`id` ORDER BY `id` SEPARATOR ',')
        FROM `ai_model_config`
    ) = 'ASR_DoubaoStreamASRV2,Intent_function_call,Intent_nointent,LLM_DoubaoCharacter,LLM_DoubaoLite,Memory_mem_local_short,Memory_mem_report_only,Memory_mem0ai,Memory_nomem,Memory_powermem,RAG_RAGFlow,TTS_DoubaoSeedTTS,VAD_SileroVAD'
    AND (
        SELECT GROUP_CONCAT(`id` ORDER BY `id` SEPARATOR ',')
        FROM `ai_model_provider`
    ) = 'SYSTEM_ASR_DoubaoSeedASR,SYSTEM_Intent_function_call,SYSTEM_Intent_nointent,SYSTEM_LLM_DoubaoArk,SYSTEM_Memory_mem_local_short,SYSTEM_Memory_mem_report_only,SYSTEM_Memory_mem0ai,SYSTEM_Memory_nomem,SYSTEM_Memory_powermem,SYSTEM_PLUGIN_CALL_DEVICE,SYSTEM_PLUGIN_HA_GET_STATE,SYSTEM_PLUGIN_HA_PLAY_MUSIC,SYSTEM_PLUGIN_HA_SET_STATE,SYSTEM_PLUGIN_MUSIC,SYSTEM_PLUGIN_NEWS_CHINANEWS,SYSTEM_PLUGIN_NEWS_NEWSNOW,SYSTEM_PLUGIN_WEATHER,SYSTEM_PLUGIN_WEB_SEARCH,SYSTEM_RAG_ragflow,SYSTEM_TTS_DoubaoSeedTTS,SYSTEM_VAD_SileroVAD'
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
           OR (`id` = 'Intent_function_call' AND `is_default` = 1 AND `is_enabled` = 1)
    ) = 8
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
