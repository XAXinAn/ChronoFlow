package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.config.MindFlowConfig;
import com.chronoflow.backend.mindflow.service.SparkApiService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.Map;

/**
 * 编排智能体（P0核心）— 负责意图分类、Agent路由调度、结果流式汇总。
 *
 * 执行流程：
 * 1. 构建分类Prompt（含上下文 + 意图标签表）
 * 2. 调用星火API进行意图分类
 * 3. 根据分类结果路由到对应Agent
 * 4. 订阅Agent返回的Flux<AgentEvent>
 * 5. 封装为SSE事件流返回Controller
 *
 * 降级策略：
 * - 意图分类失败 → GENERAL_CHAT
 * - 置信度 < 0.5 → GENERAL_CHAT
 * - Agent异常 → 友好错误提示
 *
 * 意图标签：GENERAL_CHAT（兜底）
 */
@Slf4j
@Component
public class OrchestratorAgent implements MindFlowAgent {

    private final SparkApiService sparkApiService;
    private final AgentRegistry agentRegistry;
    private final MindFlowConfig config;

    public OrchestratorAgent(SparkApiService sparkApiService,
                             @Lazy AgentRegistry agentRegistry,
                             MindFlowConfig config) {
        this.sparkApiService = sparkApiService;
        this.agentRegistry = agentRegistry;
        this.config = config;
    }

    @Override
    public String getIntentLabel() {
        // 修复（vs HEAD）：返回内部标识 _ORCHESTRATOR，避免被 AgentRegistry 路由到自身造成无限递归
        return "_ORCHESTRATOR";
    }

    /**
     * Orchestrator的execute收到的是尚未分类的原始输入。
     * 因此本方法不是给AgentRegistry路由用的，而是作为入口方法由ChatService直接调用。
     *
     * 完整流程：分类 → 路由 → 流式输出
     */
    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        log.info("OrchestratorAgent 开始处理: userId={}, sessionId={}, message={}",
                ctx.getUserId(), ctx.getSessionId(), ctx.getUserMessage());

        // 简化响应式链，避免深层嵌套导致 StackOverflow
        return classifyAndRoute(ctx)
                .flatMapMany(result -> {
                    String label = (String) result.get("label");
                    double confidence = (double) result.get("confidence");
                    ctx.setIntentLabel(label);
                    ctx.setConfidence(confidence);
                    log.info("意图分类完成: label={}, confidence={}", label, confidence);

                    // 低置信度或无匹配Agent → 通用对话
                    if (confidence < 0.5 || agentRegistry.resolve(label).isEmpty()) {
                        log.warn("意图分类置信度过低({})或无匹配Agent，回退GENERAL_CHAT", confidence);
                        return handleGeneralChat(ctx);
                    }

                    // 路由到目标Agent
                    return agentRegistry.resolve(label)
                            .map(agent -> {
                                log.info("路由到Agent: {}", agent.getClass().getSimpleName());
                                return agent.execute(ctx)
                                        .onErrorResume(e -> {
                                            log.error("Agent执行异常: {}", e.getMessage(), e);
                                            return Flux.just(AgentEvent.builder()
                                                    .type("ERROR")
                                                    .content("AI服务暂时繁忙，请稍后重试")
                                                    .retryable(true)
                                                    .build());
                                        });
                            })
                            .orElseGet(() -> handleGeneralChat(ctx));
                })
                .onErrorResume(e -> {
                    log.error("编排异常: {}", e.getMessage(), e);
                    return Flux.just(AgentEvent.builder()
                            .type("ERROR")
                            .content("AI服务暂时繁忙，请稍后重试")
                            .retryable(true)
                            .build());
                });
    }

    /**
     * 调用星火API进行意图分类。
     */
    private Mono<Map<String, Object>> classifyAndRoute(AgentContext ctx) {
        return sparkApiService.classify(ctx.getUserMessage(), ctx.getConversationHistory())
                .timeout(Duration.ofMillis(config.getAgent().getIntentClassifyTimeoutMs()))
                .onErrorResume(e -> {
                    log.error("意图分类API调用失败: {}", e.getMessage());
                    return Mono.just(Map.of("label", "GENERAL_CHAT", "confidence", 0.0));
                });
    }

    /**
     * 通用对话处理 — 直接使用星火API进行流式对话。
     */
    private Flux<AgentEvent> handleGeneralChat(AgentContext ctx) {
        log.info("进入通用对话模式");

        var messages = new java.util.ArrayList<Map<String, String>>();
        if (ctx.getConversationHistory() != null) {
            for (String h : ctx.getConversationHistory()) {
                messages.add(Map.of("role", "user", "content", h));
            }
        }
        messages.add(Map.of("role", "user", "content", ctx.getUserMessage()));

        String systemPrompt = """
                你是智流（MindFlow）AI学习助手，具备以下能力：
                - 解答学科知识问题
                - 生成学习资料（讲解文档、思维导图、练习题、拓展材料、代码案例）
                - 构建和更新用户学习画像
                - 提供学习建议和指导

                回答要求：
                - 使用Markdown格式
                - 内容准确、清晰、有条理
                - 对于不确定的信息，标注"AI生成，请核实"
                """;

        return sparkApiService.chatStream(systemPrompt, messages)
                .map(text -> AgentEvent.builder()
                        .type("TEXT")
                        .content(text)
                        .build())
                .concatWith(Flux.just(AgentEvent.builder()
                        .type("COMPLETE")
                        .summary("对话完成")
                        .build()))
                .onErrorResume(e -> {
                    log.error("通用对话异常: {}", e.getMessage());
                    return Flux.just(AgentEvent.builder()
                            .type("ERROR")
                            .content("AI服务暂时繁忙，请稍后重试")
                            .retryable(true)
                            .build());
                });
    }
}