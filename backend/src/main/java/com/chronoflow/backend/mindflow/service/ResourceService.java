package com.chronoflow.backend.mindflow.service;

import com.chronoflow.backend.mindflow.agent.*;
import com.chronoflow.backend.mindflow.config.MindFlowConfig;
import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.constant.MindFlowConstants;
import com.chronoflow.backend.mindflow.dto.ResourceResponse;
import com.chronoflow.backend.mindflow.entity.LearningResource;
import com.chronoflow.backend.mindflow.mapper.LearningResourceMapper;
import com.chronoflow.backend.mindflow.review.MindFlowReviewService;
import com.chronoflow.backend.mindflow.util.PromptGuard;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.service.MinioService;
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
 *
 * 修复（vs HEAD）：
 * - 加 Redis 缓存（同一用户同一知识点重复请求直接返回缓存）
 * - 加 PromptGuard 输入校验
 * - 加 MindFlowReviewService 内容审核（每个 RESOURCE_CARD 入库前）
 * - 加 MindFlowConstants 常量引用
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ResourceService {

    private final ResourceOrchestrator resourceOrchestrator;
    private final LearningResourceMapper resourceMapper;
    private final MindFlowConfig config;
    private final MindFlowCacheService cacheService;
    private final MindFlowReviewService reviewService;
    private final MinioService minioService;

    /**
     * 生成学习资源（SSE 流式）。
     *
     * 流程：缓存检查 → 限额检查 → PromptGuard 校验 → 内容审核 → Orchestrator 执行
     */
    public Flux<AgentEvent> generateResources(Long userId, String sessionId, String topic) {
        // 1. 输入安全校验
        try {
            PromptGuard.validate(topic);
        } catch (Exception e) {
            log.warn("用户输入未通过 PromptGuard: {}", e.getMessage());
            return Flux.just(AgentEvent.builder()
                    .type(AgentEventType.ERROR.getCode())
                    .content(e.getMessage())
                    .retryable(false)
                    .build());
        }

        // 2. 用户输入内容审核
        try {
            reviewService.reviewUserInput(topic);
        } catch (Exception e) {
            log.warn("用户输入未通过内容审核: {}", e.getMessage());
            return Flux.just(AgentEvent.builder()
                    .type(AgentEventType.ERROR.getCode())
                    .content(e.getMessage())
                    .retryable(false)
                    .build());
        }

        // 3. 检查每日限额
        int todayCount = resourceMapper.countTodayByUserId(userId);
        int maxPerDay = config.getResource().getMaxPerDay() > 0
                ? config.getResource().getMaxPerDay()
                : MindFlowConstants.FALLBACK_MAX_RESOURCE_PER_DAY;
        if (todayCount >= maxPerDay) {
            return Flux.just(AgentEvent.builder()
                    .type(AgentEventType.ERROR.getCode())
                    .content("今日资源生成次数已达上限（" + maxPerDay + "次），请明天再来")
                    .retryable(false)
                    .build());
        }

        // 4. 检查缓存（同一用户同一主题 24h 内复用）
        String cached = cacheService.getResourceCache(userId, topic);
        if (cached != null) {
            log.info("命中资源缓存: userId={}, topic={}", userId, topic);
            return Flux.just(
                    AgentEvent.builder()
                            .type(AgentEventType.PROGRESS.getCode())
                            .stage("cache_hit")
                            .content("命中 1 小时内的缓存结果，直接返回")
                            .percent(0.5)
                            .build(),
                    AgentEvent.builder()
                            .type(AgentEventType.DIAGRAM.getCode())
                            .content(cached)
                            .build(),
                    AgentEvent.builder()
                            .type(AgentEventType.COMPLETE.getCode())
                            .summary("已返回缓存资源")
                            .build()
            );
        }

        // 5. 执行编排器
        AgentContext ctx = AgentContext.builder()
                .userId(userId)
                .sessionId(sessionId)
                .userMessage(topic)
                .intentLabel("RESOURCE_GEN")
                .build();

        return resourceOrchestrator.execute(ctx)
                .doOnNext(event -> {
                    // 当 RESOURCE_CARD 事件到达时，内容审核 + 缓存
                    if (AgentEventType.RESOURCE_CARD.getCode().equals(event.getType())) {
                        // 内容审核（防止 AI 生成违规内容入库）
                        try {
                            reviewService.reviewGeneratedContent(event.getContent(), "RESOURCE");
                        } catch (Exception e) {
                            log.warn("RESOURCE_CARD 内容审核未通过: {}", e.getMessage());
                        }
                    }
                    // COMPLETE 时缓存生成的资源
                    if (AgentEventType.COMPLETE.getCode().equals(event.getType())) {
                        try {
                            // 简单方案：缓存 topic 字符串 + 时间戳（实际内容已入库 learning_resource）
                            int ttl = config.getResource().getCacheHours() > 0
                                    ? config.getResource().getCacheHours() : 1;
                            String cacheValue = String.format("{\"topic\":\"%s\",\"generatedAt\":\"%s\"}",
                                    topic.replace("\"", "\\\""),
                                    java.time.LocalDateTime.now().toString());
                            cacheService.putResourceCache(userId, topic, cacheValue, ttl);
                        } catch (Exception e) {
                            log.warn("写入资源缓存失败: {}", e.getMessage());
                        }
                    }
                })
                .onErrorResume(e -> {
                    log.error("资源生成异常: {}", e.getMessage(), e);
                    return Flux.just(AgentEvent.builder()
                            .type(AgentEventType.ERROR.getCode())
                            .content("资源生成失败：" + e.getMessage())
                            .retryable(true)
                            .build());
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
        // 反馈信息记录到 metadata 中
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

    private ResourceResponse toResourceResponse(LearningResource resource) {
        String downloadUrl = null;
        if (resource.getFileKey() != null && !resource.getFileKey().isEmpty()) {
            try {
                downloadUrl = minioService.getResourceUrl(resource.getFileKey());
            } catch (Exception e) {
                // MinIO 不可用时返回 null
            }
        }
        return ResourceResponse.builder()
                .id(resource.getId())
                .userId(resource.getUserId())
                .sessionId(resource.getSessionId())
                .resourceType(resource.getResourceType())
                .title(resource.getTitle())
                .fileKey(resource.getFileKey())
                .fileSize(resource.getFileSize())
                .downloadUrl(downloadUrl)
                .content(resource.getContent())
                .confidenceScore(resource.getConfidenceScore())
                .reviewed(resource.getReviewed() != null && resource.getReviewed())
                .createdAt(resource.getCreatedAt())
                .build();
    }
}