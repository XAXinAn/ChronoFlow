package com.chronoflow.backend.mindflow.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 学习画像响应 — 六维画像的完整返回格式。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProfileResponse {

    private Long userId;
    private String knowledgeBase;
    private String cognitiveStyle;
    private String weakPoints;
    private String pacePreference;
    private String interests;
    private String peakHours;
    private String errorTypes;
    private Integer profileVersion;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}