package com.chronoflow.backend.mindflow.exception;

/**
 * 内容审核异常 — 当AI生成内容审核不通过或审核服务异常时抛出。
 * GlobalExceptionHandler 映射为 HTTP 422。
 */
public class ContentReviewException extends RuntimeException {
    public ContentReviewException(String message) {
        super(message);
    }

    public ContentReviewException(String message, Throwable cause) {
        super(message, cause);
    }
}