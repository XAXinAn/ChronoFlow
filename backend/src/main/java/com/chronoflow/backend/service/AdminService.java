package com.chronoflow.backend.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chronoflow.backend.dto.FeedbackResponse;
import com.chronoflow.backend.dto.PageResult;
import com.chronoflow.backend.entity.Feedback;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.mapper.FeedbackMapper;
import com.chronoflow.backend.mapper.GroupMapper;
import com.chronoflow.backend.mapper.GroupMemberMapper;
import com.chronoflow.backend.mapper.ScheduleMapper;
import com.chronoflow.backend.mapper.UserMapper;
import com.chronoflow.backend.entity.Group;
import com.chronoflow.backend.entity.GroupMember;
import com.chronoflow.backend.entity.Schedule;
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
    private final GroupMapper groupMapper;
    private final GroupMemberMapper groupMemberMapper;
    private final ScheduleMapper scheduleMapper;
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    public PageResult<FeedbackResponse> listFeedbacks(int page, int size, String status, String type, String keyword) {
        QueryWrapper<Feedback> wrapper = new QueryWrapper<>();
        if (status != null && !status.isBlank()) wrapper.eq("status", status);
        if (type != null && !type.isBlank()) wrapper.eq("type", type);
        if (keyword != null && !keyword.isBlank()) wrapper.like("content", keyword);
        wrapper.orderByDesc("created_at");

        long total = feedbackMapper.selectCount(wrapper);
        wrapper.last("LIMIT " + ((page - 1) * size) + "," + size);
        List<Feedback> list = feedbackMapper.selectList(wrapper);

        List<FeedbackResponse> records = list.stream().map(this::toResponse).toList();
        return new PageResult<>(records, total, page, size);
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

    public PageResult<Map<String, Object>> listUsers(int page, int size, String keyword) {
        QueryWrapper<User> wrapper = new QueryWrapper<>();
        if (keyword != null && !keyword.isBlank()) {
            wrapper.and(w -> w.like("username", keyword).or().like("nickname", keyword)
                    .or().like("phone", keyword).or().like("email", keyword));
        }
        wrapper.orderByDesc("created_at");
        wrapper.select("id", "username", "nickname", "email", "phone",
                "real_name_verified", "created_at");

        long total = userMapper.selectCount(wrapper);
        wrapper.last("LIMIT " + ((page - 1) * size) + "," + size);
        List<User> userList = userMapper.selectList(wrapper);

        List<Map<String, Object>> records = userList.stream().map(u -> {
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
        return new PageResult<>(records, total, page, size);
    }

    // ==================== 群组 ====================

    public PageResult<Map<String, Object>> listGroups(int page, int size, String keyword) {
        QueryWrapper<Group> wrapper = new QueryWrapper<>();
        if (keyword != null && !keyword.isBlank()) wrapper.like("name", keyword);
        wrapper.orderByDesc("created_at");

        long total = groupMapper.selectCount(wrapper);
        wrapper.last("LIMIT " + ((page - 1) * size) + "," + size);
        List<Group> groupList = groupMapper.selectList(wrapper);

        List<String> groupIds = groupList.stream().map(Group::getId).toList();
        java.util.Map<String, Integer> memberCounts = new java.util.HashMap<>();
        if (!groupIds.isEmpty()) {
            for (GroupMember m : groupMemberMapper.selectList(
                    new QueryWrapper<GroupMember>().in("group_id", groupIds))) {
                memberCounts.merge(m.getGroupId(), 1, Integer::sum);
            }
        }

        List<Map<String, Object>> records = groupList.stream().map(g -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", g.getId());
            m.put("name", g.getName());
            m.put("creatorId", g.getCreatorId());
            m.put("parentId", g.getParentId());
            m.put("depth", g.getDepth());
            m.put("memberCount", memberCounts.getOrDefault(g.getId(), 0));
            m.put("createdAt", g.getCreatedAt() != null ? g.getCreatedAt().toString() : null);
            return m;
        }).toList();
        return new PageResult<>(records, total, page, size);
    }

    // ==================== 日程 ====================

    public PageResult<Map<String, Object>> listSchedules(int page, int size, String keyword) {
        QueryWrapper<Schedule> wrapper = new QueryWrapper<>();
        if (keyword != null && !keyword.isBlank()) {
            wrapper.and(w -> w.like("title", keyword).or().like("description", keyword));
        }
        wrapper.orderByDesc("schedule_time");

        long total = scheduleMapper.selectCount(wrapper);
        wrapper.last("LIMIT " + ((page - 1) * size) + "," + size);
        List<Schedule> scheduleList = scheduleMapper.selectList(wrapper);

        List<String> groupIds = scheduleList.stream()
                .map(Schedule::getGroupId).filter(Objects::nonNull).distinct().toList();
        java.util.Map<String, String> groupNames = new java.util.HashMap<>();
        if (!groupIds.isEmpty()) {
            for (Group g : groupMapper.selectList(
                    new QueryWrapper<Group>().in("id", groupIds))) {
                groupNames.put(g.getId(), g.getName());
            }
        }

        List<Map<String, Object>> records = scheduleList.stream().map(s -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", s.getId());
            m.put("userId", s.getUserId());
            m.put("title", s.getTitle());
            m.put("description", s.getDescription());
            m.put("location", s.getLocation());
            m.put("scheduleTime", s.getTime() != null ? s.getTime().toString() : null);
            m.put("groupId", s.getGroupId());
            m.put("groupName", s.getGroupId() != null ? groupNames.getOrDefault(s.getGroupId(), "") : null);
            m.put("createdAt", s.getCreatedAt() != null ? s.getCreatedAt().toString() : null);
            return m;
        }).toList();
        return new PageResult<>(records, total, page, size);
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
