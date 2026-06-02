package com.chronoflow.backend.exception;

/**
 * Base class for business logic exceptions.
 * Messages from BusinessException subclasses are safe to show to users.
 * GlobalExceptionHandler passes these messages through instead of masking them.
 */
public class BusinessException extends RuntimeException {
    public BusinessException(String message) {
        super(message);
    }

    public BusinessException(String message, Throwable cause) {
        super(message, cause);
    }
}
