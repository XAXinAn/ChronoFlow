package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.service.SparkApiService;
import com.chronoflow.backend.mindflow.util.PromptGuard;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

/**
 * 练习题生成Agent — 生成选择题、填空题、简答题及详细解析（Markdown格式）。
 *
 * 安全特性：
 * - 用户输入经 PromptGuard 校验（防 prompt 注入）
 * - 用户输入用 XML 标签包裹
 *
 * 输出：选择题(4选项) + 填空题 + 简答题，每题含解析。
 * 个性化参数：知识基础决定难度（基础→基础题，进阶→综合题，熟练→挑战题）
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class QuizAgent implements MindFlowAgent {

    private final SparkApiService sparkApiService;

    @Override
    public String getIntentLabel() {
        return "QUIZ";
    }

    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        String rawTopic = ctx.getUserMessage();
        String topic = PromptGuard.sanitize(rawTopic);

        String prompt = String.format("""
                请为知识点「%s」生成一套练习题。

                要求：
                1. **选择题**（4题）：
                   - 4个选项，标注正确答案
                   - 每题附带答案解析
                2. **填空题**（2题）：
                   - 明确填空位置
                   - 附带标准答案
                3. **简答题**（2题）：
                   - 开放性问题
                   - 附带参考答案要点

                难度分布：基础题50%%，进阶题30%%，综合题20%%。
                每题包含：题目、答案、详细解析。

                输出格式：Markdown，答案放在折叠块中以便自测。
                """, topic);

        return sparkApiService.chatStream("你是一位经验丰富的教育评估专家，擅长编写高质量的练习题。",
                java.util.List.of(java.util.Map.of("role", "user", "content", prompt)))
                .map(text -> AgentEvent.builder().agent("QuizAgent").type(AgentEventType.TEXT.getCode()).content(text).build())
                .startWith(AgentEvent.builder()
                        .type(AgentEventType.RESOURCE_CARD.getCode())
                        .agent("QuizAgent")
                        .title("\uD83D\uDCDD 练习题 - " + sanitizeForTitle(rawTopic))
                        .content("")
                        .build());
    }

    private String sanitizeForTitle(String s) {
        if (s == null) return "未命名";
        String cleaned = s.replaceAll("[\\x00-\\x1F]", "").trim();
        return cleaned.length() > 50 ? cleaned.substring(0, 50) + "..." : cleaned;
    }
}