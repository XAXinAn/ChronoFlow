package com.chronoflow.backend.mindflow.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 发送消息请求 — POST /api/v1/chat/message。
 */
@Data
public class ChatRequest {

    /** 会话ID（新会话可为null，后端自动创建） */
    private String sessionId;

    /** 用户消息内容 */
    @NotBlank(message = "消息内容不能为空")
    private String message;
}