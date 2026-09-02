package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.dto.NotificationParseResult;
import com.chronoflow.backend.service.VoiceService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/voice")
public class VoiceController {

    private final VoiceService voiceService;

    public VoiceController(@Autowired VoiceService voiceService) {
        this.voiceService = voiceService;
    }

    @PostMapping(value = "/recognize", consumes = "multipart/form-data")
    public ResponseEntity<ApiResponse<List<NotificationParseResult>>> recognize(
            HttpServletRequest request,
            @RequestParam("file") MultipartFile file) {

        Long userId = (Long) request.getAttribute("userId");
        log.debug("收到语音识别请求: userId={}, 文件大小={}bytes", userId, file.getSize());

        List<NotificationParseResult> results = voiceService.recognize(userId, file);
        String message = results.isEmpty() ? "未识别到有效语音内容" : "语音识别成功";
        return ResponseEntity.ok(ApiResponse.success(message, results));
    }
}