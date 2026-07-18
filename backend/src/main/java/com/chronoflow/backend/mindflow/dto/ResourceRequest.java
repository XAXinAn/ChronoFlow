package com.chronoflow.backend.mindflow.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 资源生成请求 — POST /api/v1/resources/generate。
 */
@Data
public class ResourceRequest {

    /** 知识点描述（如"机器学习决策树"） */
    @NotBlank(message = "知识点描述不能为空")
    private String topic;

    /** 指定生成资源类型（可选，不指定则生成全部5类） */
    private String resourceType;

    /** 会话ID（用于关联上下文） */
    private String sessionId;
}