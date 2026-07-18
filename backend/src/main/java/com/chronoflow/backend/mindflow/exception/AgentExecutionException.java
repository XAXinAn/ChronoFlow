package com.chronoflow.backend.mindflow.exception;

/**
 * Agent执行异常 — 当Agent引擎执行过程中发生错误时抛出。
 * GlobalExceptionHandler 映射为 HTTP 500。
 */
public class AgentExecutionException extends RuntimeException {
    public AgentExecutionException(String message) {
        super(message);
    }

    public AgentExecutionException(String message, Throwable cause) {
        super(message, cause);
    }
}