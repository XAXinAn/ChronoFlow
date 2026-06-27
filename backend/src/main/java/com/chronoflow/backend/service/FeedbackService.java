package com.chronoflow.backend.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.chronoflow.backend.dto.FeedbackResponse;
import com.chronoflow.backend.dto.PageResult;
import com.chronoflow.backend.entity.Feedback;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.mapper.FeedbackMapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class FeedbackService {

    private final FeedbackMapper feedbackMapper;
    private final ObjectMapper objectMapper;
    private final ContentModerationService contentModerationService;
    private final RateLimiterService rateLimiterService;

    @Value("${feedback.upload-dir:./uploads/feedback}")
    private String uploadDir;

    private static final long MAX_IMAGE_SIZE = 5 * 1024 * 1024;
    private static final int MAX_IMAGE_COUNT = 5;
    private static final int CONTENT_MIN_LENGTH = 10;
    private static final int CONTENT_MAX_LENGTH = 500;

    @PostConstruct
    public void init() {
        try {
            Path dir = Paths.get(uploadDir);
            if (!Files.exists(dir)) {
                Files.createDirectories(dir);
                log.info("Created feedback upload directory: {}", dir.toAbsolutePath());
            }
        } catch (IOException e) {
            log.error("Failed to create upload directory: {}", uploadDir, e);
        }
    }

    // ==================== 反馈提交（单步 Multipart） ====================

    public FeedbackResponse submitFeedback(Long userId, String type, String content, MultipartFile[] files) {
        // 1. Rate limiting
        if (!rateLimiterService.tryAcquire("feedback:submit:" + userId, 5, Duration.ofMinutes(1))) {
            throw new BusinessException("操作过于频繁，请稍后再试");
        }

        // 2. Validate type
        if (!Set.of("bug", "suggestion", "other").contains(type)) {
            throw new BusinessException("反馈类型无效，仅支持 bug / suggestion / other");
        }

        // 3. Validate content
        String trimmed = content != null ? content.trim() : "";
        if (trimmed.length() < CONTENT_MIN_LENGTH || trimmed.length() > CONTENT_MAX_LENGTH) {
            throw new BusinessException("反馈内容需在" + CONTENT_MIN_LENGTH + "~" + CONTENT_MAX_LENGTH + "字之间");
        }

        // 4. Content moderation (fail-open: allow if service unavailable)
        try {
            String reason = contentModerationService.moderate(trimmed);
            if (reason != null) {
                throw new ContentModerationException(reason);
            }
        } catch (ContentModerationException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Content moderation unavailable, allowing feedback through: {}", e.getMessage());
        }

        // 5. Save image files
        List<String> savedPaths = new ArrayList<>();
        List<String> imageUrls = new ArrayList<>();
        if (files != null && files.length > 0) {
            if (files.length > MAX_IMAGE_COUNT) {
                throw new BusinessException("图片最多上传" + MAX_IMAGE_COUNT + "张");
            }
            for (MultipartFile file : files) {
                if (file.isEmpty()) continue;
                if (file.getSize() > MAX_IMAGE_SIZE) {
                    throw new BusinessException("图片大小不能超过 5 MB");
                }
                String imageType = detectImageType(file);
                if (imageType == null) {
                    throw new BusinessException("图片格式仅支持 jpg / png");
                }
                String filename = "feedback_" + System.currentTimeMillis() + "_"
                        + UUID.randomUUID().toString().replace("-", "").substring(0, 8)
                        + "." + imageType;
                try {
                    Path destPath = Paths.get(uploadDir, filename);
                    file.transferTo(destPath.toAbsolutePath());
                    savedPaths.add(destPath.toAbsolutePath().toString());
                    imageUrls.add("/api/feedback/image/" + filename);
                    log.info("Feedback image saved: {}", destPath.toAbsolutePath());
                } catch (IOException e) {
                    // Clean up already-saved files on failure
                    for (String p : savedPaths) {
                        try { Files.deleteIfExists(Paths.get(p)); } catch (IOException ignored) {}
                    }
                    log.error("Failed to save feedback image: {}", filename, e);
                    throw new BusinessException("图片上传失败，请稍后重试");
                }
            }
        }

        // 6. Build entity
        String imageUrlsJson;
        try {
            imageUrlsJson = imageUrls.isEmpty() ? "[]" : objectMapper.writeValueAsString(imageUrls);
        } catch (JsonProcessingException e) {
            // Clean up saved files
            for (String p : savedPaths) {
                try { Files.deleteIfExists(Paths.get(p)); } catch (IOException ignored) {}
            }
            throw new BusinessException("图片数据处理失败，请重试");
        }

        Feedback feedback = Feedback.builder()
                .userId(userId)
                .type(type)
                .content(trimmed)
                .imageUrls(imageUrlsJson)
                .status("pending")
                .build();

        // 7. Insert — if DB fails, clean up files
        try {
            feedbackMapper.insert(feedback);
        } catch (Exception e) {
            for (String p : savedPaths) {
                try { Files.deleteIfExists(Paths.get(p)); } catch (IOException ignored) {}
            }
            throw new BusinessException("反馈提交失败，请重试");
        }

        log.info("Feedback submitted: userId={}, feedbackId={}, type={}, images={}",
                userId, feedback.getId(), type, imageUrls.size());
        return toResponse(feedback);
    }

    // ==================== 查询个人反馈列表（分页） ====================

    public PageResult<FeedbackResponse> getMyFeedbacks(Long userId, int page, int size) {
        QueryWrapper<Feedback> wrapper = new QueryWrapper<Feedback>()
                .eq("user_id", userId)
                .orderByDesc("created_at");

        Page<Feedback> p = new Page<>(page, size);
        Page<Feedback> result = feedbackMapper.selectPage(p, wrapper);

        List<FeedbackResponse> records = result.getRecords().stream()
                .map(this::toResponse)
                .toList();
        return new PageResult<>(records, result.getTotal(), result.getCurrent(), result.getSize());
    }

    // ==================== 查询单条反馈详情 ====================

    public FeedbackResponse getFeedbackDetail(Long userId, Long feedbackId) {
        Feedback feedback = feedbackMapper.selectById(feedbackId);
        if (feedback == null) {
            throw new BusinessException("反馈不存在");
        }
        if (!feedback.getUserId().equals(userId)) {
            throw new BusinessException("无权查看该反馈");
        }
        return toResponse(feedback);
    }

    // ==================== 图片安全路径解析 ====================

    public Path resolveSafePath(String baseDir, String filename) {
        // Reject dangerous characters
        if (filename == null || !filename.matches("^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$")) {
            throw new BusinessException("无效的文件名");
        }
        Path base = Paths.get(baseDir).toAbsolutePath().normalize();
        Path resolved = base.resolve(filename).normalize();
        if (!resolved.startsWith(base)) {
            log.warn("Path traversal attempt blocked: filename={}", filename);
            throw new BusinessException("无效的文件路径");
        }
        return resolved;
    }

    // ==================== 辅助方法 ====================

    private FeedbackResponse toResponse(Feedback f) {
        List<String> imageList = parseImageUrls(f.getImageUrls());
        return FeedbackResponse.builder()
                .id(f.getId())
                .userId(f.getUserId())
                .type(f.getType())
                .content(f.getContent())
                .imageUrls(imageList)
                .status(f.getStatus())
                .adminReply(f.getAdminReply())
                .createdAt(f.getCreatedAt())
                .updatedAt(f.getUpdatedAt())
                .build();
    }

    private List<String> parseImageUrls(String json) {
        if (json == null || json.isBlank() || "[]".equals(json.trim())) {
            return Collections.emptyList();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<List<String>>() {});
        } catch (JsonProcessingException e) {
            log.warn("Failed to parse imageUrls JSON, returning empty list: {}", json, e);
            return Collections.emptyList();
        }
    }

    private String detectImageType(MultipartFile file) {
        try {
            byte[] header = new byte[4];
            try (var in = file.getInputStream()) {
                int read = in.read(header);
                if (read < 2) return null;
            }
            if ((header[0] & 0xFF) == 0xFF && (header[1] & 0xFF) == 0xD8 && (header[2] & 0xFF) == 0xFF) {
                return "jpeg";
            }
            if ((header[0] & 0xFF) == 0x89 && (header[1] & 0xFF) == 0x50
                    && (header[2] & 0xFF) == 0x4E && (header[3] & 0xFF) == 0x47) {
                return "png";
            }
            return null;
        } catch (IOException e) {
            log.error("Failed to detect image type", e);
            return null;
        }
    }
}
