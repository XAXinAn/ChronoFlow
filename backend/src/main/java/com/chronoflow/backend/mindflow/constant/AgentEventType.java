package com.chronoflow.backend.mindflow.constant;

/**
 * MindFlow SSE 事件类型枚举。
 *
 * 前端 chat_service.dart 通过事件的 type 字段路由不同 UI 组件。
 * 新增事件类型必须在此枚举中定义，避免硬编码字符串。
 */
public enum AgentEventType {
    /** 逐字 token 流（text chunk） */
    TEXT("TEXT"),
    /** 进度通知（如 profile_init / searching / generating 等阶段） */
    PROGRESS("PROGRESS"),
    /** 学习资源卡片（如讲解文档、练习题生成完毕） */
    RESOURCE_CARD("RESOURCE_CARD"),
    /** 学习画像卡片（6 维画像构建完成） */
    PROFILE_CARD("PROFILE_CARD"),
    /** Mermaid 图解（思维导图、流程图） */
    DIAGRAM("DIAGRAM"),
    /** 警告事件（不中断流，如文本截断、缓存命中） */
    WARNING("WARNING"),
    /** 错误事件（流终止，可重试） */
    ERROR("ERROR"),
    /** 完成事件（流正常结束） */
    COMPLETE("COMPLETE");

    private final String code;

    AgentEventType(String code) {
        this.code = code;
    }

    public String getCode() {
        return code;
    }

    /** 字符串 code → 枚举（容错） */
    public static AgentEventType fromCode(String code) {
        if (code == null) return TEXT;
        for (AgentEventType t : values()) {
            if (t.code.equals(code)) return t;
        }
        logUnknown(code);
        return TEXT;
    }

    private static void logUnknown(String code) {
        org.slf4j.LoggerFactory.getLogger(AgentEventType.class)
                .warn("未知的 AgentEventType code: {}", code);
    }

    @Override
    public String toString() {
        return code;
    }
}