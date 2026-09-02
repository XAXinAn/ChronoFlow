-- ChronoFlow 数据库初始化
-- docker-compose 首次启动时自动执行，MySQL 已通过 MYSQL_DATABASE 创建好库

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    nickname VARCHAR(100) NOT NULL DEFAULT '',
    nickname_updated_at DATETIME DEFAULT NULL,
    email VARCHAR(100) DEFAULT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    real_name_verified TINYINT DEFAULT 0,
    real_name VARCHAR(100) DEFAULT NULL,
    id_card_number VARCHAR(255) DEFAULT NULL COMMENT 'AES encrypted',
    student_id VARCHAR(32) DEFAULT NULL COMMENT '学号',
    verified_at DATETIME DEFAULT NULL,
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_phone (phone),
    INDEX idx_student_id (student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 群组表
CREATE TABLE IF NOT EXISTS `groups` (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    invite_code VARCHAR(20) NOT NULL UNIQUE,
    creator_id BIGINT NOT NULL,
    require_approval TINYINT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    parent_id VARCHAR(64) DEFAULT NULL,
    depth INT DEFAULT 0,
    INDEX idx_creator_id (creator_id),
    INDEX idx_invite_code (invite_code),
    INDEX idx_parent_id (parent_id),
    CONSTRAINT fk_groups_creator FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_groups_parent FOREIGN KEY (parent_id) REFERENCES `groups`(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 日程表
CREATE TABLE IF NOT EXISTS schedules (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    group_id VARCHAR(64) DEFAULT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    location VARCHAR(255),
    schedule_time DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_group_id (group_id),
    INDEX idx_schedule_time (schedule_time),
    INDEX idx_user_group_time (user_id, group_id, schedule_time),
    INDEX idx_group_schedule_time (group_id, schedule_time),
    CONSTRAINT fk_schedules_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_schedules_group FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 群组成员表
CREATE TABLE IF NOT EXISTS group_members (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    group_id VARCHAR(64) NOT NULL,
    user_id BIGINT NOT NULL,
    nickname VARCHAR(100) NOT NULL,
    is_admin TINYINT DEFAULT 0,
    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_group_id (group_id),
    INDEX idx_user_id (user_id),
    UNIQUE KEY uk_group_user (group_id, user_id),
    CONSTRAINT fk_members_group FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    CONSTRAINT fk_members_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 加群申请表
CREATE TABLE IF NOT EXISTS join_requests (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    group_id VARCHAR(64) NOT NULL,
    user_id BIGINT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_group_id (group_id),
    INDEX idx_user_id (user_id),
    INDEX idx_group_status (group_id, status),
    UNIQUE KEY uk_group_user_request (group_id, user_id),
    CONSTRAINT fk_requests_group FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    CONSTRAINT fk_requests_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 子群组创建申请表
CREATE TABLE IF NOT EXISTS subgroup_creation_requests (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    parent_group_id VARCHAR(64) NOT NULL,
    applicant_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_parent_group (parent_group_id),
    INDEX idx_applicant (applicant_id),
    CONSTRAINT fk_sub_request_group FOREIGN KEY (parent_group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
    CONSTRAINT fk_sub_request_user FOREIGN KEY (applicant_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 日程下发目标表
CREATE TABLE IF NOT EXISTS schedule_publish_targets (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    schedule_id BIGINT NOT NULL,
    target_group_id VARCHAR(64) NOT NULL,
    UNIQUE KEY uk_schedule_target (schedule_id, target_group_id),
    CONSTRAINT fk_pub_schedule FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE,
    CONSTRAINT fk_pub_group FOREIGN KEY (target_group_id) REFERENCES `groups`(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 管理后台账号表（独立于用户表）
CREATE TABLE IF NOT EXISTS admin_users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL COMMENT 'BCrypt加密',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 默认管理员账号 admin / admin123（首次部署后请修改密码）
INSERT IGNORE INTO admin_users (username, password) VALUES ('admin', '$2b$10$EuNpQTArxa5iCqXJ5o7y.O49MvR23rQH07GrifbRYztAZhIb8y1NO');

-- 用户反馈表
CREATE TABLE IF NOT EXISTS feedbacks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    type VARCHAR(20) NOT NULL COMMENT '反馈类型: bug / suggestion / other',
    content TEXT NOT NULL COMMENT '反馈正文 (10~500字)',
    image_urls TEXT COMMENT '图片URL列表 (JSON数组)',
    status VARCHAR(20) DEFAULT 'pending' COMMENT '处理状态: pending / processing / resolved / closed',
    admin_reply TEXT COMMENT '管理员回复',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_user_created (user_id, created_at),
    CONSTRAINT fk_feedback_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 成员级邀请码表（Excel 导入建群时为未注册成员生成）
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



-- ====================================================================
-- MindFlow 模块表（智流AI学习系统）
-- ====================================================================

-- 对话会话表
CREATE TABLE IF NOT EXISTS chat_session (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    session_id VARCHAR(64) NOT NULL UNIQUE,
    title VARCHAR(200) DEFAULT '新对话',
    status VARCHAR(20) DEFAULT 'ACTIVE' COMMENT 'ACTIVE / ARCHIVED',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_session_id (session_id),
    INDEX idx_user_updated (user_id, updated_at),
    CONSTRAINT fk_chat_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 对话消息表
CREATE TABLE IF NOT EXISTS chat_message (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    session_id VARCHAR(64) NOT NULL,
    role VARCHAR(20) NOT NULL COMMENT 'user / assistant / system',
    content TEXT NOT NULL COMMENT '消息内容（Markdown格式）',
    message_type VARCHAR(30) DEFAULT 'TEXT' COMMENT 'TEXT / PROFILE_CARD / RESOURCE_CARD / DIAGRAM / ERROR',
    metadata TEXT COMMENT '附加元数据（JSON格式）',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_session_id (session_id),
    INDEX idx_session_time (session_id, created_at),
    CONSTRAINT fk_chat_message_session FOREIGN KEY (session_id) REFERENCES chat_session(session_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 学习资源表（5类资源：DOC / MINDMAP / QUIZ / READING / CODE）
CREATE TABLE IF NOT EXISTS learning_resource (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    session_id VARCHAR(64),
    resource_type VARCHAR(20) NOT NULL COMMENT 'DOC / MINDMAP / QUIZ / READING / CODE',
    title VARCHAR(200) NOT NULL,
    file_key VARCHAR(500) NULL COMMENT 'MinIO object key (resources/{userId}/{resourceType}/{uuid}.md)',
    file_size BIGINT NULL COMMENT 'File content size in bytes',
    content LONGTEXT NOT NULL COMMENT '资源内容（Markdown / JSON）',
    metadata TEXT COMMENT '附加元数据（JSON格式）',
    confidence_score DECIMAL(3,2) DEFAULT 0.00 COMMENT 'AI生成置信度 0.00~1.00',
    reviewed TINYINT(1) DEFAULT 0 COMMENT '是否通过内容审核',
    version INT DEFAULT 1 COMMENT '乐观锁版本号',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_session_id (session_id),
    INDEX idx_type (resource_type),
    INDEX idx_user_created (user_id, created_at),
    INDEX idx_user_type (user_id, resource_type),
    INDEX idx_file_key (file_key),
    CONSTRAINT fk_resource_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 六维学习画像表
CREATE TABLE IF NOT EXISTS student_profile (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    knowledge_base TEXT COMMENT '知识基础',
    cognitive_style VARCHAR(20) COMMENT '认知风格：visual / verbal / logical / hands-on',
    weak_points TEXT COMMENT '薄弱知识点',
    pace_preference VARCHAR(15) COMMENT '学习节奏：slow_steady / normal / fast_paced',
    interests TEXT COMMENT '学习兴趣方向',
    peak_hours VARCHAR(50) COMMENT '高效学习时段，如 9:00-12:00',
    error_types TEXT COMMENT '易错类型',
    profile_version TINYINT UNSIGNED DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_profile_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;