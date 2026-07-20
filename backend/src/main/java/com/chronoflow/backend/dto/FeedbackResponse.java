package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

/**反馈响应 DTO*/
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FeedbackResponse {

    /** 反馈 ID */
    private Long id;

    /** 提交用户 ID */
    private Long userId;

    /**反馈类型*/
    private String type;

    /** 反馈正文（10~500 字） */
    private String content;

    /**图片 URL */
    private List<String> imageUrls;

    /**处理状态*/
    private String status;

    /** 管理员回复内容（未回复时为 null） */
    private String adminReply;

    /** 提交时间 */
    private LocalDateTime createdAt;

    /** 最近更新时间 */
    private LocalDateTime updatedAt;
}