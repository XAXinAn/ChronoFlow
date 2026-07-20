package com.chronoflow.backend.exception;

/**
 * Thrown when user-submitted content fails moderation.
 * The message should be shown to the user directly.
 */
public class ContentModerationException extends BusinessException {
    public ContentModerationException(String message) {
        super(message);
    }
}
