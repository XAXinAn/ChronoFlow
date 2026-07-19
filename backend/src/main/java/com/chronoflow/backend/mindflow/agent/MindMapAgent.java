package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.service.SparkApiService;
import com.chronoflow.backend.mindflow.util.PromptGuard;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

/**
 * 思维导图生成Agent — 生成知识点的思维导图（Markdown缩进 + Mermaid代码块）。
 *
 * 安全特性：
 * - 用户输入经 PromptGuard 校验（防 prompt 注入）
 * - 用户输入用 XML 标签包裹
 *
 * 输出结构：中心主题 → 主要分支 → 子主题 → 关键点
 * 个性化参数：知识基础决定深度（基础→3层，进阶→4层，熟练→5层）
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class MindMapAgent implements MindFlowAgent {

    private final SparkApiService sparkApiService;

    @Override
    public String getIntentLabel() {
        return "MINDMAP";
    }

    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        String rawTopic = ctx.getUserMessage();
        String topic = PromptGuard.sanitize(rawTopic);

        String prompt = String.format("""
                请为知识点「%s」生成一份结构化的思维导图。

                要求：
                1. **中心主题**：明确核心概念
                2. **主要分支**（3-5个）：知识体系的主要维度
                3. **子主题**：每个分支下的关键点
                4. **关键点**：具体的事实或细节
                5. 重点、易错点用 ⭐ 标记易错/重点节点

                输出格式：
                - 先用缩进文本展示结构
                - 再用 ```mermaid mindmap``` 代码块展示可视化导图
                """, topic);

        return sparkApiService.chatStream("你是知识体系架构专家，擅长将复杂知识点组织为清晰的思维导图。",
                java.util.List.of(java.util.Map.of("role", "user", "content", prompt)))
                .map(text -> AgentEvent.builder().agent("MindMapAgent").type(AgentEventType.TEXT.getCode()).content(text).build())
                .startWith(AgentEvent.builder()
                        .type(AgentEventType.RESOURCE_CARD.getCode())
                        .agent("MindMapAgent")
                        .title("\uD83E\uDDE0 思维导图 - " + sanitizeForTitle(rawTopic))
                        .content("")
                        .build());
    }

    private String sanitizeForTitle(String s) {
        if (s == null) return "未命名";
        String cleaned = s.replaceAll("[\\x00-\\x1F]", "").trim();
        return cleaned.length() > 50 ? cleaned.substring(0, 50) + "..." : cleaned;
    }
}