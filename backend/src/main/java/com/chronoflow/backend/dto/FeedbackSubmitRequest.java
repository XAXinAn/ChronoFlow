package com.chronoflow.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**提交反馈请求*/
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FeedbackSubmitRequest {

    /**反馈类型*/
    @NotBlank(message = "反馈类型不能为空")
    private String type;

    /**反馈正文*/
    @NotBlank(message = "反馈内容不能为空")
    @Size(min = 10, max = 500, message = "反馈内容需在10~500字之间")
    private String content;

    /**图片 URL 列表*/
    @Size(max = 5, message = "图片最多上传5张")
    private List<String> imageUrls;
}