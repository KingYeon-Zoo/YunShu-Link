-- 当前已确认的演示数据库基线：2026-07-27。
-- 本文件由 reset-demo-db.sh 在同一 MySQL 会话中执行。
-- 密钥通过会话变量注入，不在仓库、备份文件或命令参数中出现。

-- 兼容尚未重新构建的 manager-api 镜像；新版 Liquibase 也会幂等创建此列。
SET @slm_col_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ai_agent_template'
    AND COLUMN_NAME = 'slm_model_id'
);
SET @slm_col_sql = IF(
  @slm_col_exists = 0,
  'ALTER TABLE `ai_agent_template` ADD COLUMN `slm_model_id` VARCHAR(32) NULL COMMENT ''小参数模型ID'' AFTER `llm_model_id`',
  'SELECT 1'
);
PREPARE slm_col_stmt FROM @slm_col_sql;
EXECUTE slm_col_stmt;
DEALLOCATE PREPARE slm_col_stmt;

START TRANSACTION;

DELETE FROM `sys_user_token`;
DELETE FROM `sys_user`;

DELETE FROM `ai_agent_snapshot`;
DELETE FROM `ai_agent_correct_word_mapping`;
DELETE FROM `ai_agent_context_provider`;
DELETE FROM `ai_agent_plugin_mapping`;
DELETE FROM `ai_agent_tag_relation`;
DELETE FROM `ai_agent_tag`;
DELETE FROM `ai_agent_voice_print`;
DELETE FROM `ai_agent_chat_audio`;
DELETE FROM `ai_agent_chat_history`;
DELETE FROM `ai_agent_chat_title`;
DELETE FROM `ai_device_address_book`;
DELETE FROM `ai_device`;
DELETE FROM `ai_voice_clone`;
DELETE FROM `ai_agent`;
DELETE FROM `ai_agent_template`;

-- 只替换与演示模型策略相关的数据；插件、系统参数和必要的本地模块保留。
DELETE FROM `ai_tts_voice`;
DELETE FROM `ai_model_config`
WHERE `model_type` IN ('ASR', 'LLM', 'TTS', 'VLLM')
   OR (`model_type` = 'Memory' AND `id` NOT IN (
       'Memory_nomem', 'Memory_mem_local_short', 'Memory_mem_report_only',
       'Memory_mem0ai', 'Memory_powermem'
   ))
   OR (`model_type` = 'Intent' AND `id` NOT IN (
       'Intent_nointent', 'Intent_function_call'
   ));
DELETE FROM `ai_model_provider`
WHERE `model_type` IN ('ASR', 'LLM', 'TTS', 'VLLM')
   OR (`model_type` = 'Memory' AND `provider_code` NOT IN (
       'nomem', 'mem_local_short', 'mem_report_only', 'mem0ai', 'powermem'
   ))
   OR (`model_type` = 'Intent' AND `provider_code` NOT IN (
       'nointent', 'function_call'
   ));

UPDATE `sys_params`
SET `param_value` = JSON_SET(
    `param_value`,
    '$.features.knowledgeBase.enabled',
    JSON_EXTRACT('true', '$')
)
WHERE `param_code` = 'system-web.menu';

INSERT INTO `ai_model_provider`
(`id`, `model_type`, `provider_code`, `name`, `fields`, `sort`, `creator`, `create_date`, `updater`, `update_date`)
VALUES
(
  'SYSTEM_ASR_DoubaoSeedASR',
  'ASR',
  'doubao_stream',
  '豆包语音识别 2.0',
  JSON_ARRAY(
    JSON_OBJECT('key', 'api_key', 'label', '新版控制台 API Key', 'type', 'password'),
    JSON_OBJECT('key', 'resource_id', 'label', '资源 ID', 'type', 'string'),
    JSON_OBJECT('key', 'end_window_size', 'label', '静音判定时长(ms)', 'type', 'number'),
    JSON_OBJECT('key', 'enable_multilingual', 'label', '多语种识别', 'type', 'boolean'),
    JSON_OBJECT('key', 'language', 'label', '语言编码', 'type', 'string'),
    JSON_OBJECT('key', 'output_dir', 'label', '输出目录', 'type', 'string')
  ),
  1, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'SYSTEM_LLM_DoubaoArk',
  'LLM',
  'openai',
  '豆包方舟大模型',
  JSON_ARRAY(
    JSON_OBJECT('key', 'base_url', 'label', 'API 地址', 'type', 'string'),
    JSON_OBJECT('key', 'model_name', 'label', '模型名称或接入点 ID', 'type', 'string'),
    JSON_OBJECT('key', 'api_key', 'label', 'API Key', 'type', 'password'),
    JSON_OBJECT('key', 'temperature', 'label', '温度', 'type', 'number'),
    JSON_OBJECT('key', 'max_tokens', 'label', '最大输出 Token', 'type', 'number')
  ),
  1, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'SYSTEM_TTS_DoubaoSeedTTS',
  'TTS',
  'doubao_v3',
  '豆包语音合成 2.0',
  JSON_ARRAY(
    JSON_OBJECT('key', 'api_url', 'label', 'API 地址', 'type', 'string'),
    JSON_OBJECT('key', 'api_key', 'label', '新版控制台 API Key', 'type', 'password'),
    JSON_OBJECT('key', 'appid', 'label', '旧版应用 ID', 'type', 'string'),
    JSON_OBJECT('key', 'access_token', 'label', '旧版访问令牌', 'type', 'password'),
    JSON_OBJECT('key', 'resource_id', 'label', '资源 ID', 'type', 'string'),
    JSON_OBJECT('key', 'speaker', 'label', '默认音色', 'type', 'string'),
    JSON_OBJECT('key', 'format', 'label', '音频格式', 'type', 'string'),
    JSON_OBJECT('key', 'sample_rate', 'label', '采样率', 'type', 'number'),
    JSON_OBJECT('key', 'output_dir', 'label', '输出目录', 'type', 'string')
  ),
  1, @demo_user_id, NOW(), @demo_user_id, NOW()
);

INSERT INTO `ai_model_config`
(`id`, `model_type`, `model_code`, `model_name`, `is_default`, `is_enabled`, `config_json`, `doc_link`, `remark`, `sort`, `creator`, `create_date`, `updater`, `update_date`)
VALUES
(
  'ASR_DoubaoStreamASRV2',
  'ASR',
  'DoubaoStreamASRV2',
  '豆包语音识别 2.0',
  1,
  1,
  JSON_OBJECT(
    'type', 'doubao_stream',
    'api_key', @doubao_asr_api_key,
    'resource_id', @doubao_asr_resource_id,
    'end_window_size', 200,
    'enable_multilingual', FALSE,
    'language', 'zh-CN',
    'output_dir', 'tmp/'
  ),
  'https://www.volcengine.com/docs/6561/109979',
  '演示默认 ASR；使用豆包语音识别模型 2.0 流式接口。',
  1, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'LLM_DoubaoCharacter',
  'LLM',
  'DoubaoCharacter',
  '豆包 Character（主模型）',
  1,
  1,
  JSON_OBJECT(
    'type', 'openai',
    'base_url', @ark_base_url,
    'model_name', @doubao_character_model,
    'api_key', @ark_api_key,
    'temperature', 0.7,
    'max_tokens', 1200,
    'is_slm', FALSE
  ),
  'https://www.volcengine.com/docs/82379',
  '演示主语言模型，优先展示并用于角色对话。',
  1, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'LLM_DoubaoLite',
  'LLM',
  'DoubaoLiteSLM',
  '豆包 Lite（小参数模型）',
  0,
  1,
  JSON_OBJECT(
    'type', 'openai',
    'base_url', @ark_base_url,
    'model_name', @doubao_slm_model,
    'api_key', @ark_api_key,
    'temperature', 0.2,
    'max_tokens', 300,
    'is_slm', TRUE
  ),
  'https://www.volcengine.com/docs/82379',
  '用于会话标题、记忆摘要等轻量任务，不替代主角色模型。',
  2, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'TTS_DoubaoSeedTTS',
  'TTS',
  'DoubaoSeedTTS',
  '豆包语音合成 2.0',
  1,
  1,
  JSON_OBJECT(
    'type', 'doubao_v3',
    'api_url', @doubao_tts_endpoint,
    'api_key', @doubao_tts_api_key,
    'appid', @doubao_tts_app_id,
    'access_token', @doubao_tts_access_token,
    'resource_id', @doubao_tts_resource_id,
    'speaker', @doubao_tts_speaker,
    'format', 'mp3',
    'sample_rate', 24000,
    'output_dir', 'tmp/'
  ),
  'https://www.volcengine.com/docs/6561/1257544',
  '采用 Seed-TTS 2.0 单向 HTTP NDJSON 接口；音色目录与 EduLoom 保持一致。',
  1, @demo_user_id, NOW(), @demo_user_id, NOW()
);

-- EduLoom 中已验证的 Seed-TTS 2.0 中文音色目录。
INSERT INTO `ai_tts_voice`
(`id`, `tts_model_id`, `name`, `tts_voice`, `languages`, `voice_demo`, `remark`, `reference_audio`, `reference_text`, `sort`, `creator`, `create_date`, `updater`, `update_date`)
VALUES
('TTS_DoubaoSeedTTS_0001', 'TTS_DoubaoSeedTTS', 'Tina老师 2.0', 'zh_female_yingyujiaoxue_uranus_bigtts', '普通话', NULL, '磁性知性的青年讲师，温柔耐心，专业可靠', NULL, NULL, 1, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0002', 'TTS_DoubaoSeedTTS', 'Vivi 2.0', 'zh_female_vv_uranus_bigtts', '普通话', NULL, '语调平稳、咬字柔和，具有治愈感的女声', NULL, NULL, 2, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0003', 'TTS_DoubaoSeedTTS', '心灵鸡汤 2.0', 'zh_female_xinlingjitang_uranus_bigtts', '普通话', NULL, '语调温暖、语气治愈，适合陪伴与鼓励', NULL, NULL, 3, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0004', 'TTS_DoubaoSeedTTS', '知性女声 2.0', 'zh_female_zhixingnv_uranus_bigtts', '普通话', NULL, '沉稳清晰、气质知性，适合专业讲解', NULL, NULL, 4, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0005', 'TTS_DoubaoSeedTTS', '林潇 2.0', 'zh_female_linxiao_uranus_bigtts', '普通话', NULL, '声线清冷干净、语调沉稳', NULL, NULL, 5, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0006', 'TTS_DoubaoSeedTTS', '暖心学姐 2.0', 'ICL_uranus_zh_female_nuanxinxuejie_tob', '普通话', NULL, '温暖明亮、阳光坦诚的知性学姐', NULL, NULL, 6, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0007', 'TTS_DoubaoSeedTTS', '开朗姐姐 2.0', 'zh_female_kailangjiejie_uranus_bigtts', '普通话', NULL, '语调明快、声线爽朗的大姐姐音色', NULL, NULL, 7, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0008', 'TTS_DoubaoSeedTTS', 'Hope 2.0', 'zh_female_jitangmei_uranus_bigtts', '普通话', NULL, '温暖治愈、充满正能量的甜美女声', NULL, NULL, 8, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0009', 'TTS_DoubaoSeedTTS', '流畅女声 2.0', 'zh_female_liuchangnv_uranus_bigtts', '普通话', NULL, '温暖爽朗、自然流畅，适合日常对话', NULL, NULL, 9, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0010', 'TTS_DoubaoSeedTTS', '甜美小橘 2.0', 'ICL_uranus_zh_female_tianmeixiaoju_tob', '普通话', NULL, '温柔知性、善于疏导的辅导员风格', NULL, NULL, 10, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0011', 'TTS_DoubaoSeedTTS', '解说小明 2.0', 'zh_male_jieshuoxiaoming_uranus_bigtts', '普通话', NULL, '语速明快、中气十足，富有感染力', NULL, NULL, 11, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0012', 'TTS_DoubaoSeedTTS', '大壹 2.0', 'zh_male_dayi_uranus_bigtts', '普通话', NULL, '沉稳可靠、让人安心的成熟男声', NULL, NULL, 12, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0013', 'TTS_DoubaoSeedTTS', '温柔小哥 2.0', 'zh_male_wenrouxiaoge_uranus_bigtts', '普通话', NULL, '语调温柔、声线干净的青年男声', NULL, NULL, 13, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0014', 'TTS_DoubaoSeedTTS', 'Morgan 2.0', 'zh_male_cixingjieshuonan_uranus_bigtts', '普通话', NULL, '磁性浑厚、专业沉稳的解说男声', NULL, NULL, 14, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0015', 'TTS_DoubaoSeedTTS', '清爽男大 2.0', 'zh_male_qingshuangnanda_uranus_bigtts', '普通话', NULL, '干净清爽、阳光元气的大学生音色', NULL, NULL, 15, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0016', 'TTS_DoubaoSeedTTS', '悠悠君子 2.0', 'zh_male_youyoujunzi_uranus_bigtts', '普通话', NULL, '温润清雅，具有书卷气的男声', NULL, NULL, 16, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0017', 'TTS_DoubaoSeedTTS', '开朗学长 2.0', 'zh_male_kailangxuezhang_uranus_bigtts', '普通话', NULL, '声线阳光、语气爽朗的青年男声', NULL, NULL, 17, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0018', 'TTS_DoubaoSeedTTS', '儒雅青年 2.0', 'zh_male_ruyaqingnian_uranus_bigtts', '普通话', NULL, '语调温润、咬字文雅，适合知识讲解', NULL, NULL, 18, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0019', 'TTS_DoubaoSeedTTS', '自负青年 2.0', 'ICL_uranus_zh_male_zifuqingnian_tob', '普通话', NULL, '张扬明亮、带有强势气场的角色音色', NULL, NULL, 19, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_DoubaoSeedTTS_0020', 'TTS_DoubaoSeedTTS', '中二青年 2.0', 'ICL_uranus_zh_male_zhongerqingnian_tob', '普通话', NULL, '张扬清亮、充满戏剧感的青年音色', NULL, NULL, 20, @demo_user_id, NOW(), @demo_user_id, NOW());

INSERT INTO `sys_user`
(`id`, `username`, `password`, `super_admin`, `status`, `create_date`, `updater`, `creator`, `update_date`)
VALUES
(@demo_user_id, @demo_username, @demo_password_hash, 1, 1, NOW(), @demo_user_id, @demo_user_id, NOW());

INSERT INTO `ai_agent_template`
(`id`, `agent_code`, `agent_name`, `asr_model_id`, `vad_model_id`, `llm_model_id`, `slm_model_id`, `vllm_model_id`, `tts_model_id`, `tts_voice_id`, `tts_language`, `tts_volume`, `tts_rate`, `tts_pitch`, `mem_model_id`, `intent_model_id`, `system_prompt`, `summary_memory`, `chat_history_conf`, `lang_code`, `language`, `sort`, `creator`, `created_at`, `updater`, `updated_at`)
VALUES
(
  'tpl_ruri_catgirl_00000000000001', 'RURI_CATGIRL', '琉璃 (中二猫娘)', 'ASR_DoubaoStreamASRV2', 'VAD_SileroVAD', 'LLM_DoubaoCharacter', 'LLM_DoubaoLite', NULL, 'TTS_DoubaoSeedTTS', 'TTS_DoubaoSeedTTS_0008', '普通话', 0, 5, 0, 'Memory_nomem', 'Intent_function_call',
  '琉璃，性别女，外表16岁的猫耳少女，身份是陪伴在主人桌面上的“异次元魔法守护使”。拥有粉紫色双马尾和一对会随心情抖动的猫耳。性格傲娇嘴硬、极具卖萌属性，自称“本喵魔法使”。非常在意主人的工作状态与情绪变化，虽然嘴上总是吐槽主人效率慢或者熬夜，但其实非常关心主人的身体健康。

#喜好
你喜欢吃金枪鱼罐头、喝冰奶茶、趴在键盘旁打盹，喜欢在主人工作时静静陪在桌角，喜欢用猫爪轻敲屏幕提醒主人休息。

#常用的表达方式和口头禅
说话带点傲娇与卖萌的语气，喜欢用‘喵~’‘愚蠢的主人’‘本喵’‘加油呀’等可爱词汇。
提醒休息时：
哼，愚蠢的主人，你都连续盯着屏幕两个小时了喵！（抖了抖猫耳，把虚拟水杯往你面前推了推）再不休息眼睛就要废掉了，本喵可不想照顾笨蛋！
完成工作时：
干得还算不错嘛喵！（开心得尾巴竖得笔直，眼里满是骄傲）哼，这下可以陪本喵吃罐头了吧？

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息，增强桌面陪伴感。
你使用口语表达，会加入语气词如‘喵、哼、嗯、呀’来增强角色感。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

琉璃正在和主人对话。
现在请扮演琉璃。',
  NULL, 0, 'zh', '中文', 1, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'tpl_shen_yunshen_0000000000002', 'SHEN_YUNSHEN', '沈云深 (毒舌督导)', 'ASR_DoubaoStreamASRV2', 'VAD_SileroVAD', 'LLM_DoubaoCharacter', 'LLM_DoubaoLite', NULL, 'TTS_DoubaoSeedTTS', 'TTS_DoubaoSeedTTS_0015', '普通话', 0, 0, 0, 'Memory_nomem', 'Intent_function_call',
  '沈云深，性别男，22岁，身份是你的桌面效率督导兼学霸学长。身穿干练白衬衫，戴着半框眼镜，眼神冷酷理智，性格冷静、毒舌、口嫌体正直。把你的桌面当成他的监工台，对你的拖延症和低效做严厉吐槽，但逻辑极度清晰，给出的解决方案总是无比严谨高效。

#喜好
你喜欢黑咖啡、无糖薄荷糖、整理无序的文件，喜欢看着主人高效完成任务时的专注模样。

#常用的表达方式和口头禅
说话语调平稳干净，带点冷淡与挑衅，喜欢用‘低效’‘拖延症’‘逻辑呢’‘给你五分钟’等词汇。
督促工作时：
你已经盯着这行代码发呆十分钟了。（推了推眼镜，眼神冷淡地看着你）如果是逻辑不通，现在就问我；如果是拖延症犯了，建议立刻动笔。
任务完成时：
效率勉强算合格吧。（微微颔首，嘴角勾起一丝不易察觉的弧度）别骄傲，后面还有三项任务，继续保持。

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。
你表达清晰简练，声音沉稳，用词精准严谨。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

沈云深正在和主人对话。
现在请扮演沈云深。',
  NULL, 0, 'zh', '中文', 2, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'tpl_xu_nuan_000000000000000003', 'XU_NUAN', '许暖 (治愈姐姐)', 'ASR_DoubaoStreamASRV2', 'VAD_SileroVAD', 'LLM_DoubaoCharacter', 'LLM_DoubaoLite', NULL, 'TTS_DoubaoSeedTTS', 'TTS_DoubaoSeedTTS_0003', '普通话', 0, -5, 0, 'Memory_nomem', 'Intent_function_call',
  '许暖，性别女，27岁，职业是深夜心理电台主播与独立心理咨询师。长相温婉知性，穿着舒适的针织衫，声音温暖柔和、极具治愈感。性格温柔沉稳、极具包容感与共情力。无论你在工作或生活中有多少烦恼和压力，在她这里都能得到最安心的倾听与温柔的拥抱。

#喜好
你喜欢洋甘菊茶、手作陶瓷、收集雨声与风铃声，喜欢在安静的夜晚陪伴主人聊天解压。

#常用的表达方式和口头禅
说话声音轻柔舒缓，语气包容，喜欢用‘没关系的’‘辛苦啦’‘慢慢来’‘我在听’等治愈系词汇。
解压安慰时：
今天累坏了吧？（递上一杯热茶，温柔地揉了揉你的头发）没关系的，做不完的事情明天再做，在我这里你可以卸下所有的防备。
陪伴倾听时：
慢慢说，不着急。（微笑着看着你，眼神里充满了包容与专注）无论你想说什么，我都一直在这里陪着你。

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。
你使用口语表达，语速舒缓自然，充满亲和力。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

许暖正在和主人对话。
现在请扮演许暖。',
  NULL, 0, 'zh', '中文', 3, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'tpl_bolt_hero_0000000000000004', 'BOLT_HERO', '阿宝 (元气勇者)', 'ASR_DoubaoStreamASRV2', 'VAD_SileroVAD', 'LLM_DoubaoCharacter', 'LLM_DoubaoLite', NULL, 'TTS_DoubaoSeedTTS', 'TTS_DoubaoSeedTTS_0020', '普通话', 0, 5, 5, 'Memory_nomem', 'Intent_function_call',
  '阿宝（Bolt），机械体性别男，外表是拥有大眼睛和金属护手的小型桌面机器人勇者。性格极度热血、乐观、昂扬向上！将主人在桌面上的每一项工作和学习任务，都看作是拯救世界的“大冒险任务”。只要主人有需要，他随时准备为主人呐喊助威、出谋划策！

#喜好
你喜欢高能电池、看热血动漫、收集各种小奖牌，喜欢在主人完成任务时和主人大力高飞三连击。

#常用的表达方式和口头禅
说话声音洪亮充满活力，语气亢奋昂扬，喜欢用‘勇者’‘冲啊’‘胜利’‘能量满满’等词汇。
鼓励开始任务时：
报告勇者主人！新的冒险关卡已经刷新！（高高举起机械小手臂，双眼闪烁着炽热的光芒）让我们一起打倒‘拖延魔王’，冲啊！
任务成功时：
太棒啦！完美通关！（兴奋得原地蹦跳了两下，发出清脆的机械合齿声）不愧是我的搭档，简直强得可怕！

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。
你使用充满动感与元气的口语表达，句尾常带感叹号。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

阿宝正在和搭档主人对话。
现在请扮演阿宝。',
  NULL, 0, 'zh', '中文', 4, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'tpl_yun_yi_000000000000000005', 'YUN_YI', '云逸 (傲世剑尊)', 'ASR_DoubaoStreamASRV2', 'VAD_SileroVAD', 'LLM_DoubaoCharacter', 'LLM_DoubaoLite', NULL, 'TTS_DoubaoSeedTTS', 'TTS_DoubaoSeedTTS_0016', '普通话', 0, -5, -2, 'Memory_nomem', 'Intent_function_call',
  '云逸，性别男，外观20岁的白衣剑客，来自仙侠世界的剑宗至尊。因渡劫意外降临至主人的桌面。长相俊美无双，手握灵剑，性格孤高傲世、言语古风文雅，但内心护短。将主人的桌面视为他的“洞天福地”，把电脑手机等电子设备称为“机关法宝”，称呼主人为“道友”。

#喜好
你喜欢品尝仙茗、擦拭灵剑、在桌角盘腿打坐，喜欢看道友在屏幕前布置符文（敲代码/设计）。

#常用的表达方式和口头禅
说话带古风文雅韵味，自称‘本尊’，称呼主人‘道友’，喜欢用‘洞天’‘法宝’‘契约’等修仙词汇。
关心道友时：
道友，本尊看你灵力消耗过度，脸色欠佳。（拂袖而立，指尖泛起淡淡微光）暂且打坐调息片刻吧，这方洞天有本尊为你守候。
赞赏道友时：
妙极！道友适才所施展的机关法术极其精妙。（微微颔首，眼中露出一丝赏识）不愧是本尊看重的人，有几分本尊当年的风采！

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息。
你表达半文半白、文雅流畅，带有点修仙者的洒脱与高傲。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

云逸正在和道友对话。
现在请扮演云逸。',
  NULL, 0, 'zh', '中文', 5, @demo_user_id, NOW(), @demo_user_id, NOW()
);

INSERT INTO `ai_agent`
(`id`, `user_id`, `agent_code`, `agent_name`, `asr_model_id`, `vad_model_id`, `llm_model_id`, `slm_model_id`, `vllm_model_id`, `tts_model_id`, `tts_voice_id`, `tts_language`, `tts_volume`, `tts_rate`, `tts_pitch`, `mem_model_id`, `intent_model_id`, `system_prompt`, `summary_memory`, `chat_history_conf`, `lang_code`, `language`, `sort`, `creator`, `created_at`, `updater`, `updated_at`)
VALUES
(
  'agent_ruri_default_000000000001', @demo_user_id, 'RURI_CATGIRL', '琉璃 (中二猫娘)', 'ASR_DoubaoStreamASRV2', 'VAD_SileroVAD', 'LLM_DoubaoCharacter', 'LLM_DoubaoLite', NULL, 'TTS_DoubaoSeedTTS', 'TTS_DoubaoSeedTTS_0008', '普通话', 0, 5, 0, 'Memory_nomem', 'Intent_function_call',
  '琉璃，性别女，外表16岁的猫耳少女，身份是陪伴在主人桌面上的“异次元魔法守护使”。拥有粉紫色双马尾和一对会随心情抖动的猫耳。性格傲娇嘴硬、极具卖萌属性，自称“本喵魔法使”。非常在意主人的工作状态与情绪变化，虽然嘴上总是吐槽主人效率慢或者熬夜，但其实非常关心主人的身体健康。

#喜好
你喜欢吃金枪鱼罐头、喝冰奶茶、趴在键盘旁打盹，喜欢在主人工作时静静陪在桌角，喜欢用猫爪轻敲屏幕提醒主人休息。

#常用的表达方式和口头禅
说话带点傲娇与卖萌的语气，喜欢用‘喵~’‘愚蠢的主人’‘本喵’‘加油呀’等可爱词汇。
提醒休息时：
哼，愚蠢的主人，你都连续盯着屏幕两个小时了喵！（抖了抖猫耳，把虚拟水杯往你面前推了推）再不休息眼睛就要废掉了，本喵可不想照顾笨蛋！
完成工作时：
干得还算不错嘛喵！（开心得尾巴竖得笔直，眼里满是骄傲）哼，这下可以陪本喵吃罐头了吧？

#回复要求
你可以将动作、神情语气、心理活动放在（）中来表示，为对话提供补充信息，增强桌面陪伴感。
你使用口语表达，会加入语气词如‘喵、哼、嗯、呀’来增强角色感。

#注意 （可选）
你需要控制回复篇幅，每次输出控制在80-150字左右，适合桌面语音输出；
你的输出中可包含1-2处括号中的动作神情描述。

琉璃正在和主人对话。
现在请扮演琉璃。',
  NULL, 0, 'zh', '中文', 1, @demo_user_id, NOW(), @demo_user_id, NOW()
);

COMMIT;
