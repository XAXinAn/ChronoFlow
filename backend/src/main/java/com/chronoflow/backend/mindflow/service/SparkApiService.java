package com.chronoflow.backend.mindflow.service;

import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.mindflow.config.MindFlowConfig;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.publisher.FluxSink;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

/**
 * 讯飞星火 API 服务 — 封装星火大模型的HTTP调用。
 *
 * 使用 Java 11 内置 HttpClient 实现，无需额外依赖。
 * 支持：
 * - 同步对话（chat）
 * - 流式对话（chatStream）— 通过 SSE 逐行解析
 * - 意图分类（classify）
 *
 * API格式遵循 OpenAI 兼容接口：POST /v1/chat/completions
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SparkApiService {

    private final MindFlowConfig config;
    private final ObjectMapper objectMapper;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    /** 缓存的 API Key（启动时为空则在首次调用时校验报错） */
    private volatile String cachedApiKey;
    private volatile boolean apiKeyChecked;

    /**
     * 校验 API Key 是否已配置，未配置时抛出明确错误。
     */
    private void ensureApiKey() {
        if (apiKeyChecked) return;
        cachedApiKey = config.getSpark().getApiKey();
        apiKeyChecked = true;
        if (cachedApiKey == null || cachedApiKey.isBlank()) {
            throw new BusinessException("讯飞星火 API Key 未配置，请在 .env 中设置 SPARK_API_KEY");
        }
    }

    /**
     * 同步对话 — 发送消息并等待完整回复。
     *
     * @param systemPrompt 系统提示词
     * @param userMessage  用户消息
     * @return Mono包装的AI回复文本
     */
    public Mono<String> chat(String systemPrompt, String userMessage) {
        ensureApiKey();
        return Mono.fromCallable(() -> {
            Map<String, Object> body = buildChatBody(systemPrompt, List.of(
                    Map.of("role", "user", "content", userMessage)
            ), false);

            String jsonBody = objectMapper.writeValueAsString(body);
            HttpRequest request = buildRequest("/chat/completions", jsonBody);

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 200) {
                return extractContent(response.body());
            }
            log.error("星火API返回非200: status={}, body={}", response.statusCode(), response.body());
            return "";
        });
    }

    /**
     * 流式对话 — SSE 流式返回，用于对话界面的逐字渲染。
     *
     * @param systemPrompt 系统提示词
     * @param messages     对话历史（包含当前用户消息）
     * @return 流式文本片段 Flux<String>
     */
    public Flux<String> chatStream(String systemPrompt, List<Map<String, String>> messages) {
        ensureApiKey();
        return Flux.create(sink -> {
            try {
                Map<String, Object> body = buildChatBody(systemPrompt, messages, true);
                String jsonBody = objectMapper.writeValueAsString(body);
                HttpRequest request = buildRequest("/chat/completions", jsonBody);

                CompletableFuture<HttpResponse<java.io.InputStream>> future =
                        httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofInputStream());

                future.thenAccept(response -> {
                    if (response.statusCode() != 200) {
                        sink.error(new RuntimeException("星火API返回: " + response.statusCode()));
                        return;
                    }

                    try (var reader = new java.io.BufferedReader(
                            new java.io.InputStreamReader(response.body()))) {
                        String line;
                        while ((line = reader.readLine()) != null) {
                            if (line.startsWith("data: ") && !line.contains("[DONE]")) {
                                try {
                                    String json = line.substring(6).trim();
                                    if (json.isEmpty()) continue;
                                    JsonNode node = objectMapper.readTree(json);
                                    JsonNode choices = node.get("choices");
                                    if (choices != null && choices.isArray() && choices.size() > 0) {
                                        JsonNode delta = choices.get(0).get("delta");
                                        if (delta != null) {
                                            // spark-x 模型返回 reasoning_content（思考链）和 content（实际回复）
                                            String text = null;
                                            if (delta.has("content") && !delta.get("content").isNull()
                                                    && !delta.get("content").asText().isEmpty()) {
                                                text = delta.get("content").asText();
                                            }
                                            if ((text == null || text.isEmpty())
                                                    && delta.has("reasoning_content")
                                                    && !delta.get("reasoning_content").isNull()
                                                    && !delta.get("reasoning_content").asText().isEmpty()) {
                                                text = delta.get("reasoning_content").asText();
                                            }
                                            if (text != null && !text.isEmpty()) {
                                                sink.next(text);
                                            }
                                        }
                                    }
                                } catch (Exception e) {
                                    // 跳过无法解析的行
                                }
                            }
                        }
                        sink.complete();
                    } catch (Exception e) {
                        sink.error(e);
                    }
                }).exceptionally(e -> {
                    sink.error(e);
                    return null;
                });
            } catch (Exception e) {
                sink.error(e);
            }
        }, FluxSink.OverflowStrategy.BUFFER);
    }

    /**
     * 意图分类 — 根据用户输入和上下文判断意图标签。
     *
     * @param userMessage 用户输入
     * @param history     最近对话历史
     * @return 意图分类结果 {label: "RESOURCE_GEN", confidence: 0.95}
     */
    public Mono<Map<String, Object>> classify(String userMessage, List<String> history) {
        ensureApiKey();
        String prompt = buildClassifyPrompt(userMessage, history);

        return chat("你是一个意图分类助手，请根据用户输入判断其意图", prompt)
                .map(response -> {
                    try {
                        String json = extractJson(response);
                        JsonNode node = objectMapper.readTree(json);
                        return Map.<String, Object>of(
                                "label", node.has("label") ? node.get("label").asText() : "GENERAL_CHAT",
                                "confidence", node.has("confidence") ? node.get("confidence").asDouble() : 0.5
                        );
                    } catch (Exception e) {
                        log.warn("意图分类解析失败，回退GENERAL_CHAT: {}", e.getMessage());
                        return Map.<String, Object>of("label", "GENERAL_CHAT", "confidence", 0.3);
                    }
                })
                .timeout(Duration.ofMillis(config.getAgent().getIntentClassifyTimeoutMs()))
                .onErrorReturn(Map.of("label", "GENERAL_CHAT", "confidence", 0.0));
    }

    /**
     * 构建HTTP请求。
     */
    private HttpRequest buildRequest(String path, String jsonBody) {
        String baseUrl = config.getSpark().getBaseUrl();
        return HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + path))
                .header("Authorization", "Bearer " + cachedApiKey)
                .header("Content-Type", "application/json")
                .timeout(Duration.ofMillis(config.getAgent().getExecutionTimeoutMs()))
                .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
                .build();
    }

    /**
     * 构建意图分类提示词。
     */
    private String buildClassifyPrompt(String userMessage, List<String> history) {
        StringBuilder sb = new StringBuilder();
        sb.append("请分析以下用户输入，判断其意图并返回JSON格式结果。\n\n");
        sb.append("意图标签列表：\n");
        sb.append("- PROFILE_BUILD: 用户想开始学情测评、建立学习画像\n");
        sb.append("- PROFILE_VIEW: 用户想查看自己的学习画像\n");
        sb.append("- PROFILE_UPDATE: 用户想更新学习画像\n");
        sb.append("- RESOURCE_GEN: 用户想生成学习资料（如\"生成XX讲义\")\n");
        sb.append("- GENERAL_CHAT: 普通对话、问候、其他\n\n");
        sb.append("返回格式：{\"label\": \"意图标签\", \"confidence\": 0.0~1.0}\n");
        sb.append("只返回JSON，不要包含其他文字。\n\n");

        if (history != null && !history.isEmpty()) {
            sb.append("对话历史：\n");
            for (int i = Math.max(0, history.size() - 6); i < history.size(); i++) {
                sb.append(history.get(i)).append("\n");
            }
            sb.append("\n");
        }

        sb.append("用户输入：").append(userMessage).append("\n");
        sb.append("意图分类结果：");
        return sb.toString();
    }

    /**
     * 从AI回复中提取JSON片段。
     */
    private String extractJson(String response) {
        if (response == null || response.isEmpty()) return "{}";
        int start = response.indexOf('{');
        int end = response.lastIndexOf('}');
        if (start >= 0 && end > start) {
            return response.substring(start, end + 1);
        }
        return "{}";
    }

    /**
     * 从OpenAI兼容响应中提取content字段。
     */
    private String extractContent(String responseBody) {
        try {
            JsonNode root = objectMapper.readTree(responseBody);
            JsonNode choices = root.get("choices");
            if (choices != null && choices.isArray() && choices.size() > 0) {
                JsonNode message = choices.get(0).get("message");
                if (message != null) {
                    // spark-x 优先取 content，没有则取 reasoning_content
                    if (message.has("content") && !message.get("content").isNull()
                            && !message.get("content").asText().isEmpty()) {
                        return message.get("content").asText();
                    }
                    if (message.has("reasoning_content") && !message.get("reasoning_content").isNull()
                            && !message.get("reasoning_content").asText().isEmpty()) {
                        return message.get("reasoning_content").asText();
                    }
                }
            }
        } catch (Exception e) {
            log.warn("解析星火API响应失败: {}", e.getMessage());
        }
        return "";
    }

    /**
     * 构建OpenAI兼容的请求体。
     */
    private Map<String, Object> buildChatBody(String systemPrompt, List<Map<String, String>> messages, boolean stream) {
        List<Map<String, String>> allMessages = new java.util.ArrayList<>();
        if (systemPrompt != null && !systemPrompt.isEmpty()) {
            allMessages.add(Map.of("role", "system", "content", systemPrompt));
        }
        allMessages.addAll(messages);

        Map<String, Object> body = new java.util.LinkedHashMap<>();
        body.put("model", config.getSpark().getModel());
        body.put("messages", allMessages);
        body.put("temperature", config.getSpark().getTemperature());
        body.put("stream", stream);
        body.put("max_tokens", 4096);
        return body;
    }
}