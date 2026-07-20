package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.mindflow.agent.AgentEvent;
import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.dto.ResourceResponse;
import com.chronoflow.backend.mindflow.service.ResourceService;
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

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/**
 * ResourceController 单元测试。
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("ResourceController 资源接口测试")
class ResourceControllerTest {

    @Mock private ResourceService resourceService;
    @Mock private HttpServletRequest request;

    @InjectMocks private ResourceController resourceController;

    @BeforeEach
    void setUp() {
        when(request.getAttribute("userId")).thenReturn(100L);
    }

    @Test
    @DisplayName("generateResources 应返回 SSE Flux<AgentEvent> 资源生成事件流")
    void generateResources_shouldReturnFlux() {
        when(resourceService.generateResources(anyLong(), anyString(), anyString()))
                .thenReturn(Flux.just(
                        AgentEvent.builder().type(AgentEventType.PROGRESS.getCode()).content("正在生成").build(),
                        AgentEvent.builder().type(AgentEventType.COMPLETE.getCode()).summary("完成").build()
                ));

        com.chronoflow.backend.mindflow.dto.ResourceRequest req = new com.chronoflow.backend.mindflow.dto.ResourceRequest();
        req.setSessionId("s1");
        req.setTopic("机器学习");

        Flux<Map<String, Object>> result = resourceController.generateResources(request, req).getBody();

        StepVerifier.create(result)
                .assertNext(e -> assertThat(e.get("type")).isEqualTo("PROGRESS"))
                .assertNext(e -> assertThat(e.get("type")).isEqualTo("COMPLETE"))
                .verifyComplete();
    }

    @Test
    @DisplayName("getResources 应返回用户资源列表")
    void getResources_shouldReturnList() {
        when(resourceService.getResourcesByType(100L, "DOC")).thenReturn(List.of(
                ResourceResponse.builder().id(1L).userId(100L).resourceType("DOC")
                        .title("doc1").content("c1").confidenceScore(new BigDecimal("0.85"))
                        .reviewed(true).version(1).build()
        ));

        ResponseEntity<ApiResponse<List<ResourceResponse>>> response = resourceController.getResources(request, "DOC");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getData()).hasSize(1);
    }

    @Test
    @DisplayName("getResources 不传 type 应默认查 DOC")
    void getResources_noType_shouldDefaultToDoc() {
        when(resourceService.getResourcesByType(100L, "DOC")).thenReturn(List.of());

        resourceController.getResources(request, null);

        verify(resourceService, times(1)).getResourcesByType(100L, "DOC");
    }

    @Test
    @DisplayName("getResourceDetail 应返回资源详情")
    void getResourceDetail_shouldReturnResource() {
        when(resourceService.getResourceDetail(1L))
                .thenReturn(ResourceResponse.builder().id(1L).userId(100L)
                        .title("机器学习").content("content").build());

        ResponseEntity<ApiResponse<ResourceResponse>> response = resourceController.getResourceDetail(1L);

        assertThat(response.getBody().getData().getId()).isEqualTo(1L);
    }

    @Test
    @DisplayName("getResourceDetail 资源不存在应抛 BusinessException")
    void getResourceDetail_notFound_shouldThrow() {
        when(resourceService.getResourceDetail(999L))
                .thenThrow(new BusinessException("资源不存在"));

        assertThatThrownBy(() -> resourceController.getResourceDetail(999L))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("submitFeedback 应成功提交反馈")
    void submitFeedback_shouldSucceed() {
        com.chronoflow.backend.mindflow.dto.ResourceFeedbackRequest req =
                new com.chronoflow.backend.mindflow.dto.ResourceFeedbackRequest();
        req.setRating(5);
        req.setComment("很好");

        ResponseEntity<ApiResponse<Void>> response = resourceController.submitFeedback(1L, req);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getCode()).isEqualTo(200);
        verify(resourceService, times(1)).submitFeedback(1L, 5, "很好");
    }

    @Test
    @DisplayName("submitFeedback 直接调用不触发 @Valid（验证在 Spring MVC 层）")
    void submitFeedback_invalidRatingDirectCall_shouldNotThrow() {
        com.chronoflow.backend.mindflow.dto.ResourceFeedbackRequest req =
                new com.chronoflow.backend.mindflow.dto.ResourceFeedbackRequest();
        req.setRating(10);

        // 直接调用 controller 方法不会触发 @Valid 验证
        org.junit.jupiter.api.Assertions.assertDoesNotThrow(() -> resourceController.submitFeedback(1L, req));
    }
}