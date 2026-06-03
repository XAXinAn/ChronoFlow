package com.chronoflow.backend.service;

import com.chronoflow.backend.dto.NotificationParseRequest;
import com.chronoflow.backend.dto.NotificationParseResult;
import com.chronoflow.backend.dto.ScheduleRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Collections;

import java.util.List;

@Slf4j
@Service
public class NotificationService {

    private final NotificationAiService notificationAiService;
    private final ScheduleService scheduleService;

    public NotificationService(
            @Autowired(required = false) NotificationAiService notificationAiService,
            ScheduleService scheduleService) {
        this.notificationAiService = notificationAiService;
        this.scheduleService = scheduleService;
    }

    public List<NotificationParseResult> parse(Long userId, NotificationParseRequest request) {
        if (notificationAiService == null) {
            log.warn("AI notification service not configured, returning empty results");
            return Collections.emptyList();
        }

        long startTime = System.currentTimeMillis();
        String ocrText = request.getOcrText();
        log.info("[后端解析开始] userId={}, OCR文本长度: {} 字符", userId, ocrText.length());

        List<NotificationParseResult> parseResults = notificationAiService.parseNotification(ocrText);

        long endTime = System.currentTimeMillis();
        log.info("[后端解析完成] userId={}, 共{}个日程, 后端耗时: {}ms", userId, parseResults.size(), (endTime - startTime));

        return parseResults;
    }

    /**
     * Parse and create schedules. Each schedule created individually.
     * AI call is outside any transaction.
     */
    public List<NotificationParseResult> parseAndCreateSchedules(Long userId, NotificationParseRequest request) {
        if (notificationAiService == null) {
            log.warn("AI notification service not configured, returning empty results");
            return Collections.emptyList();
        }

        String ocrText = request.getOcrText();
        log.info("[收到解析请求] userId={}, OCR文本: {}", userId, ocrText);

        List<NotificationParseResult> parseResults = notificationAiService.parseNotification(ocrText);

        for (int i = 0; i < parseResults.size(); i++) {
            NotificationParseResult parseResult = parseResults.get(i);
            if (parseResult.getTitle() != null && !parseResult.getTitle().isBlank()) {
                try {
                    LocalDate eventDate = LocalDate.now();
                    if (parseResult.getEventDate() != null && !parseResult.getEventDate().isBlank()) {
                        try {
                            eventDate = LocalDate.parse(parseResult.getEventDate());
                        } catch (Exception e) {
                            log.warn("[日期解析失败，使用当前日期] title={}", parseResult.getTitle());
                            parseResult.setRemark((parseResult.getRemark() != null ? parseResult.getRemark() : "")
                                    + " [日期解析失败，已使用当前日期]");
                        }
                    }

                    LocalTime eventTime = LocalTime.of(9, 0);
                    if (parseResult.getEventTime() != null && !parseResult.getEventTime().isBlank()) {
                        try {
                            eventTime = LocalTime.parse(parseResult.getEventTime());
                        } catch (Exception e) {
                            log.warn("[时间解析失败，使用默认时间] title={}", parseResult.getTitle());
                            parseResult.setRemark((parseResult.getRemark() != null ? parseResult.getRemark() : "")
                                    + " [时间解析失败，已使用默认时间09:00]");
                        }
                    }

                    LocalDateTime scheduleTime = LocalDateTime.of(eventDate, eventTime);

                    ScheduleRequest scheduleRequest = ScheduleRequest.builder()
                            .title(parseResult.getTitle().trim())
                            .description(parseResult.getRemark() != null ? parseResult.getRemark() : "")
                            .location(parseResult.getLocation() != null ? parseResult.getLocation() : "")
                            .time(scheduleTime)
                            .build();

                    scheduleService.createSchedule(userId, scheduleRequest);
                    log.info("[解析并创建日程] userId={}, title={}, time={}", userId, parseResult.getTitle(), scheduleTime);
                } catch (Exception e) {
                    log.error("[创建日程失败] userId={}, title={}, error={}", userId, parseResult.getTitle(), e.getMessage());
                    parseResult.setRemark((parseResult.getRemark() != null ? parseResult.getRemark() : "")
                            + " [创建失败: " + e.getMessage() + "]");
                }
            } else {
                log.warn("[解析结果无有效标题，跳过创建日程] title={}", parseResult.getTitle());
            }
        }

        return parseResults;
    }
}
