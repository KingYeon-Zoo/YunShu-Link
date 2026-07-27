-- 演示用的多厂商模型目录。
--
-- 只有豆包那套会被智能体真正绑定，因此 ./start-dev.sh check-models 仍然只对豆包
-- 发起真实调用；这里的其余模型纯粹让「模型配置」页面不至于每类只有一行。
--
-- 三条硬约束，改这个文件时别破坏：
--   1. config_json 必须含 type，且取值等于某条 ai_model_provider.provider_code，
--      否则模型配置页的「接口类型」列会读空指针，编辑弹窗也拉不出表单。
--   2. 每个 model_type 只能有一条 is_default = 1，仍旧全部留给豆包。
--   3. is_enabled = 1 的模型会出现在智能体的模型下拉里，但只要不被 ai_agent 引用，
--      自检就不会去调它。演示环境没有这些厂商的密钥，所以密钥字段一律留空占位。

INSERT INTO `ai_model_provider`
(`id`, `model_type`, `provider_code`, `name`, `fields`, `sort`, `creator`, `create_date`, `updater`, `update_date`)
VALUES
(
  'SYSTEM_LLM_OllamaLocal', 'LLM', 'ollama', 'Ollama 本地推理',
  JSON_ARRAY(
    JSON_OBJECT('key', 'base_url', 'label', '服务地址', 'type', 'string'),
    JSON_OBJECT('key', 'model_name', 'label', '模型名称', 'type', 'string')
  ),
  10, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'SYSTEM_VLLM_DoubaoVision', 'VLLM', 'openai', '豆包视觉理解',
  JSON_ARRAY(
    JSON_OBJECT('key', 'base_url', 'label', 'API 地址', 'type', 'string'),
    JSON_OBJECT('key', 'model_name', 'label', '模型名称或接入点 ID', 'type', 'string'),
    JSON_OBJECT('key', 'api_key', 'label', 'API Key', 'type', 'password')
  ),
  1, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'SYSTEM_ASR_FunASRLocal', 'ASR', 'fun_local', 'FunASR 本地识别',
  JSON_ARRAY(
    JSON_OBJECT('key', 'model_dir', 'label', '模型目录', 'type', 'string'),
    JSON_OBJECT('key', 'output_dir', 'label', '输出目录', 'type', 'string')
  ),
  10, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'SYSTEM_TTS_EdgeTTS', 'TTS', 'edge', 'Edge 免费语音合成',
  JSON_ARRAY(
    JSON_OBJECT('key', 'voice', 'label', '音色', 'type', 'string'),
    JSON_OBJECT('key', 'output_dir', 'label', '输出目录', 'type', 'string')
  ),
  10, @demo_user_id, NOW(), @demo_user_id, NOW()
);

INSERT INTO `ai_model_config`
(`id`, `model_type`, `model_code`, `model_name`, `is_default`, `is_enabled`, `config_json`, `doc_link`, `remark`, `sort`, `creator`, `create_date`, `updater`, `update_date`)
VALUES
(
  'LLM_DoubaoPro', 'LLM', 'DoubaoPro', '豆包 Pro（长文本）', 0, 1,
  JSON_OBJECT(
    'type', 'openai', 'base_url', @ark_base_url, 'model_name', 'doubao-seed-1-6-250615',
    'api_key', @ark_api_key, 'temperature', 0.6, 'max_tokens', 4096, 'is_slm', FALSE
  ),
  'https://www.volcengine.com/docs/82379',
  '长上下文场景备选，演示中不绑定到智能体。', 3, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'LLM_QwenPlus', 'LLM', 'QwenPlus', '通义千问 Plus', 0, 1,
  JSON_OBJECT(
    'type', 'openai', 'base_url', 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    'model_name', 'qwen-plus', 'api_key', '', 'temperature', 0.7, 'max_tokens', 2000, 'is_slm', FALSE
  ),
  'https://help.aliyun.com/zh/model-studio/',
  '阿里云百炼 OpenAI 兼容接入；演示环境未配置密钥。', 4, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'LLM_DeepSeekChat', 'LLM', 'DeepSeekChat', 'DeepSeek V3', 0, 1,
  JSON_OBJECT(
    'type', 'openai', 'base_url', 'https://api.deepseek.com', 'model_name', 'deepseek-chat',
    'api_key', '', 'temperature', 0.7, 'max_tokens', 2000, 'is_slm', FALSE
  ),
  'https://api-docs.deepseek.com/zh-cn/',
  '成本敏感场景备选；演示环境未配置密钥。', 5, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'LLM_GLM4Flash', 'LLM', 'GLM4Flash', '智谱 GLM-4-Flash', 0, 1,
  JSON_OBJECT(
    'type', 'openai', 'base_url', 'https://open.bigmodel.cn/api/paas/v4/',
    'model_name', 'glm-4-flash', 'api_key', '', 'temperature', 0.7, 'max_tokens', 1500, 'is_slm', TRUE
  ),
  'https://docs.bigmodel.cn/',
  '免费额度较大的轻量模型；演示环境未配置密钥。', 6, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'LLM_OllamaQwen', 'LLM', 'OllamaQwen', 'Ollama · Qwen2.5 7B（本地）', 0, 0,
  JSON_OBJECT(
    'type', 'ollama', 'base_url', 'http://127.0.0.1:11434', 'model_name', 'qwen2.5:7b'
  ),
  'https://github.com/ollama/ollama',
  '离线内网部署方案，演示时保持停用。', 7, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'VLLM_DoubaoVision', 'VLLM', 'DoubaoVision', '豆包视觉理解', 1, 1,
  JSON_OBJECT(
    'type', 'openai', 'base_url', @ark_base_url,
    'model_name', 'doubao-seed-1-6-vision-250815', 'api_key', @ark_api_key
  ),
  'https://www.volcengine.com/docs/82379',
  '摄像头画面识别，供 Vision 接口使用。', 1, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'ASR_FunASRLocal', 'ASR', 'FunASRLocal', 'FunASR 本地识别（SenseVoice）', 0, 1,
  JSON_OBJECT(
    'type', 'fun_local', 'model_dir', 'models/SenseVoiceSmall', 'output_dir', 'tmp/'
  ),
  'https://github.com/modelscope/FunASR',
  '断网兜底方案，模型随启动器自动下载。', 2, @demo_user_id, NOW(), @demo_user_id, NOW()
),
(
  'TTS_EdgeTTS', 'TTS', 'EdgeTTS', 'Edge 语音合成（免费）', 0, 1,
  JSON_OBJECT(
    'type', 'edge', 'voice', 'zh-CN-XiaoxiaoNeural', 'output_dir', 'tmp/'
  ),
  'https://github.com/rany2/edge-tts',
  '零成本兜底音色，音质与情感表达弱于 Seed-TTS。', 2, @demo_user_id, NOW(), @demo_user_id, NOW()
);

-- Edge TTS 的可选音色，让 TTS 音色管理弹窗在非豆包模型下也不为空。
INSERT INTO `ai_tts_voice`
(`id`, `tts_model_id`, `name`, `tts_voice`, `languages`, `voice_demo`, `remark`, `reference_audio`, `reference_text`, `sort`, `creator`, `create_date`, `updater`, `update_date`)
VALUES
('TTS_EdgeTTS_0001', 'TTS_EdgeTTS', '晓晓', 'zh-CN-XiaoxiaoNeural', '普通话', NULL, '温暖自然的女声，Edge 默认中文音色', NULL, NULL, 1, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_EdgeTTS_0002', 'TTS_EdgeTTS', '云希', 'zh-CN-YunxiNeural', '普通话', NULL, '活泼阳光的青年男声', NULL, NULL, 2, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_EdgeTTS_0003', 'TTS_EdgeTTS', '晓伊', 'zh-CN-XiaoyiNeural', '普通话', NULL, '偏少年感的女声，适合童趣场景', NULL, NULL, 3, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_EdgeTTS_0004', 'TTS_EdgeTTS', '云健', 'zh-CN-YunjianNeural', '普通话', NULL, '浑厚沉稳的男声，适合解说', NULL, NULL, 4, @demo_user_id, NOW(), @demo_user_id, NOW()),
('TTS_EdgeTTS_0005', 'TTS_EdgeTTS', '辽宁小北', 'zh-CN-liaoning-XiaobeiNeural', '东北话', NULL, '东北方言女声，方言演示用', NULL, NULL, 5, @demo_user_id, NOW(), @demo_user_id, NOW());
