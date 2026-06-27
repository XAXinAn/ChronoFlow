package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.dto.FeedbackResponse;
import com.chronoflow.backend.dto.PageResult;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.service.FeedbackService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@Slf4j
@RestController
@RequestMapping("/api/feedback")
@RequiredArgsConstructor
public class FeedbackController {

    private final FeedbackService feedbackService;

    // ==================== 提交反馈（单步 Multipart） ====================

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<FeedbackResponse>> submitFeedback(
            HttpServletRequest request,
            @RequestPart("type") String type,
            @RequestPart("content") String content,
            @RequestPart(value = "files", required = false) MultipartFile[] files) {
        Long userId = getUserIdFromRequest(request);
        log.info("POST /api/feedback multipart - userId: {}, type: {}, files: {}",
                userId, type, files != null ? files.length : 0);
        FeedbackResponse response = feedbackService.submitFeedback(userId, type, content, files);
        return ResponseEntity.ok(ApiResponse.success("提交成功", response));
    }

    // ==================== 我的反馈列表（分页） ====================

    @GetMapping("/my")
    public ResponseEntity<ApiResponse<PageResult<FeedbackResponse>>> getMyFeedbacks(
            HttpServletRequest request,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {
        Long userId = getUserIdFromRequest(request);
        log.info("GET /api/feedback/my - userId: {}, page: {}, size: {}", userId, page, size);
        return ResponseEntity.ok(ApiResponse.success("获取成功",
                feedbackService.getMyFeedbacks(userId, page, size)));
    }

    // ==================== 反馈详情 ====================

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<FeedbackResponse>> getFeedbackDetail(
            HttpServletRequest request, @PathVariable Long id) {
        Long userId = getUserIdFromRequest(request);
        log.info("GET /api/feedback/{} - userId: {}", id, userId);
        return ResponseEntity.ok(ApiResponse.success("获取成功",
                feedbackService.getFeedbackDetail(userId, id)));
    }

    // ==================== 辅助方法 ====================

    private Long getUserIdFromRequest(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            throw new BusinessException("用户未登录");
        }
        return userId;
    }
}
