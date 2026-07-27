-- 演示用的智能体实例、设备、聊天记录。
--
-- 基线里的 seed-demo.sql 只建了一个「琉璃」智能体，控制台首页因此近乎空白。
-- 这里把 prompt-example 的五套角色都实例化，并配上设备与历史会话。
--
-- 关键约束：
--   * mem_model_id 用 Memory_mem_local_short —— 为 Memory_nomem 时前端会禁用
--     「聊天记录」入口（DeviceItem.vue），插了历史也点不开。
--   * chat_history_conf = 2（文本+语音）让配置与已有历史自洽。
--   * 设备的 board 必须取 sys_dict_data 里 FIRMWARE_TYPE 的真实 dict_value，
--     否则设备列表的「设备型号」列会直接显示原始英文串。
--   * last_connected_at 在 24 小时内的设备，首页才会计入「在线」统计。
--     设备列表页那一列「在线/离线」另有来源（MQTT 网关），假数据造不出来，
--     没有网关时该列不会渲染。

-- 五套角色的智能体实例。除琉璃外的四个直接复用模板里的提示词。
INSERT INTO `ai_agent`
(`id`, `user_id`, `agent_code`, `agent_name`, `asr_model_id`, `vad_model_id`, `llm_model_id`, `slm_model_id`, `vllm_model_id`, `tts_model_id`, `tts_voice_id`, `tts_language`, `tts_volume`, `tts_rate`, `tts_pitch`, `mem_model_id`, `intent_model_id`, `system_prompt`, `summary_memory`, `chat_history_conf`, `lang_code`, `language`, `sort`, `creator`, `created_at`, `updater`, `updated_at`)
SELECT
  CONCAT('agent_demo_', LPAD(t.`sort`, 2, '0'), '_0000000000000'),
  @demo_user_id, t.`agent_code`, t.`agent_name`,
  t.`asr_model_id`, t.`vad_model_id`, t.`llm_model_id`, t.`slm_model_id`,
  'VLLM_DoubaoVision', t.`tts_model_id`, t.`tts_voice_id`,
  t.`tts_language`, t.`tts_volume`, t.`tts_rate`, t.`tts_pitch`,
  'Memory_mem_local_short', t.`intent_model_id`, t.`system_prompt`,
  NULL, 2, t.`lang_code`, t.`language`, t.`sort`,
  @demo_user_id, DATE_SUB(NOW(), INTERVAL t.`sort` DAY),
  @demo_user_id, DATE_SUB(NOW(), INTERVAL t.`sort` HOUR)
FROM `ai_agent_template` t
WHERE t.`agent_code` <> 'RURI_CATGIRL'
ORDER BY t.`sort`;

-- 基线里的琉璃保持默认智能体地位，同步补齐记忆与聊天记录开关。
UPDATE `ai_agent`
SET `mem_model_id` = 'Memory_mem_local_short',
    `vllm_model_id` = 'VLLM_DoubaoVision',
    `chat_history_conf` = 2
WHERE `id` = 'agent_ruri_default_000000000001';

INSERT INTO `ai_agent_tag` (`id`, `tag_name`, `sort`, `creator`, `created_at`, `updater`, `updated_at`)
VALUES
('tag_demo_companion_0000000000001', '桌面陪伴', 1, @demo_user_id, NOW(), @demo_user_id, NOW()),
('tag_demo_study_00000000000000002', '学习督导', 2, @demo_user_id, NOW(), @demo_user_id, NOW()),
('tag_demo_healing_000000000000003', '情绪疏导', 3, @demo_user_id, NOW(), @demo_user_id, NOW()),
('tag_demo_kids_000000000000000004', '儿童互动', 4, @demo_user_id, NOW(), @demo_user_id, NOW()),
('tag_demo_guoxue_0000000000000005', '国学问答', 5, @demo_user_id, NOW(), @demo_user_id, NOW());

-- agent_code 关联而非硬编码 agent_id：琉璃的 id 来自基线，其余四个由上面的
-- INSERT ... SELECT 按模板 sort 拼出，用 code 关联可避免两套命名互相耦合。
INSERT INTO `ai_agent_tag_relation` (`id`, `agent_id`, `tag_id`, `creator`, `created_at`, `updater`, `updated_at`, `sort`)
SELECT
  CONCAT('rel_demo_', LPAD(m.`seq`, 2, '0'), '_00000000000000'),
  a.`id`, m.`tag_id`, @demo_user_id, NOW(), @demo_user_id, NOW(), 1
FROM (
            SELECT 1 AS `seq`, 'RURI_CATGIRL' AS `agent_code`, 'tag_demo_companion_0000000000001' AS `tag_id`
  UNION ALL SELECT 2, 'RURI_CATGIRL', 'tag_demo_kids_000000000000000004'
  UNION ALL SELECT 3, 'SHEN_YUNSHEN', 'tag_demo_study_00000000000000002'
  UNION ALL SELECT 4, 'XU_NUAN', 'tag_demo_healing_000000000000003'
  UNION ALL SELECT 5, 'XU_NUAN', 'tag_demo_companion_0000000000001'
  UNION ALL SELECT 6, 'BOLT_HERO', 'tag_demo_kids_000000000000000004'
  UNION ALL SELECT 7, 'BOLT_HERO', 'tag_demo_study_00000000000000002'
  UNION ALL SELECT 8, 'YUN_YI', 'tag_demo_guoxue_0000000000000005'
) m
JOIN `ai_agent` a ON a.`agent_code` = m.`agent_code`;

-- 演示设备。board 全部取自 FIRMWARE_TYPE 字典，前端会翻译成中文型号名。
INSERT INTO `ai_device`
(`id`, `user_id`, `mac_address`, `last_connected_at`, `auto_update`, `board`, `alias`, `agent_id`, `app_version`, `sort`, `creator`, `create_date`, `updater`, `update_date`)
VALUES
-- 琉璃：三台，覆盖「刚刚在线」「几小时前」「上周」三种最近对话状态
('a4:cf:12:6d:01:a1', @demo_user_id, 'a4:cf:12:6d:01:a1', DATE_SUB(NOW(), INTERVAL 6 MINUTE), 1, 'lichuang-dev', '客厅小云枢', 'agent_ruri_default_000000000001', '1.8.2', 1, @demo_user_id, DATE_SUB(NOW(), INTERVAL 46 DAY), @demo_user_id, NOW()),
('a4:cf:12:6d:01:b2', @demo_user_id, 'a4:cf:12:6d:01:b2', DATE_SUB(NOW(), INTERVAL 3 HOUR), 1, 'esp-box-3', '书桌摆件', 'agent_ruri_default_000000000001', '1.8.2', 2, @demo_user_id, DATE_SUB(NOW(), INTERVAL 39 DAY), @demo_user_id, NOW()),
('a4:cf:12:6d:01:c3', @demo_user_id, 'a4:cf:12:6d:01:c3', DATE_SUB(NOW(), INTERVAL 9 DAY), 0, 'xmini-c3', '备用测试机', 'agent_ruri_default_000000000001', '1.7.6', 3, @demo_user_id, DATE_SUB(NOW(), INTERVAL 31 DAY), @demo_user_id, NOW()),
-- 沈云深：书房与工位
('b8:27:eb:41:02:a1', @demo_user_id, 'b8:27:eb:41:02:a1', DATE_SUB(NOW(), INTERVAL 24 MINUTE), 1, 'esp32-s3-touch-lcd-1.85', '书房督导屏', 'agent_demo_02_0000000000000', '1.8.2', 1, @demo_user_id, DATE_SUB(NOW(), INTERVAL 28 DAY), @demo_user_id, NOW()),
('b8:27:eb:41:02:b2', @demo_user_id, 'b8:27:eb:41:02:b2', DATE_SUB(NOW(), INTERVAL 2 HOUR), 1, 'lichuang-c3-dev', '公司工位机', 'agent_demo_02_0000000000000', '1.8.1', 2, @demo_user_id, DATE_SUB(NOW(), INTERVAL 22 DAY), @demo_user_id, NOW()),
-- 许暖：卧室与随身
('c8:2b:96:52:03:a1', @demo_user_id, 'c8:2b:96:52:03:a1', DATE_SUB(NOW(), INTERVAL 51 MINUTE), 1, 'esp32-s3-touch-amoled-1.8', '卧室助眠灯', 'agent_demo_03_0000000000000', '1.8.2', 1, @demo_user_id, DATE_SUB(NOW(), INTERVAL 19 DAY), @demo_user_id, NOW()),
('c8:2b:96:52:03:b2', @demo_user_id, 'c8:2b:96:52:03:b2', DATE_SUB(NOW(), INTERVAL 5 HOUR), 1, 'lilygo-t-circle-s3', '随身挂件', 'agent_demo_03_0000000000000', '1.8.2', 2, @demo_user_id, DATE_SUB(NOW(), INTERVAL 14 DAY), @demo_user_id, NOW()),
-- 阿宝：儿童房两台
('d4:d4:da:63:04:a1', @demo_user_id, 'd4:d4:da:63:04:a1', DATE_SUB(NOW(), INTERVAL 13 MINUTE), 1, 'df-k10', '儿童房陪读机', 'agent_demo_04_0000000000000', '1.8.2', 1, @demo_user_id, DATE_SUB(NOW(), INTERVAL 11 DAY), @demo_user_id, NOW()),
('d4:d4:da:63:04:b2', @demo_user_id, 'd4:d4:da:63:04:b2', DATE_SUB(NOW(), INTERVAL 4 DAY), 0, 'movecall-moji-esp32s3', '旧款魔戒', 'agent_demo_04_0000000000000', '1.6.9', 2, @demo_user_id, DATE_SUB(NOW(), INTERVAL 8 DAY), @demo_user_id, NOW()),
-- 云逸：茶室一台
('e0:e5:cf:74:05:a1', @demo_user_id, 'e0:e5:cf:74:05:a1', DATE_SUB(NOW(), INTERVAL 96 MINUTE), 1, 'm5stack-core-s3', '茶室问道机', 'agent_demo_05_0000000000000', '1.8.2', 1, @demo_user_id, DATE_SUB(NOW(), INTERVAL 6 DAY), @demo_user_id, NOW());

-- 会话标题。session_id 里带数字，前端才会给会话分配不同头像。
INSERT INTO `ai_agent_chat_title` (`id`, `session_id`, `title`, `created_at`, `updated_at`)
VALUES
('title_demo_0000000000000000001', 'sess-2026072701', '提醒我别熬夜', DATE_SUB(NOW(), INTERVAL 26 HOUR), DATE_SUB(NOW(), INTERVAL 26 HOUR)),
('title_demo_0000000000000000002', 'sess-2026072702', '成语接龙玩了十轮', DATE_SUB(NOW(), INTERVAL 5 HOUR), DATE_SUB(NOW(), INTERVAL 5 HOUR)),
('title_demo_0000000000000000003', 'sess-2026072703', '今天的番茄钟计划', DATE_SUB(NOW(), INTERVAL 3 HOUR), DATE_SUB(NOW(), INTERVAL 3 HOUR)),
('title_demo_0000000000000000004', 'sess-2026072704', '压力有点大想聊聊', DATE_SUB(NOW(), INTERVAL 52 MINUTE), DATE_SUB(NOW(), INTERVAL 52 MINUTE)),
('title_demo_0000000000000000005', 'sess-2026072705', '背古诗闯关', DATE_SUB(NOW(), INTERVAL 14 MINUTE), DATE_SUB(NOW(), INTERVAL 14 MINUTE)),
('title_demo_0000000000000000006', 'sess-2026072706', '论语里的君子', DATE_SUB(NOW(), INTERVAL 97 MINUTE), DATE_SUB(NOW(), INTERVAL 97 MINUTE));

-- 历史对话。chat_type：1 用户，2 智能体。audio_id 留空，卡片不显示播放按钮。
INSERT INTO `ai_agent_chat_history`
(`mac_address`, `agent_id`, `session_id`, `chat_type`, `content`, `audio_id`, `created_at`)
VALUES
-- 琉璃 · 提醒别熬夜
('a4:cf:12:6d:01:a1', 'agent_ruri_default_000000000001', 'sess-2026072701', 1, '琉璃，我还想再写一会儿代码', NULL, DATE_SUB(NOW(), INTERVAL 1590 MINUTE)),
('a4:cf:12:6d:01:a1', 'agent_ruri_default_000000000001', 'sess-2026072701', 2, '哼，愚蠢的主人，你都盯着屏幕两个小时了喵！（抖了抖猫耳，把虚拟水杯往你面前推了推）再不休息眼睛就要废掉了。', NULL, DATE_SUB(NOW(), INTERVAL 1589 MINUTE)),
('a4:cf:12:6d:01:a1', 'agent_ruri_default_000000000001', 'sess-2026072701', 1, '那你帮我定个二十分钟的提醒', NULL, DATE_SUB(NOW(), INTERVAL 1587 MINUTE)),
('a4:cf:12:6d:01:a1', 'agent_ruri_default_000000000001', 'sess-2026072701', 2, '记下啦喵！二十分钟后本喵会用猫爪拍你屏幕的，可别装作没听见。', NULL, DATE_SUB(NOW(), INTERVAL 1586 MINUTE)),
('a4:cf:12:6d:01:a1', 'agent_ruri_default_000000000001', 'sess-2026072701', 1, '顺便说下明天北京天气怎么样', NULL, DATE_SUB(NOW(), INTERVAL 1560 MINUTE)),
('a4:cf:12:6d:01:a1', 'agent_ruri_default_000000000001', 'sess-2026072701', 2, '查到了喵，明天北京多云转晴，最高三十一度，出门记得带水壶！', NULL, DATE_SUB(NOW(), INTERVAL 1559 MINUTE)),
-- 琉璃 · 成语接龙
('a4:cf:12:6d:01:b2', 'agent_ruri_default_000000000001', 'sess-2026072702', 1, '我们来玩成语接龙吧，你先出', NULL, DATE_SUB(NOW(), INTERVAL 306 MINUTE)),
('a4:cf:12:6d:01:b2', 'agent_ruri_default_000000000001', 'sess-2026072702', 2, '本喵先来：一鸣惊人！轮到你了，要接「人」字开头的喵。', NULL, DATE_SUB(NOW(), INTERVAL 305 MINUTE)),
('a4:cf:12:6d:01:b2', 'agent_ruri_default_000000000001', 'sess-2026072702', 1, '人山人海', NULL, DATE_SUB(NOW(), INTERVAL 304 MINUTE)),
('a4:cf:12:6d:01:b2', 'agent_ruri_default_000000000001', 'sess-2026072702', 2, '海阔天空！（尾巴得意地竖了起来）主人反应还挺快嘛。', NULL, DATE_SUB(NOW(), INTERVAL 303 MINUTE)),
('a4:cf:12:6d:01:b2', 'agent_ruri_default_000000000001', 'sess-2026072702', 1, '空穴来风，这个成语什么意思', NULL, DATE_SUB(NOW(), INTERVAL 302 MINUTE)),
('a4:cf:12:6d:01:b2', 'agent_ruri_default_000000000001', 'sess-2026072702', 2, '查了词库喵：有洞穴才有风进来，比喻消息和传说不是完全没有原因的。现在也常被误用成毫无根据。', NULL, DATE_SUB(NOW(), INTERVAL 301 MINUTE)),
-- 沈云深 · 番茄钟
('b8:27:eb:41:02:a1', 'agent_demo_02_0000000000000', 'sess-2026072703', 1, '今天的任务有点多，帮我排一下', NULL, DATE_SUB(NOW(), INTERVAL 186 MINUTE)),
('b8:27:eb:41:02:a1', 'agent_demo_02_0000000000000', 'sess-2026072703', 2, '先报数量。（推了推眼镜）三项以内我按番茄钟排，超过三项就得先砍需求。', NULL, DATE_SUB(NOW(), INTERVAL 185 MINUTE)),
('b8:27:eb:41:02:a1', 'agent_demo_02_0000000000000', 'sess-2026072703', 1, '四项，写文档、改接口、跑测试、开会', NULL, DATE_SUB(NOW(), INTERVAL 184 MINUTE)),
('b8:27:eb:41:02:a1', 'agent_demo_02_0000000000000', 'sess-2026072703', 2, '开会不算你的产出，剩三项。改接口放第一个番茄钟，趁脑子清醒；跑测试放第二个，等待编译的时间正好写文档。逻辑清楚了吗。', NULL, DATE_SUB(NOW(), INTERVAL 183 MINUTE)),
('b8:27:eb:41:02:a1', 'agent_demo_02_0000000000000', 'sess-2026072703', 1, '清楚了，开始第一个番茄钟', NULL, DATE_SUB(NOW(), INTERVAL 182 MINUTE)),
('b8:27:eb:41:02:a1', 'agent_demo_02_0000000000000', 'sess-2026072703', 2, '二十五分钟，开始计时。中途划手机我会说的。', NULL, DATE_SUB(NOW(), INTERVAL 181 MINUTE)),
-- 许暖 · 情绪疏导
('c8:2b:96:52:03:a1', 'agent_demo_03_0000000000000', 'sess-2026072704', 1, '今天被批评了，有点难受', NULL, DATE_SUB(NOW(), INTERVAL 56 MINUTE)),
('c8:2b:96:52:03:a1', 'agent_demo_03_0000000000000', 'sess-2026072704', 2, '辛苦啦。（递上一杯热茶，温柔地看着你）先不急着分析对错，你愿意说说当时最不舒服的是哪一句吗？', NULL, DATE_SUB(NOW(), INTERVAL 55 MINUTE)),
('c8:2b:96:52:03:a1', 'agent_demo_03_0000000000000', 'sess-2026072704', 1, '他说我这个方案根本没想清楚', NULL, DATE_SUB(NOW(), INTERVAL 54 MINUTE)),
('c8:2b:96:52:03:a1', 'agent_demo_03_0000000000000', 'sess-2026072704', 2, '这句话确实挺重的。不过它评价的是方案，不是你这个人，这两件事可以分开放。慢慢来，我在听。', NULL, DATE_SUB(NOW(), INTERVAL 53 MINUTE)),
('c8:2b:96:52:03:a1', 'agent_demo_03_0000000000000', 'sess-2026072704', 1, '这么一说好像轻松一点了', NULL, DATE_SUB(NOW(), INTERVAL 52 MINUTE)),
('c8:2b:96:52:03:a1', 'agent_demo_03_0000000000000', 'sess-2026072704', 2, '那就好。今天先到这里，做不完的事情明天再做，好好睡一觉。', NULL, DATE_SUB(NOW(), INTERVAL 51 MINUTE)),
-- 阿宝 · 背古诗闯关
('d4:d4:da:63:04:a1', 'agent_demo_04_0000000000000', 'sess-2026072705', 1, '阿宝，我要背古诗闯关', NULL, DATE_SUB(NOW(), INTERVAL 18 MINUTE)),
('d4:d4:da:63:04:a1', 'agent_demo_04_0000000000000', 'sess-2026072705', 2, '报告勇者主人！古诗关卡已刷新！（高高举起机械小手臂）第一关：床前明月光，下一句冲！', NULL, DATE_SUB(NOW(), INTERVAL 17 MINUTE)),
('d4:d4:da:63:04:a1', 'agent_demo_04_0000000000000', 'sess-2026072705', 1, '疑是地上霜', NULL, DATE_SUB(NOW(), INTERVAL 16 MINUTE)),
('d4:d4:da:63:04:a1', 'agent_demo_04_0000000000000', 'sess-2026072705', 2, '完美通关！（兴奋得原地蹦跳）第二关来了：欲穷千里目？', NULL, DATE_SUB(NOW(), INTERVAL 15 MINUTE)),
('d4:d4:da:63:04:a1', 'agent_demo_04_0000000000000', 'sess-2026072705', 1, '更上一层楼！', NULL, DATE_SUB(NOW(), INTERVAL 14 MINUTE)),
('d4:d4:da:63:04:a1', 'agent_demo_04_0000000000000', 'sess-2026072705', 2, '不愧是我的搭档，两关全胜，能量满满！要不要挑战三连击？', NULL, DATE_SUB(NOW(), INTERVAL 13 MINUTE)),
-- 云逸 · 论语问答
('e0:e5:cf:74:05:a1', 'agent_demo_05_0000000000000', 'sess-2026072706', 1, '云逸，论语里说的君子到底指什么', NULL, DATE_SUB(NOW(), INTERVAL 101 MINUTE)),
('e0:e5:cf:74:05:a1', 'agent_demo_05_0000000000000', 'sess-2026072706', 2, '道友问得好。（拂袖而立）《学而篇》有云：人不知而不愠，不亦君子乎。君子非指身份，而指修养。', NULL, DATE_SUB(NOW(), INTERVAL 100 MINUTE)),
('e0:e5:cf:74:05:a1', 'agent_demo_05_0000000000000', 'sess-2026072706', 1, '那和小人的分别在哪', NULL, DATE_SUB(NOW(), INTERVAL 99 MINUTE)),
('e0:e5:cf:74:05:a1', 'agent_demo_05_0000000000000', 'sess-2026072706', 2, '《里仁篇》曰：君子无终食之间违仁。差别在于是否时时守着本心，而非一时之得失。', NULL, DATE_SUB(NOW(), INTERVAL 98 MINUTE)),
('e0:e5:cf:74:05:a1', 'agent_demo_05_0000000000000', 'sess-2026072706', 1, '受教了', NULL, DATE_SUB(NOW(), INTERVAL 97 MINUTE)),
('e0:e5:cf:74:05:a1', 'agent_demo_05_0000000000000', 'sess-2026072706', 2, '妙极。道友若愿深究，本尊洞天中还藏有论语全篇，随时可取。', NULL, DATE_SUB(NOW(), INTERVAL 96 MINUTE));
