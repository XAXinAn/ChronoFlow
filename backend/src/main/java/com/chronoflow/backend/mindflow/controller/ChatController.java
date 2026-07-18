package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.mindflow.agent.AgentEvent;
import com.chronoflow.backend.mindflow.dto.ChatRequest;
import com.chronoflow.backend.mindflow.dto.MessageResponse;
import com.chronoflow.backend.mindflow.dto.SessionResponse;
import com.chronoflow.backend.mindflow.service.ChatService;
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
 * 对话控制器 — MindFlow 对话系统的SSE流式接口。
 *
 * 接口清单（设计文档 6.1 节）：
 * - POST /api/v1/chat/session     创建新会话
 * - GET  /api/v1/chat/sessions    会话列表
 * - GET  /api/v1/chat/session/{id}/messages  消息历史
 * - POST /api/v1/chat/message     发送消息（SSE）★ 核心接口
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    /**
     * 创建新会话。
     * POST /api/v1/chat/session
     */
    @PostMapping("/session")
    public ResponseEntity<ApiResponse<SessionResponse>> createSession(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        SessionResponse session = chatService.createSession(userId);
        return ResponseEntity.ok(ApiResponse.success("会话创建成功", session));
    }

    /**
     * 获取会话列表。
     * GET /api/v1/chat/sessions
     */
    @GetMapping("/sessions")
    public ResponseEntity<ApiResponse<List<SessionResponse>>> getSessions(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        List<SessionResponse> sessions = chatService.getSessions(userId);
        return ResponseEntity.ok(ApiResponse.success("查询成功", sessions));
    }

    /**
     * 获取会话消息历史。
     * GET /api/v1/chat/session/{id}/messages
     */
    @GetMapping("/session/{id}/messages")
    public ResponseEntity<ApiResponse<List<MessageResponse>>> getMessages(
            @PathVariable("id") String sessionId) {
        List<MessageResponse> messages = chatService.getMessages(sessionId);
        return ResponseEntity.ok(ApiResponse.success("查询成功", messages));
    }

    /**
     * 发送消息（SSE流式响应）— 核心接口。
     * POST /api/v1/chat/message
     *
     * 返回 Server-Sent Events 流，事件类型包括：
     * - TEXT: 逐字追加的AI回复文本
     * - PROGRESS: 进度通知
     * - RESOURCE_CARD: 资源卡片
     * - PROFILE_CARD: 画像卡片
     * - DIAGRAM: Mermaid图解
     * - ERROR: 错误信息
     * - COMPLETE: 完成通知
     */
    @PostMapping(value = "/message", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<Map<String, Object>> sendMessage(
            HttpServletRequest request,
            @Valid @RequestBody ChatRequest chatRequest) {

        Long userId = (Long) request.getAttribute("userId");
        log.info("收到消息: userId={}, sessionId={}, message={}",
                userId, chatRequest.getSessionId(), chatRequest.getMessage());

        return chatService.sendMessage(userId, chatRequest.getSessionId(), chatRequest.getMessage())
                .map(this::toSseEvent)
                .doOnError(e -> log.error("SSE流异常: {}", e.getMessage(), e));
    }

    /**
     * 将AgentEvent转换为SSE事件Map。
     */
    private Map<String, Object> toSseEvent(AgentEvent event) {
        Map<String, Object> map = new java.util.LinkedHashMap<>();
        map.put("type", event.getType());
        if (event.getContent() != null) map.put("content", event.getContent());
        if (event.getStage() != null) map.put("stage", event.getStage());
        if (event.getPercent() > 0) map.put("percent", event.getPercent());
        if (event.getAgent() != null) map.put("agent", event.getAgent());
        if (event.getTitle() != null) map.put("title", event.getTitle());
        if (event.getMermaid() != null) map.put("mermaid", event.getMermaid());
        if (event.getCaption() != null) map.put("caption", event.getCaption());
        if (event.getSummary() != null) map.put("summary", event.getSummary());
        if (event.getResources() != null) map.put("resources", event.getResources());
        if (event.isRetryable()) map.put("retryable", true);
        if (event.getExtra() != null) map.putAll(event.getExtra());
        return map;
    }
}