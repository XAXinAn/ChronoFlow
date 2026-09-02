-- V1.3.0 增量迁移：users 表新增 student_id 列
-- 用于 Excel 导入建群时按学号匹配已注册用户

ALTER TABLE users ADD COLUMN student_id VARCHAR(32) DEFAULT NULL COMMENT '学号' AFTER id_card_number;
CREATE INDEX idx_student_id ON users(student_id);
