package com.chronoflow.backend.mindflow.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 资源质量反馈请求 — POST /api/v1/resources/{id}/feedback。
 */
@Data
public class FeedbackRequest {

    /** 评分 1-5 */
    @NotNull(message = "评分不能为空")
    @Min(1) @Max(5)
    private Integer rating;

    /** 反馈意见（可选） */
    private String comment;
}