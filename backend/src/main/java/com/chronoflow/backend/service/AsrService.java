package com.chronoflow.backend.service;

import com.chronoflow.backend.exception.BusinessException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

@Slf4j
@Service
public class AsrService {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final String DASHSCOPE_BASE_URL = "https://dashscope.aliyuncs.com/api/v1";

    @Value("${spring.ai.dashscope.api-key:}")
    private String apiKey;

    @Value("${voice.asr.model:paraformer-realtime-v2}")
    private String asrModel;

    @Value("${voice.asr.timeout-seconds:60}")
    private int timeoutSeconds;

    private final RestTemplate restTemplate = new RestTemplate();

    public String transcribe(String audioUrl) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new BusinessException("语音识别服务未配置，请设置DASHSCOPE_API_KEY");
        }

        try {
            CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> doTranscribe(audioUrl));
            try {
                return future.get(timeoutSeconds, TimeUnit.SECONDS);
            } catch (TimeoutException e) {
                future.cancel(true);
                throw new BusinessException("语音识别超时，请稍后重试");
            } catch (ExecutionException e) {
                Throwable cause = e.getCause();
                if (cause instanceof BusinessException) throw (BusinessException) cause;
                throw new BusinessException("语音识别失败，请重试");
            }
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("ASR transcribe failed: {}", e.getMessage());
            throw new BusinessException("语音识别失败，请重试");
        }
    }

    private String doTranscribe(String audioUrl) {
        String taskId = submitTranscriptionTask(audioUrl);
        String transcriptionUrl = pollTaskResult(taskId);
        return fetchTranscriptionText(transcriptionUrl);
    }

    private String submitTranscriptionTask(String audioUrl) {
        String url = DASHSCOPE_BASE_URL + "/services/audio/asr/transcription";

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(apiKey);

        String requestBody = String.format(
                "{\"model\":\"%s\",\"input\":{\"file_urls\":[\"%s\"]},\"parameters\":{\"language_hints\":[\"zh\"]}}",
                asrModel, audioUrl);

        try {
            ResponseEntity<String> response = restTemplate.exchange(
                    url, HttpMethod.POST, new HttpEntity<>(requestBody, headers), String.class);
            JsonNode root = OBJECT_MAPPER.readTree(response.getBody());
            JsonNode output = root.path("output");
            String taskId = output.path("task_id").asText();
            if (taskId == null || taskId.isEmpty()) {
                throw new BusinessException("语音识别任务提交失败");
            }
            log.info("ASR task submitted: taskId={}", taskId);
            return taskId;
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("ASR submit task failed: {}", e.getMessage());
            throw new BusinessException("语音识别服务调用失败，请重试");
        }
    }

    private String pollTaskResult(String taskId) {
        String url = DASHSCOPE_BASE_URL + "/tasks/" + taskId;
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(apiKey);

        // 轮询次数基于 timeoutSeconds 动态计算，轮询间隔 1 秒，总时长与超时阈值一致
        int maxRetries = timeoutSeconds;
        for (int i = 0; i < maxRetries; i++) {
            try {
                Thread.sleep(1000);
                ResponseEntity<String> response = restTemplate.exchange(
                        url, HttpMethod.GET, new HttpEntity<>(headers), String.class);
                JsonNode root = OBJECT_MAPPER.readTree(response.getBody());
                JsonNode output = root.path("output");
                String taskStatus = output.path("task_status").asText();

                if ("SUCCEEDED".equals(taskStatus)) {
                    JsonNode results = output.path("results");
                    if (results.isArray() && !results.isEmpty()) {
                        String transcriptionUrl = results.get(0).path("transcription_url").asText();
                        if (transcriptionUrl != null && !transcriptionUrl.isEmpty()) {
                            return transcriptionUrl;
                        }
                    }
                    throw new BusinessException("语音识别结果为空");
                } else if ("FAILED".equals(taskStatus)) {
                    throw new BusinessException("语音识别失败，请重试");
                }
            } catch (BusinessException e) {
                throw e;
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new BusinessException("语音识别被中断");
            } catch (Exception e) {
                log.warn("ASR poll attempt {} failed: {}", i + 1, e.getMessage());
            }
        }
        throw new BusinessException("语音识别超时，请稍后重试");
    }

    private String fetchTranscriptionText(String transcriptionUrl) {
        try {
            ResponseEntity<String> response = restTemplate.getForEntity(transcriptionUrl, String.class);
            JsonNode root = OBJECT_MAPPER.readTree(response.getBody());
            JsonNode transcripts = root.path("transcripts");
            if (transcripts.isArray() && !transcripts.isEmpty()) {
                StringBuilder sb = new StringBuilder();
                for (JsonNode transcript : transcripts) {
                    String text = transcript.path("text").asText();
                    if (!text.isEmpty()) {
                        if (sb.length() > 0) sb.append(" ");
                        sb.append(text);
                    }
                }
                return sb.toString().trim();
            }
            return "";
        } catch (Exception e) {
            log.error("ASR fetch transcription failed: {}", e.getMessage());
            throw new BusinessException("语音识别结果获取失败");
        }
    }
}