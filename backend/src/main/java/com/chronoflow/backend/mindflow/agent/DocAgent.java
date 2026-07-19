package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.service.SparkApiService;
import com.chronoflow.backend.mindflow.util.PromptGuard;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

/**
 * 讲解文档生成Agent — 生成知识点的结构化讲解文档（Markdown格式）。
 *
 * 安全特性：
 * - 用户输入经 PromptGuard 校验（防 prompt 注入）
 * - 用户输入用 XML 标签包裹（明确边界，防止混淆系统指令）
 *
 * 输出结构：概念引入 → 核心讲解 → 示例说明 → 常见误区 → 小结
 * 个性化参数：认知风格决定举例方式（visual用图示/verbal用类比/logical用推导/hands-on用实践）
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DocAgent implements MindFlowAgent {

    private final SparkApiService sparkApiService;

    @Override
    public String getIntentLabel() {
        return "DOC";
    }

    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        String rawTopic = ctx.getUserMessage();
        // 安全清洗：检测注入 + XML 包裹
        String topic = PromptGuard.sanitize(rawTopic);
        String searchContext = ctx.getResolvedParams() != null ? ctx.getResolvedParams() : "";

        String prompt = String.format("""
                你是一位优秀的教育内容创作者。请为知识点「%s」生成一份结构化的讲解文档。

                要求：
                1. **概念引入**：用生动的方式引入主题
                2. **核心讲解**：分层次、有条理地讲解核心概念和原理
                3. **示例说明**：提供2-3个具体示例帮助理解
                4. **常见误区**：列出学习中容易混淆或出错的地方
                5. **小结**：用简洁的语言总结要点

                输出格式：Markdown，使用标题层级、列表、代码块等格式化。
                请确保内容准确、清晰，适合自学使用。

                %s
                """, topic, searchContext);

        return sparkApiService.chatStream("你是一位专业的教育内容创作者，擅长编写清晰易懂的讲解文档。",
                java.util.List.of(java.util.Map.of("role", "user", "content", prompt)))
                .map(text -> AgentEvent.builder().agent("DocAgent").type(AgentEventType.TEXT.getCode()).content(text).build())
                .startWith(AgentEvent.builder()
                        .type(AgentEventType.RESOURCE_CARD.getCode())
                        .agent("DocAgent")
                        .title("\uD83D\uDCC4 讲解文档 - " + sanitizeForTitle(rawTopic))
                        .content("")
                        .build());
    }

    /** 标题清洗（防止超长或包含控制字符） */
    private String sanitizeForTitle(String s) {
        if (s == null) return "未命名";
        String cleaned = s.replaceAll("[\\x00-\\x1F]", "").trim();
        return cleaned.length() > 50 ? cleaned.substring(0, 50) + "..." : cleaned;
    }
}