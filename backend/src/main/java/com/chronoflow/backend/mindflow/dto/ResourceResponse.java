package com.chronoflow.backend.mindflow.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 学习资源响应 — 资源列表和详情的返回格式。
 *
 * 修复（vs HEAD）：
 * - 加 userId / sessionId 字段（前端展示需要）
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ResourceResponse {

    private Long id;
    private Long userId;
    private String sessionId;
    private String resourceType;
    private String title;
    private String content;
    private String metadata;
    private BigDecimal confidenceScore;
    private Boolean reviewed;
    private Integer version;
    private LocalDateTime createdAt;
}