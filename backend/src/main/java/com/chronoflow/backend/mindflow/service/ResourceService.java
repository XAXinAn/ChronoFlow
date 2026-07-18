package com.chronoflow.backend.mindflow.service;

import com.chronoflow.backend.mindflow.agent.*;
import com.chronoflow.backend.mindflow.config.MindFlowConfig;
import com.chronoflow.backend.mindflow.dto.ResourceResponse;
import com.chronoflow.backend.mindflow.entity.LearningResource;
import com.chronoflow.backend.mindflow.mapper.LearningResourceMapper;
import com.chronoflow.backend.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 资源服务 — 管理学习资源的生成、查询、反馈。
 *
 * 核心流程：
 * - 资源生成：ResourceOrchestrator编排 → 5子Agent并行生成 → SSE流式推送 → 持久化
 * - 资源查询：按类型筛选、分页列表、详情查看
 * - 资源反馈：用户评分 + 意见收集
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ResourceService {

    private final ResourceOrchestrator resourceOrchestrator;
    private final LearningResourceMapper resourceMapper;
    private final MindFlowConfig config;

    /**
     * 生成学习资源（SSE流式）。
     * 调用ResourceOrchestrator执行四阶段流程：细化→检索→并行生成→持久化。
     */
    public Flux<AgentEvent> generateResources(Long userId, String sessionId, String topic) {
        // 检查每日限额
        int todayCount = resourceMapper.countTodayByUserId(userId);
        if (todayCount >= config.getResource().getMaxPerDay()) {
            return Flux.just(AgentEvent.builder()
                    .type("ERROR")
                    .content("今日资源生成次数已达上限（" + config.getResource().getMaxPerDay() + "次），请明天再来")
                    .retryable(false)
                    .build());
        }

        AgentContext ctx = AgentContext.builder()
                .userId(userId)
                .sessionId(sessionId)
                .userMessage(topic)
                .intentLabel("RESOURCE_GEN")
                .build();

        return resourceOrchestrator.execute(ctx)
                .doOnNext(event -> {
                    // 当RESOURCE_CARD事件到达时，持久化资源
                    if ("RESOURCE_CARD".equals(event.getType())) {
                        persistResource(userId, sessionId, event);
                    }
                });
    }

    /**
     * 按类型获取资源列表。
     */
    public List<ResourceResponse> getResourcesByType(Long userId, String resourceType) {
        return resourceMapper.findByUserIdAndType(userId, resourceType).stream()
                .map(this::toResourceResponse)
                .collect(Collectors.toList());
    }

    /**
     * 获取资源详情。
     */
    public ResourceResponse getResourceDetail(Long resourceId) {
        LearningResource resource = resourceMapper.selectById(resourceId);
        if (resource == null) {
            throw new BusinessException("资源不存在");
        }
        return toResourceResponse(resource);
    }

    /**
     * 提交资源反馈。
     */
    public void submitFeedback(Long resourceId, int rating, String comment) {
        LearningResource resource = resourceMapper.selectById(resourceId);
        if (resource == null) {
            throw new BusinessException("资源不存在");
        }
        // 反馈信息记录到metadata中
        try {
            String metadata = resource.getMetadata();
            String feedbackJson = String.format("{\"rating\":%d,\"comment\":\"%s\"}", rating,
                    comment != null ? comment.replace("\"", "\\\"") : "");
            String updatedMetadata = metadata != null && !metadata.isEmpty()
                    ? metadata.substring(0, metadata.length() - 1) + ",\"feedback\":" + feedbackJson + "}"
                    : "{\"feedback\":" + feedbackJson + "}";
            resource.setMetadata(updatedMetadata);
            resourceMapper.updateById(resource);
            log.info("资源反馈已记录: resourceId={}, rating={}", resourceId, rating);
        } catch (Exception e) {
            log.warn("记录资源反馈失败: {}", e.getMessage());
        }
    }

    /**
     * 持久化生成的资源。
     */
    private void persistResource(Long userId, String sessionId, AgentEvent event) {
        try {
            String resourceType = event.getAgent();
            if (resourceType == null) return;

            // 映射Agent名称到资源类型
            String type = switch (resourceType) {
                case "DocAgent" -> "DOC";
                case "MindMapAgent" -> "MINDMAP";
                case "QuizAgent" -> "QUIZ";
                case "ReadingAgent" -> "READING";
                case "CodeAgent" -> "CODE";
                default -> resourceType;
            };

            LearningResource resource = LearningResource.builder()
                    .userId(userId)
                    .sessionId(sessionId)
                    .resourceType(type)
                    .title(event.getTitle() != null ? event.getTitle() : "学习资源")
                    .content(event.getContent())
                    .confidenceScore(new BigDecimal("0.85"))
                    .reviewed(false)
                    .build();
            resourceMapper.insert(resource);
            log.info("资源已持久化: type={}, id={}", type, resource.getId());
        } catch (Exception e) {
            log.error("持久化资源失败: {}", e.getMessage());
        }
    }

    private ResourceResponse toResourceResponse(LearningResource resource) {
        return ResourceResponse.builder()
                .id(resource.getId())
                .resourceType(resource.getResourceType())
                .title(resource.getTitle())
                .content(resource.getContent())
                .metadata(resource.getMetadata())
                .confidenceScore(resource.getConfidenceScore())
                .reviewed(resource.getReviewed())
                .createdAt(resource.getCreatedAt())
                .build();
    }
}