-- V1.3.0 增量迁移：新增成员级邀请码表
-- 用于 Excel 导入建群时为未注册成员生成定向邀请码

CREATE TABLE IF NOT EXISTS member_invite_codes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    group_id VARCHAR(64) NOT NULL,
    creator_id BIGINT NOT NULL,
    masked_name VARCHAR(50) DEFAULT NULL,
    masked_student_id VARCHAR(32) DEFAULT NULL,
    masked_email VARCHAR(100) DEFAULT NULL,
    masked_phone VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    expires_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    consumed_at DATETIME DEFAULT NULL,
    INDEX idx_code (code),
    INDEX idx_group_id (group_id),
    INDEX idx_creator_id (creator_id),
    INDEX idx_status (status),
    CONSTRAINT fk_member_invite_group FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    CONSTRAINT fk_member_invite_creator FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
