package com.chronoflow.backend.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("messages")
public class Message {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 发送者ID（管理员发起消息时为管理员ID，用户回复时为用户ID） */
    @TableField("sender_id")
    private Long senderId;

    /** 接收者ID */
    @TableField("receiver_id")
    private Long receiverId;

    /** 消息标题 */
    @TableField("title")
    private String title;

    /** 消息内容 */
    @TableField("content")
    private String content;

    /** 父消息ID，回复时指向原始消息 */
    @TableField("parent_id")
    private Long parentId;

    /** 类型：admin_message(管理员消息) / feedback_notify(反馈回复通知) / user_reply(用户回复) */
    @TableField("type")
    private String type;

    /** 是否已读 */
    @TableField("is_read")
    private Boolean isRead;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
