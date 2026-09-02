package com.chronoflow.backend.service;

import com.chronoflow.backend.dto.NotificationParseResult;
import com.chronoflow.backend.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Slf4j
@Service
public class VoiceService {

    private final AsrService asrService;
    private final MinioService minioService;
    private final NotificationAiService notificationAiService;

    @Value("${voice.max-size-mb:10}")
    private int maxSizeMb;

    @Value("${voice.supported-formats:amr,mp3,wav,m4a}")
    private String supportedFormats;

    public VoiceService(@Autowired AsrService asrService,
                        @Autowired MinioService minioService,
                        @Autowired(required = false) NotificationAiService notificationAiService) {
        this.asrService = asrService;
        this.minioService = minioService;
        this.notificationAiService = notificationAiService;
    }

    public List<NotificationParseResult> recognize(Long userId, MultipartFile file) {
        long startTime = System.currentTimeMillis();

        String originalFilename = file.getOriginalFilename();
        String ext = extractExtension(originalFilename);
        validateFormat(ext);
        validateSize(file.getSize());

        try {
            byte[] audioBytes = file.getBytes();
            String audioUrl = minioService.uploadAudio(audioBytes, userId, ext);
            log.info("语音上传成功: userId={}, url={}", userId, audioUrl);

            String transcribedText = asrService.transcribe(audioUrl);
            log.info("ASR转写完成: userId={}, 文本长度={}", userId, transcribedText.length());

            if (transcribedText.isBlank()) {
                log.info("语音转写结果为空: userId={}", userId);
                return Collections.emptyList();
            }

            if (notificationAiService == null) {
                throw new BusinessException("AI服务未配置，无法解析日程");
            }

            List<NotificationParseResult> results = notificationAiService.parseNotification(transcribedText);
            List<NotificationParseResult> deduped = deduplicate(results);

            long costMs = System.currentTimeMillis() - startTime;
            log.info("语音识别完成: userId={}, 结果数={}, 耗时={}ms", userId, deduped.size(), costMs);

            return deduped;
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("语音识别失败: userId={}, error={}", userId, e.getMessage());
            throw new BusinessException("语音识别失败，请重试");
        }
    }

    private String extractExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            throw new BusinessException("无法识别音频文件格式");
        }
        return filename.substring(filename.lastIndexOf('.') + 1).toLowerCase();
    }

    private void validateFormat(String ext) {
        Set<String> supported = new HashSet<>(List.of(supportedFormats.split(",")));
        if (!supported.contains(ext)) {
            throw new BusinessException("不支持的音频格式，支持 amr/mp3/wav/m4a");
        }
    }

    private void validateSize(long size) {
        long maxBytes = (long) maxSizeMb * 1024 * 1024;
        if (size > maxBytes) {
            throw new BusinessException("音频文件过大，上限 " + maxSizeMb + "MB");
        }
    }

    private List<NotificationParseResult> deduplicate(List<NotificationParseResult> results) {
        List<NotificationParseResult> deduped = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (NotificationParseResult r : results) {
            String key = (r.getTitle() == null ? "" : r.getTitle()) + "|"
                    + (r.getEventDate() == null ? "" : r.getEventDate()) + "|"
                    + (r.getEventTime() == null ? "" : r.getEventTime());
            if (seen.add(key)) {
                deduped.add(r);
            }
        }
        return deduped;
    }

}