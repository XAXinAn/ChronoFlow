package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.dto.FeedbackResponse;
import com.chronoflow.backend.dto.PageResult;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.service.FeedbackService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.net.MalformedURLException;
import java.nio.file.Path;

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

    // ==================== 图片文件服务（路径穿越防护 + 认证） ====================

    @GetMapping("/image/{filename}")
    public ResponseEntity<Resource> serveImage(
            HttpServletRequest request, @PathVariable String filename) {
        // Require authentication
        Long userId = getUserIdFromRequest(request);

        try {
            Path filePath = feedbackService.resolveSafePath(
                    "./uploads/feedback", filename);
            Resource resource = new UrlResource(filePath.toUri());

            if (!resource.exists() || !resource.isReadable()) {
                log.warn("Image not found: {}", filename);
                return ResponseEntity.notFound().build();
            }

            String contentType = guessContentType(filename);
            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(contentType))
                    .header(HttpHeaders.CACHE_CONTROL, "max-age=86400")
                    .body(resource);

        } catch (BusinessException e) {
            return ResponseEntity.badRequest().build();
        } catch (MalformedURLException e) {
            log.error("Failed to serve image: {}", filename, e);
            return ResponseEntity.internalServerError().build();
        }
    }

    // ==================== 辅助方法 ====================

    private Long getUserIdFromRequest(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            throw new BusinessException("用户未登录");
        }
        return userId;
    }

    private String guessContentType(String filename) {
        String lower = filename.toLowerCase();
        if (lower.endsWith(".png")) return "image/png";
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
        return "image/jpeg";
    }
}
