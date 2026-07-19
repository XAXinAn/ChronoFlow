package com.chronoflow.backend.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**用户反馈实体*/
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("feedbacks")
public class Feedback {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 提交反馈的用户 ID */
    @TableField("user_id")
    private Long userId;

    /**反馈类型*/
    @TableField("type")
    private String type;

    /** 反馈正文（10~500 字） */
    @TableField("content")
    private String content;

    /**图片 URL 列表*/
    @TableField("image_urls")
    private String imageUrls;

    /**处理状态*/
    @TableField("status")
    private String status;

    /** 管理员回复内容 */
    @TableField("admin_reply")
    private String adminReply;

    /** 提交时间 */
    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    /** 最近更新时间（管理员回复 / 状态变更时自动更新） */
    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}