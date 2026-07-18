package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.entity.StudentProfile;
import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * Agent执行上下文 — 封装Agent执行所需的全部输入信息。
 */
@Data
@Builder
public class AgentContext {

    /** 当前用户ID */
    private Long userId;

    /** 会话ID */
    private String sessionId;

    /** 用户原始输入消息 */
    private String userMessage;

    /** 意图分类标签（如 RESOURCE_GEN） */
    private String intentLabel;

    /** 意图分类置信度 (0.0~1.0) */
    private double confidence;

    /** 用户学习画像（可为null） */
    private StudentProfile profile;

    /** 最近N轮会话历史（用于上下文理解） */
    private List<String> conversationHistory;

    /** 细化的知识点/参数（由Orchestrator解析后传入） */
    private String resolvedParams;
}