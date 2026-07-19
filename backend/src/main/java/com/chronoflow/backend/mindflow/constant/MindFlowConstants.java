package com.chronoflow.backend.mindflow.constant;

/**
 * MindFlow 模块常量 — 统一管理魔法数字。
 *
 * 所有 Agent / Service 中的超时、长度、限额等硬编码值都应该迁移到这里。
 * application.yaml 中的可调参数仍然通过 @ConfigurationProperties 注入。
 */
public final class MindFlowConstants {

    private MindFlowConstants() {}

    /** 用户输入最大长度（防 token 耗尽） */
    public static final int MAX_USER_INPUT_LENGTH = 2000;

    /** 单条 AI 回复最大累积长度（防 StringBuffer 无限增长） */
    public static final int MAX_TEXT_BUFFER_LENGTH = 100_000;

    /** SSE 事件单次 payload 最大长度（防网络层 OOM） */
    public static final int MAX_EVENT_PAYLOAD_LENGTH = 50_000;

    /** 缓存键前缀 */
    public static final String CACHE_KEY_RESOURCE = "mindflow:resource:";

    /** 缓存键分隔符 */
    public static final String CACHE_KEY_SEPARATOR = ":";

    /** 限流器 key 前缀（用户每日资源生成次数） */
    public static final String RATE_LIMIT_KEY_RESOURCE_DAILY = "mindflow:rl:resource:daily:";

    /** 限流器 key 前缀（用户每分钟对话次数） */
    public static final String RATE_LIMIT_KEY_CHAT_MINUTE = "mindflow:rl:chat:minute:";

    /** 每用户每日最大资源生成次数（兜底，默认值；可被 yaml 配置覆盖） */
    public static final int FALLBACK_MAX_RESOURCE_PER_DAY = 30;

    /** 每用户每分钟最大对话次数（兜底） */
    public static final int FALLBACK_MAX_CHAT_PER_MINUTE = 20;

    /** 内容审核未通过时的默认错误码 */
    public static final String ERROR_CONTENT_REVIEW = "CONTENT_REVIEW_FAILED";

    /** 限额超限错误码 */
    public static final String ERROR_RATE_LIMIT = "RATE_LIMIT_EXCEEDED";

    /** 输入超长错误码 */
    public static final String ERROR_INPUT_TOO_LONG = "INPUT_TOO_LONG";

    /** Prompt 注入错误码 */
    public static final String ERROR_PROMPT_INJECTION = "PROMPT_INJECTION_DETECTED";

    /** 星火 API 错误码 */
    public static final String ERROR_SPARK_API = "SPARK_API_ERROR";

    /** 内容审核降级错误码（审核服务未配置） */
    public static final String ERROR_REVIEW_UNAVAILABLE = "CONTENT_REVIEW_UNAVAILABLE";
}