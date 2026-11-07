package com.chronoflow.backend.service;

import com.chronoflow.backend.exception.BusinessException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;
import okio.ByteString;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.nio.ByteBuffer;
import java.util.LinkedHashMap;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeoutException;

@Slf4j
@Service
public class AsrService {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final String DASHSCOPE_BASE_URL = "https://dashscope.aliyuncs.com/api/v1";
    private static final String DASHSCOPE_WS_URL = "wss://dashscope.aliyuncs.com/api-ws/v1/inference/";

    private static final OkHttpClient HTTP_CLIENT = new OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .pingInterval(20, TimeUnit.SECONDS)
            .build();

    @Value("${spring.ai.dashscope.api-key:}")
    private String apiKey;

    @Value("${voice.asr.model:paraformer-realtime-v2}")
    private String asrModel;

    @Value("${voice.asr.timeout-seconds:60}")
    private int timeoutSeconds;

    private final RestTemplate restTemplate = new RestTemplate();

    // =====================================================================================
    // 实时 WebSocket ASR（paraformer-realtime-v2）：直接把音频字节流式发给 DashScope，
    // 无需公网可访问的音频 URL，本地/部署均可使用。
    // =====================================================================================
    public String transcribe(byte[] audioBytes, String format) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new BusinessException("语音识别服务未配置，请设置DASHSCOPE_API_KEY");
        }
        if (audioBytes == null || audioBytes.length == 0) {
            throw new BusinessException("音频数据为空");
        }
        String fmt = normalizeFormat(format);
        // 实时 ASR 仅可靠支持 wav/pcm 流式解码；m4a/amr 等压缩容器先转码为 wav(16kHz 单声道 PCM)
        byte[] sendBytes = audioBytes;
        String sendFmt = fmt;
        if (!"wav".equals(fmt) && !"pcm".equals(fmt)) {
            sendBytes = convertToWav(audioBytes, fmt);
            sendFmt = sendBytes == audioBytes ? fmt : "wav";
        }
        log.info("实时ASR开始: 原始字节={}, format={}, 发送字节={}, sendFmt={}, model={}",
                audioBytes.length, fmt, sendBytes.length, sendFmt, asrModel);
        try {
            return doRealtimeTranscribe(sendBytes, sendFmt);
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("实时ASR失败: {}", e.getMessage());
            throw new BusinessException("语音识别失败，请重试");
        }
    }

    /** 用 jave2(ffmpeg)把音频转码为 wav(16kHz 单声道 PCM 16bit)，供实时 ASR 使用。失败则返回原字节。 */
    private byte[] convertToWav(byte[] audioBytes, String ext) {
        java.nio.file.Path inPath = null, outPath = null;
        try {
            inPath = java.nio.file.Files.createTempFile("chronoflow-asr-in-", "." + ext);
            outPath = java.nio.file.Files.createTempFile("chronoflow-asr-out-", ".wav");
            java.nio.file.Files.write(inPath, audioBytes);
            ws.schild.jave.encode.AudioAttributes audio = new ws.schild.jave.encode.AudioAttributes();
            audio.setCodec("pcm_s16le");
            audio.setSamplingRate(16000);
            audio.setChannels(1);
            ws.schild.jave.encode.EncodingAttributes attrs = new ws.schild.jave.encode.EncodingAttributes();
            attrs.setAudioAttributes(audio);
            attrs.setOutputFormat("wav");
            new ws.schild.jave.Encoder().encode(new ws.schild.jave.MultimediaObject(inPath.toFile()), outPath.toFile(), attrs);
            byte[] wav = java.nio.file.Files.readAllBytes(outPath);
            log.info("音频转码成功: {} -> wav, {} 字节 -> {} 字节", ext, audioBytes.length, wav.length);
            return wav;
        } catch (Exception e) {
            log.error("音频转码失败({}): {}, 将用原始音频尝试ASR", ext, e.getMessage());
            return audioBytes;
        } finally {
            try { if (inPath != null) java.nio.file.Files.deleteIfExists(inPath); } catch (Exception ignored) { }
            try { if (outPath != null) java.nio.file.Files.deleteIfExists(outPath); } catch (Exception ignored) { }
        }
    }

    private String normalizeFormat(String ext) {
        if (ext == null) return "pcm";
        String e = ext.toLowerCase().trim().replace(".", "");
        return switch (e) {
            case "m4a", "amr", "mp3", "wav", "aac", "flac", "ogg", "opus" -> e;
            default -> "pcm";
        };
    }

    private String doRealtimeTranscribe(byte[] audioBytes, String format) {
        String taskId = UUID.randomUUID().toString().replace("-", "");
        LinkedHashMap<Integer, String> sentences = new LinkedHashMap<>();
        CompletableFuture<Void> done = new CompletableFuture<>();

        // DashScope 实时 ASR WebSocket 仅接受 Authorization: bearer <key> 头（query 参数会 401）
        Request request = new Request.Builder()
                .url(DASHSCOPE_WS_URL)
                .header("Authorization", "bearer " + apiKey)
                .header("X-DashScope-DataInspection", "enable")
                .build();

        final WebSocket ws = HTTP_CLIENT.newWebSocket(request, new WebSocketListener() {
            @Override
            public void onOpen(WebSocket webSocket, Response response) {
                try {
                    // 1) run-task（input 必须在 payload 内部）
                    var header = java.util.Map.of("action", "run-task", "task_id", taskId, "streaming", "duplex");
                    var parameters = new java.util.LinkedHashMap<String, Object>();
                    parameters.put("format", format);
                    parameters.put("sample_rate", 16000);
                    parameters.put("language_hints", java.util.List.of("zh"));
                    var payload = new java.util.LinkedHashMap<String, Object>();
                    payload.put("model", asrModel);
                    payload.put("task_group", "audio");
                    payload.put("task", "asr");
                    payload.put("function", "recognition");
                    payload.put("input", java.util.Map.of());
                    payload.put("parameters", parameters);
                    var runTask = java.util.Map.of("header", header, "payload", payload);
                    webSocket.send(OBJECT_MAPPER.writeValueAsString(runTask));

                    // 2) 流式发送音频（分块二进制帧）
                    int chunkSize = 16384;
                    for (int off = 0; off < audioBytes.length; off += chunkSize) {
                        int end = Math.min(off + chunkSize, audioBytes.length);
                        webSocket.send(ByteString.of(audioBytes, off, end - off));
                    }

                    // 3) finish-task（同样需要 payload.input）
                    var finishTask = java.util.Map.of(
                            "header", java.util.Map.of("action", "finish-task", "task_id", taskId, "streaming", "duplex"),
                            "payload", java.util.Map.of("input", java.util.Map.of()));
                    webSocket.send(OBJECT_MAPPER.writeValueAsString(finishTask));
                } catch (Exception e) {
                    if (!done.isDone()) {
                        done.completeExceptionally(new BusinessException("语音识别请求构造失败：" + e.getMessage()));
                    }
                }
            }

            @Override
            public void onMessage(WebSocket webSocket, String text) {
                try {
                    JsonNode root = OBJECT_MAPPER.readTree(text);
                    JsonNode headerNode = root.path("header");
                    String event = headerNode.path("event").asText("");
                    switch (event) {
                        case "result-generated":
                            JsonNode sentence = root.path("payload").path("output").path("sentence");
                            int sid = sentence.path("sentence_id").asInt(0);
                            String t = sentence.path("text").asText("");
                            if (!t.isEmpty()) {
                                // 实时 API 对同一句会发多次增量（text 为该句累计文本），取最新值即可
                                sentences.put(sid, t);
                            }
                            break;
                        case "task-finished":
                            done.complete(null);
                            break;
                        case "task-failed":
                            String err = headerNode.path("error_message").asText("");
                            if (err.isEmpty()) err = headerNode.path("message").asText("请重试");
                            if (!done.isDone()) {
                                done.completeExceptionally(new BusinessException("语音识别失败：" + err));
                            }
                            break;
                        default:
                            break;
                    }
                } catch (Exception e) {
                    if (!done.isDone()) {
                        done.completeExceptionally(new BusinessException("语音识别结果解析失败"));
                    }
                }
            }

            @Override
            public void onFailure(WebSocket webSocket, Throwable t, Response response) {
                String body = "";
                int code = -1;
                if (response != null) {
                    code = response.code();
                    if (response.body() != null) {
                        try { body = response.body().string(); } catch (Exception ignored) { }
                    }
                }
                log.error("ASR WebSocket onFailure: code={}, body={}, err={}", code, body, t == null ? "" : t.getMessage());
                if (!done.isDone()) {
                    String msg = response != null ? ("语音识别连接失败：" + code + " " + body) : ("语音识别连接失败：" + (t == null ? "" : t.getMessage()));
                    done.completeExceptionally(new BusinessException(msg));
                }
            }

            @Override
            public void onClosed(WebSocket webSocket, int code, String reason) {
                if (!done.isDone()) {
                    done.complete(null);
                }
            }
        });

        try {
            done.get(timeoutSeconds, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            ws.cancel();
            throw new BusinessException("语音识别超时，请稍后重试");
        } catch (ExecutionException e) {
            Throwable cause = e.getCause();
            if (cause instanceof BusinessException) throw (BusinessException) cause;
            throw new BusinessException("语音识别失败，请重试");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new BusinessException("语音识别被中断");
        } finally {
            ws.close(1000, "chronoflow-asr-done");
        }

        StringBuilder sb = new StringBuilder();
        for (String s : sentences.values()) {
            sb.append(s);
        }
        String result = sb.toString().trim();
        log.info("实时ASR完成: 句子数={}, 文本长度={}", sentences.size(), result.length());
        return result;
    }

    // =====================================================================================
    // 离线录音文件转写（paraformer-v2，需音频公网 URL）—— 部署到公网、MinIO 公网可访问时可用
    // =====================================================================================
    public String transcribe(String audioUrl) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new BusinessException("语音识别服务未配置，请设置DASHSCOPE_API_KEY");
        }
        if (audioUrl == null || audioUrl.isBlank()) {
            throw new BusinessException("音频地址无效");
        }
        // DashScope 云端需通过公网拉取音频文件，本地 localhost 地址无法被其服务器访问
        if (audioUrl.contains("localhost") || audioUrl.contains("127.0.0.1")) {
            throw new BusinessException("语音识别需要公网可访问的音频地址：请将项目部署到公网服务器，并将 MINIO_BASE_URL 设置为公网可访问的 MinIO 地址（当前音频地址为本地 " + audioUrl + "）");
        }

        try {
            CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> doOfflineTranscribe(audioUrl));
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

    private String doOfflineTranscribe(String audioUrl) {
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
                String code = root.path("code").asText("");
                String msg = root.path("message").asText("");
                String detail = !msg.isEmpty() ? msg : (!code.isEmpty() ? code : "请重试");
                throw new BusinessException("语音识别任务提交失败：" + detail);
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
                    String err = output.path("message").asText("");
                    throw new BusinessException("语音识别失败：" + (err == null || err.isEmpty() ? "请重试" : err));
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
