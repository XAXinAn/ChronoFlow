package com.chronoflow.backend.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.chronoflow.backend.dto.FeedbackResponse;
import com.chronoflow.backend.dto.PageResult;
import com.chronoflow.backend.entity.Feedback;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.mapper.FeedbackMapper;
import com.chronoflow.backend.mapper.UserMapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class AdminService {

    private final FeedbackMapper feedbackMapper;
    private final UserMapper userMapper;
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    public PageResult<FeedbackResponse> listFeedbacks(int page, int size, String status, String type) {
        QueryWrapper<Feedback> wrapper = new QueryWrapper<>();
        if (status != null && !status.isBlank()) wrapper.eq("status", status);
        if (type != null && !type.isBlank()) wrapper.eq("type", type);
        wrapper.orderByDesc("created_at");

        Page<Feedback> p = new Page<>(page, size);
        Page<Feedback> result = feedbackMapper.selectPage(p, wrapper);

        List<FeedbackResponse> records = result.getRecords().stream()
                .map(this::toResponse)
                .toList();
        return new PageResult<>(records, result.getTotal(), result.getCurrent(), result.getSize());
    }

    public FeedbackResponse getFeedbackDetail(Long feedbackId) {
        Feedback f = feedbackMapper.selectById(feedbackId);
        if (f == null) throw new BusinessException("反馈不存在");
        return toResponse(f);
    }

    @Transactional
    public FeedbackResponse replyFeedback(Long feedbackId, String reply) {
        Feedback f = feedbackMapper.selectById(feedbackId);
        if (f == null) throw new BusinessException("反馈不存在");
        if (reply == null || reply.isBlank()) throw new BusinessException("回复内容不能为空");
        if (reply.length() > 1000) throw new BusinessException("回复内容不能超过1000字");
        f.setAdminReply(reply);
        // Auto-transition to resolved if currently pending or processing
        if ("pending".equals(f.getStatus()) || "processing".equals(f.getStatus())) {
            f.setStatus("resolved");
        }
        f.setUpdatedAt(LocalDateTime.now());
        feedbackMapper.updateById(f);
        return toResponse(f);
    }

    @Transactional
    public FeedbackResponse updateFeedbackStatus(Long feedbackId, String status) {
        Set<String> valid = Set.of("pending", "processing", "resolved", "closed");
        if (!valid.contains(status)) throw new BusinessException("无效的状态: " + status);
        Feedback f = feedbackMapper.selectById(feedbackId);
        if (f == null) throw new BusinessException("反馈不存在");
        f.setStatus(status);
        f.setUpdatedAt(LocalDateTime.now());
        feedbackMapper.updateById(f);
        return toResponse(f);
    }

    public PageResult<Map<String, Object>> listUsers(int page, int size) {
        QueryWrapper<User> wrapper = new QueryWrapper<>();
        wrapper.orderByDesc("created_at");
        wrapper.select("id", "username", "nickname", "email", "phone",
                "real_name_verified", "created_at");

        Page<User> p = new Page<>(page, size);
        Page<User> result = userMapper.selectPage(p, wrapper);

        List<Map<String, Object>> records = result.getRecords().stream().map(u -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", u.getId());
            m.put("username", u.getUsername());
            m.put("nickname", u.getNickname());
            m.put("email", u.getEmail());
            m.put("phone", u.getPhone());
            m.put("realNameVerified", u.getRealNameVerified());
            m.put("createdAt", u.getCreatedAt() != null ? u.getCreatedAt().toString() : null);
            return m;
        }).toList();
        return new PageResult<>(records, result.getTotal(), result.getCurrent(), result.getSize());
    }

    private FeedbackResponse toResponse(Feedback f) {
        List<String> imageUrls = new ArrayList<>();
        if (f.getImageUrls() != null && !f.getImageUrls().isBlank()) {
            try {
                imageUrls = OBJECT_MAPPER.readValue(f.getImageUrls(),
                        new com.fasterxml.jackson.core.type.TypeReference<List<String>>() {});
            } catch (Exception e) {
                log.warn("Failed to parse imageUrls for feedback {}", f.getId());
            }
        }
        return FeedbackResponse.builder()
                .id(f.getId())
                .userId(f.getUserId())
                .type(f.getType())
                .content(f.getContent())
                .imageUrls(imageUrls)
                .status(f.getStatus())
                .adminReply(f.getAdminReply())
                .createdAt(f.getCreatedAt())
                .updatedAt(f.getUpdatedAt())
                .build();
    }
}
