package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.mindflow.agent.AgentEvent;
import com.chronoflow.backend.mindflow.dto.ResourceFeedbackRequest;
import com.chronoflow.backend.mindflow.dto.ResourceRequest;
import com.chronoflow.backend.mindflow.dto.ResourceResponse;
import com.chronoflow.backend.mindflow.service.ResourceService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;

import java.util.List;
import java.util.Map;

/**
 * 资源控制器 — 学习资源的生成、查询、反馈接口。
 *
 * 接口清单：
 * - POST /api/v1/resources/generate    生成资源（SSE流式）★ 核心接口
 * - GET  /api/v1/resources             资源列表（按类型筛选）
 * - GET  /api/v1/resources/{id}        资源详情
 * - POST /api/v1/resources/{id}/feedback  资源质量反馈
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/resources")
@RequiredArgsConstructor
public class ResourceController {

    private final ResourceService resourceService;

    /**
     * 生成学习资源（SSE流式）。
     * POST /api/v1/resources/generate
     *
     * 四阶段流程：知识点细化 → 联网检索 → 5子Agent并行生成 → 审核+持久化
     */
    @PostMapping(value = "/generate", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<Map<String, Object>> generateResources(
            HttpServletRequest request,
            @Valid @RequestBody ResourceRequest resourceRequest) {

        Long userId = (Long) request.getAttribute("userId");
        log.info("资源生成请求: userId={}, topic={}", userId, resourceRequest.getTopic());

        return resourceService.generateResources(
                        userId,
                        resourceRequest.getSessionId(),
                        resourceRequest.getTopic())
                .map(this::toSseEvent);
    }

    /**
     * 获取资源列表（可按类型筛选）。
     * GET /api/v1/resources?type=DOC
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<ResourceResponse>>> getResources(
            HttpServletRequest request,
            @RequestParam(required = false) String type) {

        Long userId = (Long) request.getAttribute("userId");
        String resourceType = (type != null) ? type.toUpperCase() : "DOC";
        List<ResourceResponse> resources = resourceService.getResourcesByType(userId, resourceType);
        return ResponseEntity.ok(ApiResponse.success("查询成功", resources));
    }

    /**
     * 获取资源详情。
     * GET /api/v1/resources/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ResourceResponse>> getResourceDetail(@PathVariable Long id) {
        ResourceResponse resource = resourceService.getResourceDetail(id);
        return ResponseEntity.ok(ApiResponse.success("查询成功", resource));
    }

    /**
     * 提交资源质量反馈。
     * POST /api/v1/resources/{id}/feedback
     */
    @PostMapping("/{id}/feedback")
    public ResponseEntity<ApiResponse<Void>> submitFeedback(
            @PathVariable Long id,
            @Valid @RequestBody ResourceFeedbackRequest feedback) {

        resourceService.submitFeedback(id, feedback.getRating(), feedback.getComment());
        return ResponseEntity.ok(ApiResponse.success("反馈提交成功", null));
    }

    private Map<String, Object> toSseEvent(AgentEvent event) {
        Map<String, Object> map = new java.util.LinkedHashMap<>();
        map.put("type", event.getType());
        if (event.getContent() != null) map.put("content", event.getContent());
        if (event.getStage() != null) map.put("stage", event.getStage());
        if (event.getPercent() > 0) map.put("percent", event.getPercent());
        if (event.getAgent() != null) map.put("agent", event.getAgent());
        if (event.getTitle() != null) map.put("title", event.getTitle());
        if (event.getSummary() != null) map.put("summary", event.getSummary());
        if (event.isRetryable()) map.put("retryable", true);
        if (event.getResources() != null) map.put("resources", event.getResources());
        return map;
    }
}
