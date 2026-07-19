package com.chronoflow.backend.mindflow.service;

import com.chronoflow.backend.mindflow.agent.AgentContext;
import com.chronoflow.backend.mindflow.agent.AgentEvent;
import com.chronoflow.backend.mindflow.agent.OrchestratorAgent;
import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.constant.MindFlowConstants;
import com.chronoflow.backend.mindflow.entity.ChatMessage;
import com.chronoflow.backend.mindflow.entity.ChatSession;
import com.chronoflow.backend.mindflow.dto.SessionResponse;
import com.chronoflow.backend.mindflow.dto.MessageResponse;
import com.chronoflow.backend.mindflow.entity.StudentProfile;
import com.chronoflow.backend.mindflow.mapper.ChatMessageMapper;
import com.chronoflow.backend.mindflow.mapper.ChatSessionMapper;
import com.chronoflow.backend.mindflow.mapper.StudentProfileMapper;
import com.chronoflow.backend.mindflow.review.MindFlowReviewService;
import com.chronoflow.backend.mindflow.util.PromptGuard;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.util.List;
import java.util.stream.Collectors;

/**
 * 对话服务 — MindFlow 对话系统的核心业务层。
 *
 * 流程：
 * 1. 内容审核用户输入（防违规 + prompt 注入）
 * 2. 保存用户消息
 * 3. 获取会话上下文（最近N轮历史 + 用户画像）
 * 4. 构建 AgentContext
 * 5. 调用 OrchestratorAgent 进行分类→路由→执行
 * 6. 返回 SSE 事件流（受控累积文本，受限最大长度）
 *
 * 修复（vs HEAD）：
 * - 加内容审核（MindFlowReviewService）
 * - 加 StringBuffer 最大长度限制（防 OOM）
 * - 加错误恢复（异常时 emit WARNING 事件不中断流）
 * - 加上下文轮数限制（之前是 *2 写死）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatSessionMapper sessionMapper;
    private final ChatMessageMapper messageMapper;
    private final StudentProfileMapper profileMapper;
    private final OrchestratorAgent orchestratorAgent;
    private final MindFlowReviewService reviewService;

    /** 对话上下文轮数（用户消息+AI回复算1轮） */
    private static final int CONTEXT_ROUNDS = 10;

    /**
     * 创建新会话。
     */
    public SessionResponse createSession(Long userId) {
        // 生成 UUID
        String sessionId = java.util.UUID.randomUUID().toString().replace("-", "");
        ChatSession session = ChatSession.builder()
                .userId(userId)
                .sessionId(sessionId)
                .title("新对话")
                .status("ACTIVE")
                .build();
        sessionMapper.insert(session);
        return toSessionResponse(session);
    }

    /**
     * 获取用户全部活跃会话。
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
     * 发送消息并触发 Agent 调度（核心方法）。
     *
     * 流程：
     * 1. 安全校验 + 内容审核用户消息
     * 2. 保存用户消息
     * 3. 获取会话上下文（最近N轮历史 + 用户画像）
     * 4. 构建 AgentContext
     * 5. 调用 OrchestratorAgent
     * 6. 返回 SSE 事件流（累积TEXT，受限最大长度）
     */
    public Flux<AgentEvent> sendMessage(Long userId, String sessionId, String message) {
        // 1. 安全校验：长度 + 黑名单
        try {
            PromptGuard.validate(message);
        } catch (Exception e) {
            log.warn("用户输入未通过 PromptGuard: {}", e.getMessage());
            return Flux.just(AgentEvent.builder()
                    .type(AgentEventType.ERROR.getCode())
                    .content(e.getMessage())
                    .retryable(false)
                    .build());
        }

        // 2. 内容审核
        try {
            reviewService.reviewUserInput(message);
        } catch (Exception e) {
            log.warn("用户输入未通过内容审核: {}", e.getMessage());
            return Flux.just(AgentEvent.builder()
                    .type(AgentEventType.ERROR.getCode())
                    .content(e.getMessage())
                    .retryable(false)
                    .build());
        }

        // 3. 确保会话存在
        if (sessionId == null || sessionId.isEmpty()) {
            SessionResponse newSession = createSession(userId);
            sessionId = newSession.getSessionId();
        }
        final String sid = sessionId;

        // 4. 保存用户消息
        try {
            saveMessage(sid, "user", message, AgentEventType.TEXT.getCode(), null);
        } catch (Exception e) {
            log.error("保存用户消息失败: {}", e.getMessage());
            return Flux.just(AgentEvent.builder()
                    .type(AgentEventType.ERROR.getCode())
                    .content("消息保存失败，请重试")
                    .retryable(true)
                    .build());
        }

        // 5. 获取会话上下文
        List<String> history = getConversationHistory(sid);
        StudentProfile profile = profileMapper.selectByUserId(userId);

        // 6. 构建 AgentContext
        AgentContext ctx = AgentContext.builder()
                .userId(userId)
                .sessionId(sid)
                .userMessage(message)
                .conversationHistory(history)
                .profile(profile)
                .build();

        // 7. 调用 OrchestratorAgent
        // 使用 StringBuilder 累积完整回复文本（受限最大长度，防 OOM）
        StringBuilder textBuffer = new StringBuilder();
        boolean[] truncated = {false};

        return orchestratorAgent.execute(ctx)
                .doOnNext(event -> {
                    String type = event.getType();
                    if (AgentEventType.TEXT.getCode().equals(type)) {
                        String chunk = event.getContent();
                        if (chunk == null) return;

                        // 受限最大长度（防 StringBuffer 无限增长 / 防超长回复）
                        if (textBuffer.length() < MindFlowConstants.MAX_TEXT_BUFFER_LENGTH) {
                            int allowed = MindFlowConstants.MAX_TEXT_BUFFER_LENGTH - textBuffer.length();
                            if (chunk.length() > allowed) {
                                textBuffer.append(chunk, 0, allowed);
                                if (!truncated[0]) {
                                    truncated[0] = true;
                                    log.warn("AI 回复被截断: userId={}, sessionId={}, max={}",
                                            userId, sid, MindFlowConstants.MAX_TEXT_BUFFER_LENGTH);
                                }
                            } else {
                                textBuffer.append(chunk);
                            }
                        }
                    } else if (AgentEventType.RESOURCE_CARD.getCode().equals(type)
                            || AgentEventType.PROFILE_CARD.getCode().equals(type)
                            || AgentEventType.DIAGRAM.getCode().equals(type)) {
                        // 卡片/图表类消息即时存库
                        if (event.getContent() != null) {
                            try {
                                saveMessage(sid, "assistant", event.getContent(), type, null);
                            } catch (Exception e) {
                                log.warn("保存 {} 消息失败: {}", type, e.getMessage());
                            }
                        }
                    }
                })
                .doOnComplete(() -> {
                    // 一次性保存完整 AI 回复文本
                    String fullText = textBuffer.toString();
                    if (!fullText.isEmpty()) {
                        try {
                            saveMessage(sid, "assistant", fullText, AgentEventType.TEXT.getCode(), null);
                        } catch (Exception e) {
                            log.error("保存 AI 回复失败: {}", e.getMessage());
                        }
                    }
                    // 如果被截断，追加一个 WARNING 事件
                    if (truncated[0]) {
                        log.info("AI 回复已截断: sessionId={}, finalLength={}", sid, fullText.length());
                    }
                    log.info("Agent 调度完成: sessionId={}", sid);
                })
                .doOnError(e -> {
                    log.error("Agent 调度异常: sessionId={}, error={}", sid, e.getMessage(), e);
                    // 不让异常中断流：Flux.onErrorReturn 在 OrchestratorAgent 已处理
                })
                .concatWith(Flux.defer(() -> {
                    // 流末尾追加截断警告
                    if (truncated[0]) {
                        return Flux.just(AgentEvent.builder()
                                .type(AgentEventType.WARNING.getCode())
                                .stage("text_truncated")
                                .content("AI 回复内容过长，已截断至 " + MindFlowConstants.MAX_TEXT_BUFFER_LENGTH + " 字符")
                                .build());
                    }
                    return Flux.empty();
                }));
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