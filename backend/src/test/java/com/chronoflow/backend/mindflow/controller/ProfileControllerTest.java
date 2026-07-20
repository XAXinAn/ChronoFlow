package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.mindflow.agent.AgentEvent;
import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.dto.ProfileResponse;
import com.chronoflow.backend.mindflow.service.ProfileService;
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

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/**
 * ProfileController 单元测试 — 六维画像接口。
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("ProfileController 画像接口测试")
class ProfileControllerTest {

    @Mock private ProfileService profileService;
    @Mock private HttpServletRequest request;

    @InjectMocks private ProfileController profileController;

    @BeforeEach
    void setUp() {
        when(request.getAttribute("userId")).thenReturn(100L);
    }

    @Test
    @DisplayName("getProfile 已存在画像应返回")
    void getProfile_existing_shouldReturn() {
        ProfileResponse profile = ProfileResponse.builder()
                .userId(100L).knowledgeBase("良好").cognitiveStyle("visual")
                .weakPoints("链表").pacePreference("normal")
                .interests("机器学习").peakHours("晚上").errorTypes("边界条件")
                .profileVersion(1).build();
        when(profileService.getProfile(100L)).thenReturn(profile);

        ResponseEntity<ApiResponse<ProfileResponse>> response = profileController.getProfile(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getCode()).isEqualTo(200);
        assertThat(response.getBody().getData().getKnowledgeBase()).isEqualTo("良好");
    }

    @Test
    @DisplayName("getProfile 用户没有画像应返回 200 + data=null")
    void getProfile_notFound_shouldReturnNullData() {
        when(profileService.getProfile(100L)).thenReturn(null);

        ResponseEntity<ApiResponse<ProfileResponse>> response = profileController.getProfile(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getCode()).isEqualTo(200);
        assertThat(response.getBody().getData()).isNull();
    }

    @Test
    @DisplayName("buildProfile 应返回 SSE Flux<AgentEvent>")
    void buildProfile_shouldReturnFlux() {
        when(profileService.buildProfile(anyLong(), anyString(), anyString()))
                .thenReturn(Flux.just(
                        AgentEvent.builder().type(AgentEventType.PROGRESS.getCode()).content("init").build(),
                        AgentEvent.builder().type(AgentEventType.PROFILE_CARD.getCode()).content("card").build(),
                        AgentEvent.builder().type(AgentEventType.COMPLETE.getCode()).summary("done").build()
                ));

        ProfileController.ProfileBuildRequest body = new ProfileController.ProfileBuildRequest();
        body.setSessionId("s1");
        body.setMessage("开始");

        Flux<Map<String, Object>> result = profileController.buildProfile(request, body).getBody();

        StepVerifier.create(result)
                .assertNext(m -> assertThat(m.get("type")).isEqualTo("PROGRESS"))
                .assertNext(m -> assertThat(m.get("type")).isEqualTo("PROFILE_CARD"))
                .assertNext(m -> assertThat(m.get("type")).isEqualTo("COMPLETE"))
                .verifyComplete();
    }

    @Test
    @DisplayName("updateProfile 应返回 SSE Flux<AgentEvent>")
    void updateProfile_shouldReturnFlux() {
        when(profileService.updateProfile(anyLong(), anyString(), anyString()))
                .thenReturn(Flux.just(
                        AgentEvent.builder().type(AgentEventType.COMPLETE.getCode()).summary("updated").build()
                ));

        ProfileController.ProfileBuildRequest body = new ProfileController.ProfileBuildRequest();
        body.setSessionId("s1");
        body.setMessage("更新");

        Flux<Map<String, Object>> result = profileController.updateProfile(request, body).getBody();

        StepVerifier.create(result)
                .assertNext(m -> assertThat(m.get("type")).isEqualTo("COMPLETE"))
                .verifyComplete();
    }
}