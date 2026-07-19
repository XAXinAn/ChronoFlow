package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.mindflow.agent.AgentEvent;
import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.dto.SessionResponse;
import com.chronoflow.backend.mindflow.service.ChatService;
import com.chronoflow.backend.service.RateLimiterService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import reactor.core.publisher.Flux;
import reactor.test.StepVerifier;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/**
 * ChatController 单元测试 — HTTP 接口 + 限流 + 事件转换。
 *
 * 不使用 @WebMvcTest（避免 Spring 上下文开销），直接测试 Controller 方法。
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("ChatController HTTP 接口测试")
class ChatControllerTest {

    @Mock private ChatService chatService;
    @Mock private RateLimiterService rateLimiterService;
    @Mock private HttpServletRequest request;

    @InjectMocks private ChatController chatController;

    @BeforeEach
    void setUp() {
        when(request.getAttribute("userId")).thenReturn(100L);
    }

    // ============ createSession 限流 ============

    @Test
    @DisplayName("createSession 通过限流应成功创建")
    void createSession_rateLimitOk_shouldSucceed() {
        when(rateLimiterService.tryAcquire(anyString(), anyInt(), any())).thenReturn(true);
        when(chatService.createSession(anyLong()))
                .thenReturn(SessionResponse.builder().title("测试").sessionId("s1").status("ACTIVE").title("新对话").build());

        ResponseEntity<ApiResponse<SessionResponse>> response = chatController.createSession(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getCode()).isEqualTo(200);
        assertThat(response.getBody().getData().getSessionId()).isEqualTo("s1");
    }

    @Test
    @DisplayName("createSession 触发限流应返回 429")
    void createSession_rateLimited_shouldReturn429() {
        when(rateLimiterService.tryAcquire(anyString(), anyInt(), any())).thenReturn(false);

        ResponseEntity<ApiResponse<SessionResponse>> response = chatController.createSession(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getCode()).isEqualTo(429);
        assertThat(response.getBody().getMessage()).contains("请求过于频繁");
        verify(chatService, never()).createSession(anyLong());
    }

    // ============ getSessions ============

    @Test
    @DisplayName("getSessions 应返回用户会话列表")
    void getSessions_shouldReturnList() {
        when(chatService.getSessions(100L)).thenReturn(List.of(
                SessionResponse.builder().title("测试").sessionId("s1").title("t1").status("ACTIVE").build(),
                SessionResponse.builder().title("测试").sessionId("s2").title("t2").status("ACTIVE").build()
        ));

        ResponseEntity<ApiResponse<List<SessionResponse>>> response = chatController.getSessions(request);

        assertThat(response.getBody().getData()).hasSize(2);
        assertThat(response.getBody().getCode()).isEqualTo(200);
    }

    // ============ getMessages ============

    @Test
    @DisplayName("getMessages 应返回指定会话消息")
    void getMessages_shouldReturnList() {
        com.chronoflow.backend.mindflow.dto.MessageResponse msg = new com.chronoflow.backend.mindflow.dto.MessageResponse();
        msg.setId(1L);
        msg.setRole("user");
        msg.setContent("hi");
        when(chatService.getMessages("s1")).thenReturn(List.of(msg));

        ResponseEntity<ApiResponse<List<com.chronoflow.backend.mindflow.dto.MessageResponse>>> response =
                chatController.getMessages("s1");

        assertThat(response.getBody().getData()).hasSize(1);
        assertThat(response.getBody().getData().get(0).getContent()).isEqualTo("hi");
    }

    // ============ sendMessage 限流 ============

    @Test
    @DisplayName("sendMessage 通过限流应正常返回 Flux")
    void sendMessage_rateLimitOk_shouldReturnFlux() {
        when(rateLimiterService.tryAcquire(anyString(), anyInt(), any())).thenReturn(true);
        when(chatService.sendMessage(anyLong(), anyString(), anyString()))
                .thenReturn(Flux.just(
                        AgentEvent.builder().type(AgentEventType.TEXT.getCode())
                                .content("hello").build(),
                        AgentEvent.builder().type(AgentEventType.COMPLETE.getCode()).summary("done").build()
                ));

        com.chronoflow.backend.mindflow.dto.ChatRequest req = new com.chronoflow.backend.mindflow.dto.ChatRequest();
        req.setSessionId("s1");
        req.setMessage("test");

        Flux<Map<String, Object>> result = chatController.sendMessage(request, req);

        StepVerifier.create(result)
                .assertNext(map -> {
                    assertThat(map.get("type")).isEqualTo("TEXT");
                    assertThat(map.get("content")).isEqualTo("hello");
                })
                .assertNext(map -> {
                    assertThat(map.get("type")).isEqualTo("COMPLETE");
                    assertThat(map.get("summary")).isEqualTo("done");
                })
                .verifyComplete();
    }

    @Test
    @DisplayName("sendMessage 触发限流应返回 ERROR SSE 事件")
    void sendMessage_rateLimited_shouldReturnErrorEvent() {
        when(rateLimiterService.tryAcquire(anyString(), anyInt(), any())).thenReturn(false);

        com.chronoflow.backend.mindflow.dto.ChatRequest req = new com.chronoflow.backend.mindflow.dto.ChatRequest();
        req.setSessionId("s1");
        req.setMessage("test");

        Flux<Map<String, Object>> result = chatController.sendMessage(request, req);

        StepVerifier.create(result)
                .assertNext(map -> {
                    assertThat(map.get("type")).isEqualTo("ERROR");
                    assertThat(map.get("content").toString()).contains("请求过于频繁");
                    assertThat(map.get("retryable")).isEqualTo(false);
                })
                .verifyComplete();

        verify(chatService, never()).sendMessage(anyLong(), anyString(), anyString());
    }

    @Test
    @DisplayName("sendMessage ChatService 抛异常应被 onErrorResume 捕获")
    void sendMessage_serviceException_shouldBeCaught() {
        when(rateLimiterService.tryAcquire(anyString(), anyInt(), any())).thenReturn(true);
        when(chatService.sendMessage(anyLong(), anyString(), anyString()))
                .thenReturn(Flux.error(new RuntimeException("Agent 调度异常")));

        com.chronoflow.backend.mindflow.dto.ChatRequest req = new com.chronoflow.backend.mindflow.dto.ChatRequest();
        req.setSessionId("s1");
        req.setMessage("test");

        Flux<Map<String, Object>> result = chatController.sendMessage(request, req);

        StepVerifier.create(result)
                .assertNext(map -> {
                    assertThat(map.get("type")).isEqualTo("ERROR");
                    assertThat(map.get("content").toString()).contains("服务异常");
                    assertThat(map.get("retryable")).isEqualTo(true);
                })
                .verifyComplete();
    }
}