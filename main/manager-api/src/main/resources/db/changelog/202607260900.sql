-- 将默认角色归属到现有演示管理员，确保初始化后登录账号可以直接看到默认智能体。
SET @default_agent_user_id = COALESCE(
    (
        SELECT `id`
        FROM `sys_user`
        ORDER BY (`username` = 'demo') DESC, `super_admin` DESC, `create_date`
        LIMIT 1
    ),
    1
);

UPDATE `ai_agent`
SET `user_id` = @default_agent_user_id,
    `creator` = @default_agent_user_id,
    `updater` = @default_agent_user_id
WHERE `id` = 'agent_ruri_default_000000000001'
   OR `agent_code` = 'RURI_CATGIRL';

UPDATE `ai_agent_template`
SET `creator` = @default_agent_user_id,
    `updater` = @default_agent_user_id
WHERE `id` IN (
    'tpl_ruri_catgirl_00000000000001',
    'tpl_shen_yunshen_0000000000002',
    'tpl_xu_nuan_000000000000000003',
    'tpl_bolt_hero_0000000000000004',
    'tpl_yun_yi_000000000000000005'
);
