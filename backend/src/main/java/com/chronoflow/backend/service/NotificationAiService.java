package com.chronoflow.backend.service;

import com.alibaba.cloud.ai.graph.agent.ReactAgent;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.dto.NotificationParseResult;
import com.chronoflow.backend.dto.NotificationParseResultList;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import java.util.List;

@Slf4j
@Service
public class NotificationAiService {

    private final ChatModel chatModel;

    public NotificationAiService(@Autowired(required = false) ChatModel chatModel) {
        this.chatModel = chatModel;
        if (chatModel == null) {
            log.error("ChatModel not available - AI notification parsing will not work. Check DASHSCOPE_API_KEY.");
        }
    }

    private static final String SYSTEM_PROMPT = """
            你是日程提取专家，将OCR文本精准转化为结构化日程JSON。

            输出字段：title(标题), eventDate(日期YYYY-MM-DD), eventTime(时间HH:mm), location(地点), remark(备注), category(学习/工作/生活)。

            核心规则：
            1. title：必填，从OCR提取核心事件名，简洁清晰（如"项目评审会""牙医预约"）
            2. eventDate：必填，格式YYYY-MM-DD
               - 有年份直接提取（如"2026年3月20日"→2026-03-20）
               - 只有月日（如"3月20日"）→补充当前年份；若已过则用明年
               - 相对时间："下周三"→下周三的日期，"明天"→明天的日期，"后天"→后天的日期，"本周四"→本周四的日期
               - 完全无日期→当前日期{CURRENT_DATE}
            3. eventTime：必填，格式HH:mm
               - 有时段按默认时间：上午→09:00，下午→14:00，晚上→19:00
               - 模糊时间："下午3点"→15:00，"今晚8点"→20:00
               - 完全无时间→根据上下文推算，实在无法推断才用当前系统时间（参考{CURRENT_DATETIME}）
            4. location：提取具体地点，未提及填null
            5. remark：**必填**，有明确描述提取，无明确内容填"无补充信息"，禁止留空
            6. category：根据内容判断，学习→"学习"，工作→"工作"，其他→"生活"

            多事件：OCR含多个独立事件时（如"上午9点开会，下午2点见客户"），返回JSON数组，每个事件独立一条

            输出要求：纯JSON字符串，无Markdown、无注释、无空格。字段不可缺失，remark和eventTime禁止返回null。
            """;

    private static final String OUTPUT_SCHEMA = """
            {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "title": {"type": "string"},
                  "eventDate": {"type": "string"},
                  "eventTime": {"type": "string"},
                  "location": {"type": "string"},
                  "remark": {"type": "string"},
                  "category": {"type": "string"}
                },
                "required": ["title", "eventDate", "eventTime", "remark", "category"]
              }
            }
            """;

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    public List<NotificationParseResult> parseNotification(String ocrText) {
        LocalDateTime startTime = LocalDateTime.now();
        String startTimeStr = startTime.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS"));
        log.info("[AI解析开始] 时间: {}, 文本长度: {} 字符", startTimeStr, ocrText.length());

        String promptText = SYSTEM_PROMPT
                .replace("{CURRENT_DATE}", startTime.format(DateTimeFormatter.ofPattern("yyyy年MM月dd日")))
                .replace("{CURRENT_DATETIME}", startTimeStr.substring(0, 16));

        try {
            ReactAgent agent = ReactAgent.builder()
                    .name("notification-parser")
                    .description("日程提取Agent")
                    .model(chatModel)
                    .outputSchema(OUTPUT_SCHEMA)
                    .build();
            agent.setSystemPrompt(promptText);

            // Wrap AI call with timeout to prevent indefinite blocking
            CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> {
                try {
                    AssistantMessage response = agent.call(new UserMessage(ocrText));
                    return response.getText();
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            });
            String resultJson;
            try {
                resultJson = future.get(60, TimeUnit.SECONDS);
            } catch (TimeoutException e) {
                future.cancel(true);
                throw new BusinessException("AI服务响应超时，请稍后重试");
            } catch (ExecutionException e) {
                Throwable cause = e.getCause();
                if (cause instanceof BusinessException) throw (BusinessException) cause;
                throw new BusinessException("AI服务调用异常: " + cause.getMessage(), e);
            }

            LocalDateTime endTime = LocalDateTime.now();
            String endTimeStr = endTime.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS"));
            log.info("[AI解析结束] 时间: {}, 耗时: {}ms", endTimeStr,
                    java.time.Duration.between(startTime, endTime).toMillis());
            log.info("[AI响应内容] {}", resultJson);

            return parseJsonResult(resultJson);
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            LocalDateTime errorTime = LocalDateTime.now();
            String errorTimeStr = errorTime.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS"));
            log.error("[AI解析异常] 第一帧: {}, 最后一帧: {}, 错误: {}",
                    startTimeStr, errorTimeStr, e.getMessage());
            throw new BusinessException("通知解析失败: " + e.getMessage(), e);
        }
    }

    private List<NotificationParseResult> parseJsonResult(String json) {
        try {
            NotificationParseResultList listResult = OBJECT_MAPPER.readValue(json, NotificationParseResultList.class);
            return listResult.getItems();
        } catch (Exception e1) {
            try {
                return OBJECT_MAPPER.readValue(json, new com.fasterxml.jackson.core.type.TypeReference<List<NotificationParseResult>>() {});
            } catch (Exception e2) {
                try {
                    NotificationParseResult single = OBJECT_MAPPER.readValue(json, NotificationParseResult.class);
                    return List.of(single);
                } catch (Exception e3) {
                    log.error("[JSON解析失败] json: {}", json);
                    throw new BusinessException("JSON解析失败: " + e3.getMessage(), e3);
                }
            }
        }
    }
}
