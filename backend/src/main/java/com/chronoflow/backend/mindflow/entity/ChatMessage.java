package com.chronoflow.backend.mindflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**对话消息实体*/
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("chat_message")
public class ChatMessage {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 所属会话ID */
    @TableField("session_id")
    private String sessionId;

    /** 消息角色：user / assistant / system */
    @TableField("role")
    private String role;

    /** 消息内容（Markdown格式） */
    @TableField("content")
    private String content;

    /** 消息类型：TEXT / PROFILE_CARD / RESOURCE_CARD / DIAGRAM / ERROR */
    @TableField("message_type")
    private String messageType;

    /** 附加元数据（JSON格式，如资源ID、画像数据、Mermaid图表等） */
    @TableField("metadata")
    private String metadata;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}