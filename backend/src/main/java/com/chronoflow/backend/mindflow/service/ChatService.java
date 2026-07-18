package com.chronoflow.backend.mindflow.service;

import com.chronoflow.backend.mindflow.agent.*;
import com.chronoflow.backend.mindflow.entity.ChatMessage;
import com.chronoflow.backend.mindflow.entity.ChatSession;
import com.chronoflow.backend.mindflow.entity.StudentProfile;
import com.chronoflow.backend.mindflow.mapper.ChatMessageMapper;
import com.chronoflow.backend.mindflow.mapper.ChatSessionMapper;
import com.chronoflow.backend.mindflow.mapper.StudentProfileMapper;
import com.chronoflow.backend.mindflow.dto.MessageResponse;
import com.chronoflow.backend.mindflow.dto.SessionResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 对话服务 — 管理会话生命周期、消息存储、Agent调度入口。
 *
 * 核心职责：
 * - 会话创建与列表管理
 * - 消息持久化与历史查询
 * - Agent调度入口：构建AgentContext → OrchestratorAgent.classifyAndRoute() → Flux<AgentEvent>
 * - 上下文管理（取最近20轮历史，超8000 token自动摘要压缩）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatSessionMapper sessionMapper;
    private final ChatMessageMapper messageMapper;
    private final StudentProfileMapper profileMapper;
    private final OrchestratorAgent orchestratorAgent;

    /** 上下文窗口：最近N轮对话 */
    private static final int CONTEXT_ROUNDS = 20;

    /**
     * 创建新会话。
     */
    public SessionResponse createSession(Long userId) {
        String sessionId = UUID.randomUUID().toString().replace("-", "");
        ChatSession session = ChatSession.builder()
                .userId(userId)
                .sessionId(sessionId)
                .title("新对话")
                .status("ACTIVE")
                .build();
        sessionMapper.insert(session);
        log.info("创建会话: sessionId={}, userId={}", sessionId, userId);
        return toSessionResponse(session);
    }

    /**
     * 获取用户的活跃会话列表。
     */
    public List<SessionResponse> getSessions(Long userId) {
        return sessionMapper.findActiveByUserId(userId).stream()
                .map(this::toSessionResponse)
                .collect(Collectors.toList());
    }

    /**
     * 获取会话消息历史。
     */
    public List<MessageResponse> getMessages(String sessionId) {
        return messageMapper.findBySessionIdOrderByTime(sessionId).stream()
                .map(this::toMessageResponse)
                .collect(Collectors.toList());
    }

    /**
     * 发送消息并触发Agent调度（核心方法）。
     *
     * 流程：
     * 1. 保存用户消息
     * 2. 获取会话上下文（最近N轮历史 + 用户画像）
     * 3. 构建AgentContext
     * 4. 调用OrchestratorAgent进行分类→路由→执行
     * 5. 返回SSE事件流（token逐条推送，完整文本在完成时一次性存库）
     */
    public Flux<AgentEvent> sendMessage(Long userId, String sessionId, String message) {
        // 1. 确保会话存在
        if (sessionId == null || sessionId.isEmpty()) {
            sessionId = createSession(userId).getSessionId();
        }

        final String sid = sessionId;

        // 2. 保存用户消息
        saveMessage(sid, "user", message, "TEXT", null);

        // 3. 获取会话上下文
        List<String> history = getConversationHistory(sid);
        StudentProfile profile = profileMapper.selectByUserId(userId);

        // 4. 构建AgentContext
        AgentContext ctx = AgentContext.builder()
                .userId(userId)
                .sessionId(sid)
                .userMessage(message)
                .conversationHistory(history)
                .profile(profile)
                .build();

        // 5. 调用OrchestratorAgent，累积TEXT内容，流式推送
        StringBuilder textBuffer = new StringBuilder();
        return orchestratorAgent.execute(ctx)
                .doOnNext(event -> {
                    switch (event.getType()) {
                        case "TEXT" -> {
                            // 流式推送每个token，同时累积完整文本
                            if (event.getContent() != null) {
                                textBuffer.append(event.getContent());
                            }
                        }
                        case "RESOURCE_CARD", "PROFILE_CARD", "DIAGRAM" -> {
                            // 卡片/图表类消息即时存库
                            if (event.getContent() != null) {
                                saveMessage(sid, "assistant", event.getContent(),
                                        event.getType(), null);
                            }
                        }
                    }
                })
                .doOnComplete(() -> {
                    // 一次性保存完整AI回复文本（而非逐token存库）
                    String fullText = textBuffer.toString();
                    if (!fullText.isEmpty()) {
                        saveMessage(sid, "assistant", fullText, "TEXT", null);
                    }
                    log.info("Agent调度完成: sessionId={}", sid);
                })
                .doOnError(e -> log.error("Agent调度异常: sessionId={}, error={}", sid, e.getMessage()));
    }

    /**
     * 获取会话上下文（最近N轮对话历史）。
     */
    private List<String> getConversationHistory(String sessionId) {
        List<ChatMessage> recent = messageMapper.findRecentBySessionId(sessionId, CONTEXT_ROUNDS * 2);
        // 反转顺序（数据库取的是倒序）
        java.util.Collections.reverse(recent);
        return recent.stream()
                .map(m -> String.format("[%s]: %s", m.getRole(), m.getContent()))
                .collect(Collectors.toList());
    }

    /**
     * 保存消息到数据库。
     */
    private void saveMessage(String sessionId, String role, String content, String messageType, String metadata) {
        ChatMessage msg = ChatMessage.builder()
                .sessionId(sessionId)
                .role(role)
                .content(content)
                .messageType(messageType)
                .metadata(metadata)
                .build();
        messageMapper.insert(msg);
    }

    private SessionResponse toSessionResponse(ChatSession session) {
        return SessionResponse.builder()
                .sessionId(session.getSessionId())
                .title(session.getTitle())
                .status(session.getStatus())
                .createdAt(session.getCreatedAt())
                .updatedAt(session.getUpdatedAt())
                .build();
    }

    private MessageResponse toMessageResponse(ChatMessage msg) {
        return MessageResponse.builder()
                .id(msg.getId())
                .role(msg.getRole())
                .content(msg.getContent())
                .messageType(msg.getMessageType())
                .metadata(msg.getMetadata())
                .createdAt(msg.getCreatedAt())
                .build();
    }
}