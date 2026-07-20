package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.mindflow.agent.AgentEvent;
import com.chronoflow.backend.mindflow.dto.ProfileResponse;
import com.chronoflow.backend.mindflow.service.ProfileService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;

import java.util.Map;

/**
 * 画像控制器 — 六维学习画像的CRUD接口。
 *
 * 接口清单：
 * - GET   /api/v1/profile          获取当前画像
 * - POST  /api/v1/profile/build    开始画像构建对话（SSE）
 * - POST  /api/v1/profile/update   更新画像（SSE）
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/profile")
@RequiredArgsConstructor
public class ProfileController {

    private final ProfileService profileService;

    /**
     * 获取当前用户的学习画像。
     * GET /api/v1/profile
     */
    @GetMapping
    public ResponseEntity<ApiResponse<ProfileResponse>> getProfile(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        ProfileResponse profile = profileService.getProfile(userId);
        if (profile == null) {
            return ResponseEntity.ok(ApiResponse.success("暂无画像数据", null));
        }
        return ResponseEntity.ok(ApiResponse.success("查询成功", profile));
    }

    /**
     * 开始/继续画像构建对话（SSE流式）。
     * POST /api/v1/profile/build
     *
     * 通过多轮对话引导用户完成六维测评，逐步采集画像数据。
     */
    @PostMapping(value = "/build", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public ResponseEntity<Flux<Map<String, Object>>> buildProfile(
            HttpServletRequest request,
            @Valid @RequestBody ProfileBuildRequest body) {

        Long userId = (Long) request.getAttribute("userId");
        log.info("开始画像构建: userId={}", userId);

        Flux<Map<String, Object>> flux = profileService.buildProfile(userId, body.getSessionId(), body.getMessage())
                .map(this::toSseEvent);

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, "text/event-stream;charset=UTF-8")
                .body(flux);
    }

    /**
     * 更新画像（SSE流式）。
     * POST /api/v1/profile/update
     */
    @PostMapping(value = "/update", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public ResponseEntity<Flux<Map<String, Object>>> updateProfile(
            HttpServletRequest request,
            @Valid @RequestBody ProfileBuildRequest body) {

        Long userId = (Long) request.getAttribute("userId");
        log.info("画像更新: userId={}", userId);

        Flux<Map<String, Object>> flux = profileService.updateProfile(userId, body.getSessionId(), body.getMessage())
                .map(this::toSseEvent);

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, "text/event-stream;charset=UTF-8")
                .body(flux);
    }

    private Map<String, Object> toSseEvent(AgentEvent event) {
        Map<String, Object> map = new java.util.LinkedHashMap<>();
        map.put("type", event.getType());
        if (event.getContent() != null) map.put("content", event.getContent());
        if (event.getStage() != null) map.put("stage", event.getStage());
        if (event.getPercent() > 0) map.put("percent", event.getPercent());
        if (event.getExtra() != null) map.putAll(event.getExtra());
        return map;
    }

    @Data
    public static class ProfileBuildRequest {
        private String sessionId;
        @NotBlank(message = "消息不能为空")
        private String message;
    }
}