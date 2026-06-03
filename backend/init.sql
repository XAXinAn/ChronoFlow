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
    verified_at DATETIME DEFAULT NULL,
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_phone (phone)
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
