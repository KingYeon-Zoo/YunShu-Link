-- 智能体模板增加独立的小参数模型，避免新建智能体错误复用主语言模型。
SET @col_exists = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'ai_agent_template'
      AND COLUMN_NAME = 'slm_model_id'
);
SET @sql = IF(
    @col_exists = 0,
    'ALTER TABLE `ai_agent_template` ADD COLUMN `slm_model_id` VARCHAR(32) NULL COMMENT ''小参数模型ID'' AFTER `llm_model_id`',
    'SELECT ''Column slm_model_id already exists'' AS msg'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
