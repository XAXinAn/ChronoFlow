package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.dto.NotificationParseRequest;
import com.chronoflow.backend.dto.NotificationParseResult;
import com.chronoflow.backend.service.NotificationService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Collections;
import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/notification")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(@Autowired(required = false) NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @PostMapping("/parse")
    public ResponseEntity<ApiResponse<List<NotificationParseResult>>> parseNotification(
            HttpServletRequest request,
            @Valid @RequestBody NotificationParseRequest notificationRequest) {

        if (notificationService == null) {
            return ResponseEntity.ok(ApiResponse.success("AI服务未配置", Collections.emptyList()));
        }
        Long userId = getUserIdFromRequest(request);
        log.debug("收到通知解析请求: userId={}", userId);

        List<NotificationParseResult> results = notificationService.parse(userId, notificationRequest);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("解析成功", results));
    }

    @PostMapping("/parse-only")
    public ResponseEntity<ApiResponse<List<NotificationParseResult>>> parseOnly(
            HttpServletRequest request,
            @Valid @RequestBody NotificationParseRequest notificationRequest) {

        if (notificationService == null) {
            return ResponseEntity.ok(ApiResponse.success("AI服务未配置", Collections.emptyList()));
        }
        long startTime = System.currentTimeMillis();
        Long userId = getUserIdFromRequest(request);
        log.debug("[HTTP收到请求] /parse-only, userId={}, 文本长度: {} 字符", userId, notificationRequest.getOcrText().length());

        List<NotificationParseResult> results = notificationService.parse(userId, notificationRequest);

        long endTime = System.currentTimeMillis();
        log.info("[HTTP请求完成] /parse-only, userId={}, 解析结果: {}个日程, HTTP总耗时: {}ms", userId, results.size(), (endTime - startTime));

        return ResponseEntity.ok(ApiResponse.success("解析成功", results));
    }

    private Long getUserIdFromRequest(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }
}