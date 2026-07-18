package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.service.SparkApiService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

/**
 * 拓展材料生成Agent — 生成知识背景、进阶概念、应用场景、推荐资源（Markdown格式）。
 *
 * 输出结构：知识背景 → 进阶概念 → 实际应用 → 推荐阅读资源
 * 个性化参数：兴趣方向决定举例场景
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ReadingAgent implements MindFlowAgent {

    private final SparkApiService sparkApiService;

    @Override
    public String getIntentLabel() {
        return "READING";
    }

    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        String topic = ctx.getUserMessage();

        String prompt = String.format("""
                请为知识点「%s」生成一份拓展阅读材料。

                要求：
                1. **知识背景**：该知识点的历史渊源、发展脉络
                2. **进阶概念**：相关的进阶知识和前沿研究方向
                3. **实际应用**：在工业界/学术界的具体应用案例（2-3个）
                4. **推荐资源**：
                   - 经典教材/书籍
                   - 优质在线课程
                   - 相关论文/文章
                   - 实践项目建议

                输出格式：Markdown，使用层次化结构组织。
                内容应激发学习兴趣，拓展知识视野。
                """, topic);

        return sparkApiService.chatStream("你是一位博学的知识拓展专家，善于引导学生探索知识的深度与广度。",
                java.util.List.of(java.util.Map.of("role", "user", "content", prompt)))
                .map(text -> AgentEvent.builder().agent("ReadingAgent").type("TEXT").content(text).build())
                .startWith(AgentEvent.builder()
                        .type("RESOURCE_CARD")
                        .agent("ReadingAgent")
                        .title("📖 拓展材料 - " + topic)
                        .content("")
                        .build());
    }
}