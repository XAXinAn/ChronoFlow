package com.chronoflow.backend.mindflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 学习资源实体 — 存储AI生成的五类学习资源。
 * resource_type: DOC(讲解文档) / MINDMAP(思维导图) / QUIZ(练习题) / READING(拓展材料) / CODE(代码案例)
 *
 * 修复（vs HEAD）：
 * - 加 version 字段（乐观锁版本号，防止并发更新冲突）
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("learning_resource")
public class LearningResource {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 资源所属用户 */
    @TableField("user_id")
    private Long userId;

    /** 生成该资源的会话ID */
    @TableField("session_id")
    private String sessionId;

    /** 资源类型：DOC / MINDMAP / QUIZ / READING / CODE */
    @TableField("resource_type")
    private String resourceType;

    /** 资源标题（知识点名称） */
    @TableField("title")
    private String title;

    /** MinIO object key（如 resources/{userId}/{resourceType}/{uuid}.md） */
    @TableField("file_key")
    private String fileKey;

    /** 文件大小（字节），上传 MinIO 后记录 */
    @TableField("file_size")
    private Long fileSize;

    /** 资源内容（Markdown / JSON）。新资源存 MinIO，本字段为 NULL；旧资源仍存 MySQL */
    @TableField("content")
    private String content;

    /** 附加元数据（JSON格式，如知识点、难度等级等） */
    @TableField("metadata")
    private String metadata;

    /** AI生成置信度 (0.00~1.00) */
    @TableField("confidence_score")
    private BigDecimal confidenceScore;

    /** 是否已通过内容审核 */
    @TableField("reviewed")
    private Boolean reviewed;

    /**
     * 乐观锁版本号 — 每次更新 +1（MyBatis-Plus @Version 注解自动管理）
     * 防止并发用户/Agent 同时修改同一资源导致数据错乱
     */
    @Version
    @TableField("version")
    private Integer version;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}