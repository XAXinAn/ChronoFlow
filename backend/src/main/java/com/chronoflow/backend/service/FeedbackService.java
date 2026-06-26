package com.chronoflow.backend.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chronoflow.backend.dto.FeedbackResponse;
import com.chronoflow.backend.dto.FeedbackSubmitRequest;
import com.chronoflow.backend.entity.Feedback;
import com.chronoflow.backend.exception.BusinessException;
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
import java.util.*;

/**用户反馈业务逻辑层*/
@Slf4j
@Service
@RequiredArgsConstructor
public class FeedbackService {

    private final FeedbackMapper feedbackMapper;
    private final ObjectMapper objectMapper;

    /** 图片上传目录（可通过环境变量 FEEDBACK_UPLOAD_DIR 覆盖） */
    @Value("${feedback.upload-dir:./uploads/feedback}")
    private String uploadDir;

    /** 单张图片最大大小：5 MB */
    private static final long MAX_IMAGE_SIZE = 5 * 1024 * 1024;

    /** 每次最多上传图片数 */
    private static final int MAX_IMAGE_COUNT = 5;

    /** 反馈内容字数限制 */
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

    // ==================== 反馈提交 ====================
    
    public FeedbackResponse submitFeedback(Long userId, FeedbackSubmitRequest request) {
        // 1. 兜底校验反馈类型
        if (!Set.of("bug", "suggestion", "other").contains(request.getType())) {
            throw new BusinessException("反馈类型无效，仅支持 bug / suggestion / other");
        }

        // 2. 兜底校验内容长度
        String content = request.getContent().trim();
        if (content.length() < CONTENT_MIN_LENGTH || content.length() > CONTENT_MAX_LENGTH) {
            throw new BusinessException("反馈内容需在" + CONTENT_MIN_LENGTH + "~" + CONTENT_MAX_LENGTH + "字之间");
        }

        // 3. 图片数量兜底校验
        List<String> imageUrls = request.getImageUrls() != null
                ? request.getImageUrls()
                : Collections.emptyList();
        if (imageUrls.size() > MAX_IMAGE_COUNT) {
            throw new BusinessException("图片最多上传" + MAX_IMAGE_COUNT + "张");
        }

        // 4. 将图片 URL 列表序列化为 JSON 字符串
        String imageUrlsJson;
        try {
            imageUrlsJson = imageUrls.isEmpty()
                    ? "[]"
                    : objectMapper.writeValueAsString(imageUrls);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize imageUrls: {}", imageUrls, e);
            throw new BusinessException("图片数据处理失败，请重试");
        }

        // 5. 构建实体并插入
        Feedback feedback = Feedback.builder()
                .userId(userId)
                .type(request.getType())
                .content(content)
                .imageUrls(imageUrlsJson)
                .status("pending")
                .build();

        feedbackMapper.insert(feedback);
        log.info("Feedback submitted: userId={}, feedbackId={}, type={}", userId, feedback.getId(), request.getType());

        return toResponse(feedback);
    }

    // ==================== 查询个人反馈列表 ====================
    
    public List<FeedbackResponse> getMyFeedbacks(Long userId) {
        List<Feedback> feedbacks = feedbackMapper.selectList(
                new QueryWrapper<Feedback>()
                        .eq("user_id", userId)
                        .orderByDesc("created_at")
        );

        List<FeedbackResponse> responses = new ArrayList<>();
        for (Feedback f : feedbacks) {
            responses.add(toResponse(f));
        }
        return responses;
    }

    // ==================== 查询单条反馈详情 ====================
    
    public FeedbackResponse getFeedbackDetail(Long userId, Long feedbackId) {
        Feedback feedback = feedbackMapper.selectById(feedbackId);
        if (feedback == null) {
            throw new BusinessException("反馈不存在");
        }

        // 仅允许本人查看
        if (!feedback.getUserId().equals(userId)) {
            throw new BusinessException("无权查看该反馈");
        }

        return toResponse(feedback);
    }

    // ==================== 批量图片上传 ====================
    
    public List<String> uploadImages(MultipartFile[] files) {
        if (files == null || files.length == 0) {
            throw new BusinessException("请选择要上传的图片");
        }
        if (files.length > MAX_IMAGE_COUNT) {
            throw new BusinessException("图片最多上传" + MAX_IMAGE_COUNT + "张");
        }

        List<String> urls = new ArrayList<>();

        for (MultipartFile file : files) {
            // 校验文件非空
            if (file.isEmpty()) {
                throw new BusinessException("图片文件不能为空");
            }

            // 校验文件大小（≤ 5 MB）
            if (file.getSize() > MAX_IMAGE_SIZE) {
                throw new BusinessException("图片大小不能超过 5 MB，当前: "
                        + String.format("%.1f", file.getSize() / 1024.0 / 1024.0) + " MB");
            }

            // 校验文件格式（使用魔数检测）
            String realImageType = detectImageType(file);
            if (realImageType == null) {
                throw new BusinessException("图片格式仅支持 jpg / png，请检查文件格式");
            }

            // 生成唯一文件名（使用真实格式作为扩展名）
            String extension = realImageType; // "jpeg" or "png"
            String filename = "feedback_" + System.currentTimeMillis() + "_"
                    + UUID.randomUUID().toString().replace("-", "").substring(0, 8)
                    + "." + extension;

            // 保存到本地
            try {
                Path destPath = Paths.get(uploadDir, filename);
                file.transferTo(destPath);
                log.info("Feedback image saved: {} ({} bytes)", destPath.toAbsolutePath(), file.getSize());
            } catch (IOException e) {
                log.error("Failed to save feedback image: {}", filename, e);
                throw new BusinessException("图片上传失败，请稍后重试");
            }

            // 返回访问 URL
            urls.add("/api/feedback/image/" + filename);
        }

        return urls;
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

    /**将数据库中 JSON 字符串反序列化为 List{@code <String>}*/
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

    /**
     * 通过文件魔数（magic bytes）检测真实图片类型。
     * @return "jpeg" 或 "png"，如果无法识别则返回 null
     */
    private String detectImageType(MultipartFile file) {
        try {
            byte[] header = new byte[4];
            try (var in = file.getInputStream()) {
                int read = in.read(header);
                if (read < 2) return null;
            }

            // JPEG: FF D8 FF
            if ((header[0] & 0xFF) == 0xFF && (header[1] & 0xFF) == 0xD8 && (header[2] & 0xFF) == 0xFF) {
                return "jpeg";
            }
            // PNG: 89 50 4E 47
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