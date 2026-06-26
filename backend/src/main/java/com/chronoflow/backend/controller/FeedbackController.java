package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.FeedbackResponse;
import com.chronoflow.backend.dto.FeedbackSubmitRequest;
import com.chronoflow.backend.service.FeedbackService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
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
import java.nio.file.Paths;
import java.util.List;
import java.util.Map;

/**用户反馈控制器*/
@Slf4j
@RestController
@RequestMapping("/api/feedback")
@RequiredArgsConstructor
public class FeedbackController {

    private final FeedbackService feedbackService;

    // ==================== 提交反馈 ====================
    
    @PostMapping
    public ResponseEntity<FeedbackResponse> submitFeedback(
            HttpServletRequest request,
            @Valid @RequestBody FeedbackSubmitRequest body) {
        Long userId = getUserIdFromRequest(request);
        log.info("POST /api/feedback - userId: {}, type: {}", userId, body.getType());
        FeedbackResponse response = feedbackService.submitFeedback(userId, body);
        return ResponseEntity.ok(response);
    }

    // ==================== 我的反馈列表 ====================
    
    @GetMapping("/my")
    public ResponseEntity<List<FeedbackResponse>> getMyFeedbacks(HttpServletRequest request) {
        Long userId = getUserIdFromRequest(request);
        log.info("GET /api/feedback/my - userId: {}", userId);
        List<FeedbackResponse> responses = feedbackService.getMyFeedbacks(userId);
        return ResponseEntity.ok(responses);
    }

    // ==================== 反馈详情 ====================
    
    @GetMapping("/{id}")
    public ResponseEntity<FeedbackResponse> getFeedbackDetail(
            HttpServletRequest request,
            @PathVariable Long id) {
        Long userId = getUserIdFromRequest(request);
        log.info("GET /api/feedback/{} - userId: {}", id, userId);
        FeedbackResponse response = feedbackService.getFeedbackDetail(userId, id);
        return ResponseEntity.ok(response);
    }

    // ==================== 批量图片上传 ====================
    
    @PostMapping("/upload")
    public ResponseEntity<Map<String, Object>> uploadImages(
            HttpServletRequest request,
            @RequestParam("files") MultipartFile[] files) {
        Long userId = getUserIdFromRequest(request);
        log.info("POST /api/feedback/upload - userId: {}, fileCount: {}", userId,
                files != null ? files.length : 0);
        List<String> urls = feedbackService.uploadImages(files);
        return ResponseEntity.ok(Map.of(
                "urls", urls,
                "count", urls.size()
        ));
    }

    // ==================== 图片文件服务 ====================
    
    @GetMapping("/image/{filename}")
    public ResponseEntity<Resource> serveImage(@PathVariable String filename) {
        try {
            Path filePath = Paths.get(System.getProperty("user.dir"), "uploads", "feedback", filename);
            Resource resource = new UrlResource(filePath.toUri());

            if (!resource.exists() || !resource.isReadable()) {
                log.warn("Image not found: {}", filename);
                return ResponseEntity.notFound().build();
            }

            // 根据扩展名设置 Content-Type
            String contentType = guessContentType(filename);
            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(contentType))
                    .header(HttpHeaders.CACHE_CONTROL, "max-age=86400")
                    .body(resource);

        } catch (MalformedURLException e) {
            log.error("Failed to serve image: {}", filename, e);
            return ResponseEntity.internalServerError().build();
        }
    }

    // ==================== 辅助方法 ====================

    /**从 JWT 认证过滤器中提取当前登录用户 ID*/
    private Long getUserIdFromRequest(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }

    /**根据文件名后缀推断 MIME 类型*/
    private String guessContentType(String filename) {
        String lower = filename.toLowerCase();
        if (lower.endsWith(".png")) {
            return "image/png";
        }
        // 默认 jpg / jpeg
        return "image/jpeg";
    }
}