package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.mindflow.agent.AgentEvent;
import com.chronoflow.backend.mindflow.constant.MindFlowConstants;
import com.chronoflow.backend.mindflow.dto.ChatRequest;
import com.chronoflow.backend.mindflow.dto.MessageResponse;
import com.chronoflow.backend.mindflow.dto.SessionResponse;
import com.chronoflow.backend.mindflow.service.ChatService;
import com.chronoflow.backend.service.RateLimiterService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;
import java.time.Duration;

import java.util.List;
import java.util.Map;

/**
 * 对话控制器 — MindFlow 对话系统的 SSE 流式接口。
 *
 * 接口清单（设计文档 6.1 节）：
 * - POST /api/v1/chat/session     创建新会话
 * - GET  /api/v1/chat/sessions    会话列表
 * - GET  /api/v1/chat/session/{id}/messages  消息历史
 * - POST /api/v1/chat/message     发送消息（SSE）★ 核心接口
 *
 * 修复（vs HEAD）：
 * - 加每分钟限流（防 API 滥用、降低 LLM 费用）
 * - 加 ChatService.sendMessage 错误处理（统一格式）
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;
    private final RateLimiterService rateLimiterService;

    /**
     * 创建新会话。
     */
    @PostMapping("/session")
    public ResponseEntity<ApiResponse<SessionResponse>> createSession(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        // 限流：每分钟最多 N 次创建会话
        if (!rateLimiterService.tryAcquire(MindFlowConstants.RATE_LIMIT_KEY_CHAT_MINUTE + userId, MindFlowConstants.FALLBACK_MAX_CHAT_PER_MINUTE, java.time.Duration.ofSeconds(60))) {
            return ResponseEntity.ok(ApiResponse.error(429, "请求过于频繁，请稍后再试"));
        }
        SessionResponse session = chatService.createSession(userId);
        return ResponseEntity.ok(ApiResponse.success("会话创建成功", session));
    }

    /**
     * 获取会话列表。
     */
    @GetMapping("/sessions")
    public ResponseEntity<ApiResponse<List<SessionResponse>>> getSessions(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        List<SessionResponse> sessions = chatService.getSessions(userId);
        return ResponseEntity.ok(ApiResponse.success("查询成功", sessions));
    }

    /**
     * 获取会话消息历史。
     */
    @GetMapping("/session/{id}/messages")
    public ResponseEntity<ApiResponse<List<MessageResponse>>> getMessages(
            @PathVariable("id") String sessionId) {
        List<MessageResponse> messages = chatService.getMessages(sessionId);
        return ResponseEntity.ok(ApiResponse.success("查询成功", messages));
    }

    /**
     * 发送消息（SSE 流式响应）— 核心接口。
     *
     * 限流策略：每分钟最多 N 次 sendMessage 调用（防 API 滥用）
     *
     * 返回 Server-Sent Events 流，事件类型包括：
     * - TEXT: 逐字追加的 AI 回复文本
     * - PROGRESS: 进度通知
     * - RESOURCE_CARD: 资源卡片
     * - PROFILE_CARD: 画像卡片
     * - DIAGRAM: Mermaid 图解
     * - WARNING: 警告（不中断流，如文本截断、缓存命中）
     * - ERROR: 错误信息
     * - COMPLETE: 完成通知
     */
    @PostMapping(value = "/message", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public ResponseEntity<Flux<Map<String, Object>>> sendMessage(
            HttpServletRequest request,
            @Valid @RequestBody ChatRequest chatRequest) {

        Long userId = (Long) request.getAttribute("userId");

        // 限流检查
        Flux<Map<String, Object>> errorFlux = Flux.just(Map.of(
                "type", "ERROR",
                "content", "请求过于频繁，请稍后再试（每分钟最多 " + MindFlowConstants.FALLBACK_MAX_CHAT_PER_MINUTE + " 次）",
                "retryable", false
        ));

        if (!rateLimiterService.tryAcquire(MindFlowConstants.RATE_LIMIT_KEY_CHAT_MINUTE + userId, MindFlowConstants.FALLBACK_MAX_CHAT_PER_MINUTE, java.time.Duration.ofSeconds(60))) {
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, "text/event-stream;charset=UTF-8")
                    .body(errorFlux);
        }

        String sessionId = chatRequest.getSessionId();
        String message = chatRequest.getMessage();

        Flux<Map<String, Object>> flux = chatService.sendMessage(userId, sessionId, message)
                .map(this::agentEventToMap)
                .onErrorResume(e -> {
                    log.error("SSE 流异常: userId={}, error={}", userId, e.getMessage(), e);
                    return Flux.just(Map.of(
                            "type", "ERROR",
                            "content", "服务异常：" + e.getMessage(),
                            "retryable", true
                    ));
                });

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, "text/event-stream;charset=UTF-8")
                .body(flux);
    }

    /**
     * AgentEvent → Map（前端 JSON 序列化）
     */
    private Map<String, Object> agentEventToMap(AgentEvent event) {
        Map<String, Object> map = new java.util.LinkedHashMap<>();
        if (event.getType() != null) map.put("type", event.getType());
        if (event.getAgent() != null) map.put("agent", event.getAgent());
        if (event.getStage() != null) map.put("stage", event.getStage());
        if (event.getContent() != null) map.put("content", event.getContent());
        if (event.getTitle() != null) map.put("title", event.getTitle());
        if (event.getSummary() != null) map.put("summary", event.getSummary());
        if (event.getExtra() != null) map.put("extra", event.getExtra());
        if (event.getPercent() > 0) map.put("percent", event.getPercent());
        map.put("retryable", event.isRetryable());
        return map;
    }
}


