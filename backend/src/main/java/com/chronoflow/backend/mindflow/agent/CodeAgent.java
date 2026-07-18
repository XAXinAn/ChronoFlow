package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.service.SparkApiService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

/**
 * 代码案例生成Agent — 生成场景说明、分步实现、完整代码、扩展挑战（Markdown+代码块格式）。
 *
 * 输出结构：应用场景 → 分步实现 → 完整代码 → 扩展思考
 * 个性化参数：知识基础决定注释密度（入门→逐行注释，进阶→关键注释，熟练→核心逻辑注释）
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CodeAgent implements MindFlowAgent {

    private final SparkApiService sparkApiService;

    @Override
    public String getIntentLabel() {
        return "CODE";
    }

    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        String topic = ctx.getUserMessage();

        String prompt = String.format("""
                请为知识点「%s」生成一个代码实践案例。

                要求：
                1. **应用场景**：描述一个具体的编程场景，说明代码解决什么问题
                2. **分步实现**：
                   - 步骤1：环境准备/依赖导入
                   - 步骤2：核心逻辑实现（逐步讲解）
                   - 步骤3：测试验证
                3. **完整代码**：提供可直接运行的完整代码（带详细注释）
                4. **扩展挑战**：提出2-3个进阶练习方向

                代码语言：优先使用Python（适合教学），如知识点有特定语言则使用对应语言。
                注释密度：入门级（每行关键代码有注释）。

                输出格式：Markdown + 代码块。
                """, topic);

        return sparkApiService.chatStream("你是一位资深编程导师，擅长通过代码实践帮助学习者理解抽象概念。",
                java.util.List.of(java.util.Map.of("role", "user", "content", prompt)))
                .map(text -> AgentEvent.builder().agent("CodeAgent").type("TEXT").content(text).build())
                .startWith(AgentEvent.builder()
                        .type("RESOURCE_CARD")
                        .agent("CodeAgent")
                        .title("💻 代码案例 - " + topic)
                        .content("")
                        .build());
    }
}