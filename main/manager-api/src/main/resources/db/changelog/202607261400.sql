-- 注册豆包端到端实时语音大模型（RealtimeAPI）。
-- 该模型语音进、语音出，占用 ASR 槽位并在服务端内部完成识别、对话与合成；
-- 选用后 LLM/TTS 不再参与实时链路，但记忆总结与聊天标题仍会用到 LLM。

delete from `ai_model_provider` where id = 'SYSTEM_ASR_DoubaoRealtime';
INSERT INTO `ai_model_provider` (`id`, `model_type`, `provider_code`, `name`, `fields`, `sort`, `creator`, `create_date`, `updater`, `update_date`) VALUES
('SYSTEM_ASR_DoubaoRealtime', 'ASR', 'doubao_realtime', '豆包端到端实时语音大模型', '[{"key":"appid","label":"应用ID","type":"string"},{"key":"access_key","label":"访问令牌","type":"password"},{"key":"model","label":"模型版本(1.2.1.1=O2.0 / 2.2.0.0=SC2.0)","type":"string"},{"key":"speaker","label":"音色","type":"string"},{"key":"bot_name","label":"角色名称(仅O版本)","type":"string"},{"key":"system_role","label":"背景人设(仅O版本，留空用智能体提示词)","type":"string"},{"key":"speaking_style","label":"对话风格(仅O版本)","type":"string"},{"key":"character_manifest","label":"角色描述(仅SC版本，留空用智能体提示词)","type":"string"},{"key":"end_smooth_window_ms","label":"说话停止判定(ms)","type":"number"},{"key":"input_mod","label":"输入模式(keep_alive/push_to_talk)","type":"string"},{"key":"enable_websearch","label":"开启内置联网搜索","type":"boolean"},{"key":"websearch_type","label":"搜索类型(web/web_summary/web_agent)","type":"string"},{"key":"websearch_api_key","label":"融合搜索密钥","type":"password"},{"key":"websearch_bot_id","label":"搜索Agent ID(web_agent必填)","type":"string"},{"key":"websearch_result_count","label":"搜索结果条数(≤10)","type":"number"},{"key":"enable_tools","label":"开启工具调用","type":"boolean"},{"key":"tool_decision_timeout","label":"工具判定超时(秒)","type":"number"},{"key":"enable_music","label":"开启唱歌能力(仅O2.0)","type":"boolean"},{"key":"enable_user_query_exit","label":"识别用户退出意图","type":"boolean"},{"key":"output_dir","label":"输出目录","type":"string"}]', 19, 1, NOW(), 1, NOW());

delete from `ai_model_config` where id = 'ASR_DoubaoRealtime';
INSERT INTO `ai_model_config` VALUES ('ASR_DoubaoRealtime', 'ASR', 'DoubaoRealtime', '豆包端到端实时语音大模型', 0, 1, '{"type": "doubao_realtime", "appid": "", "access_key": "", "model": "1.2.1.1", "speaker": "zh_female_vv_jupiter_bigtts", "bot_name": "", "system_role": "", "speaking_style": "", "character_manifest": "", "end_smooth_window_ms": 1200, "input_mod": "keep_alive", "enable_websearch": false, "websearch_type": "web", "websearch_api_key": "", "websearch_bot_id": "", "websearch_result_count": 5, "enable_tools": true, "tool_decision_timeout": 2.5, "enable_music": false, "enable_user_query_exit": true, "output_dir": "tmp/"}', 'https://www.volcengine.com/docs/6561/1594356', '豆包端到端实时语音大模型配置说明：
1、语音直接进、语音直接出，延迟显著低于 ASR+LLM+TTS 串联链路
2、开通地址：https://console.volcengine.com/speech/service/10011
3、模型版本必须与音色匹配，配错会报 ClientError:InvalidSpeaker
   O2.0（1.2.1.1）：精品音色 zh_female_vv_jupiter_bigtts、zh_female_xiaohe_jupiter_bigtts、
                    zh_male_yunzhou_jupiter_bigtts、zh_male_xiaotian_jupiter_bigtts，支持唱歌
   SC2.0（2.2.0.0）：角色扮演，音色以 saturn_ 或 S_ 开头，官方 _tob 音色的角色描述已内置
4、人设字段按版本区分：O 版本用角色名称/背景人设/对话风格，SC 版本用角色描述；
   留空时自动使用所属智能体的提示词
5、联网搜索需在火山控制台开通「融合信息搜索」，web_agent 类型还需填写搜索 Agent ID
6、工具调用由旁路 LLM 判定后注入模型总结播报，音色与人设保持一致；
   判定超时会直接播放模型自己的回复，不会造成明显静默
7、选用本模型后 TTS 配置不参与实时链路，记忆与知识库仍照常生效', 22, NULL, NULL, NULL, NULL);
