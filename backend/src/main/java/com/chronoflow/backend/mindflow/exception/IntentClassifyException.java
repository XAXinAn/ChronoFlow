package com.chronoflow.backend.mindflow.exception;

/**
 * 意图分类异常 — 当星火API意图分类失败时抛出。
 * GlobalExceptionHandler 映射为 HTTP 500，触发降级至通用对话。
 */
public class IntentClassifyException extends RuntimeException {
    public IntentClassifyException(String message) {
        super(message);
    }

    public IntentClassifyException(String message, Throwable cause) {
        super(message, cause);
    }
}