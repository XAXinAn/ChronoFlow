package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.service.SparkApiService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

/**
 * 思维导图生成Agent — 生成知识体系的树状结构化导图（JSON树/Markdown格式）。
 *
 * 输出：知识体系树状结构，易错点节点红色标记。
 * 个性化参数：无（结构统一）
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
        String topic = ctx.getUserMessage();

        String prompt = String.format("""
                请为知识点「%s」生成一份思维导图大纲。

                要求：
                1. 以树状结构组织知识体系
                2. 每个节点包含：名称 + 简要说明
                3. 用缩进表示层级关系（最多4层）
                4. 用 ⚠️ 标记易错/重点节点
                5. 最后生成一个Mermaid格式的mindmap代码块

                输出格式：
                - 先用缩进文本展示结构
                - 再用 ```mermaid mindmap``` 代码块展示可视化导图
                """, topic);

        return sparkApiService.chatStream("你是知识体系架构专家，擅长将复杂知识点组织为清晰的思维导图。",
                java.util.List.of(java.util.Map.of("role", "user", "content", prompt)))
                .map(text -> AgentEvent.builder().agent("MindMapAgent").type("TEXT").content(text).build())
                .startWith(AgentEvent.builder()
                        .type("RESOURCE_CARD")
                        .agent("MindMapAgent")
                        .title("🧠 思维导图 - " + topic)
                        .content("")
                        .build());
    }
}