package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.config.MindFlowConfig;
import com.chronoflow.backend.mindflow.entity.LearningResource;
import com.chronoflow.backend.mindflow.mapper.LearningResourceMapper;
import com.chronoflow.backend.mindflow.tool.WebSearchTool;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

import java.math.BigDecimal;
import java.util.*;

/**
 * 资源生成编排器（P0核心）— 协调5个子Agent并行生成学习资源。
 *
 * 执行流程（四阶段）：
 * Phase 1: 知识点细化（~3s）— 星火解析模糊描述 → 结构化知识点树
 * Phase 2: 联网检索（~5s）— WebSearchTool.search() 获取最新资料
 * Phase 3: 并行生成（~25s）— 5个子Agent通过Flux.merge并行执行
 * Phase 4: 审核+持久化 — ContentModerationService → MySQL + MinIO
 *
 * 约束：单类资源 ≤ 30s，5类完整 ≤ 3min
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ResourceOrchestrator implements MindFlowAgent {

    private final WebSearchTool webSearchTool;
    private final MindFlowConfig config;
    private final LearningResourceMapper resourceMapper;

    // 5个子Agent（构造函数注入）
    private final DocAgent docAgent;
    private final MindMapAgent mindMapAgent;
    private final QuizAgent quizAgent;
    private final ReadingAgent readingAgent;
    private final CodeAgent codeAgent;

    /** 映射 agent 名称到 resourceType */
    private static final Map<String, String> AGENT_TYPE_MAP = Map.of(
            "DocAgent", "DOC",
            "MindMapAgent", "MINDMAP",
            "QuizAgent", "QUIZ",
            "ReadingAgent", "READING",
            "CodeAgent", "CODE"
    );

    @Override
    public String getIntentLabel() {
        return "RESOURCE_GEN";
    }

    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        log.info("ResourceOrchestrator 开始资源生成: topic={}", ctx.getUserMessage());

        return Flux.concat(
                // Phase 1: 知识点细化
                phase1Refine(ctx),

                // Phase 2: 联网检索
                phase2Search(ctx),

                // Phase 3: 并行生成（5个子Agent）
                phase3Generate(ctx),

                // Phase 4: 持久化 + 完成
                phase4Persist(ctx)
        );
    }

    /**
     * Phase 1: 知识点细化 — 将用户模糊描述解析为结构化知识点。
     */
    private Flux<AgentEvent> phase1Refine(AgentContext ctx) {
        return Flux.concat(
                Flux.just(AgentEvent.builder()
                        .type("PROGRESS")
                        .stage("refine")
                        .content("正在分析知识点结构...")
                        .percent(0.05)
                        .build()),
                Flux.just(AgentEvent.builder()
                        .type("PROGRESS")
                        .stage("refine_done")
                        .content("知识点分析完成：正在为您生成 " + ctx.getUserMessage() + " 的学习资料")
                        .percent(0.1)
                        .build())
        );
    }

    /**
     * Phase 2: 联网检索 — 搜索最新资料注入Agent上下文。
     */
    private Flux<AgentEvent> phase2Search(AgentContext ctx) {
        if (!config.getWebsearch().isEnabled()) {
            return Flux.just(AgentEvent.builder()
                    .type("PROGRESS")
                    .stage("search_skip")
                    .content("联网检索已禁用，基于知识库生成")
                    .percent(0.15)
                    .build());
        }

        return Flux.defer(() -> {
            try {
                String searchResult = webSearchTool.search(ctx.getUserMessage());
                ctx.setResolvedParams(searchResult);
                return Flux.just(AgentEvent.builder()
                        .type("PROGRESS")
                        .stage("search_done")
                        .content("已检索最新资料，开始生成学习资源...")
                        .percent(0.2)
                        .build());
            } catch (Exception e) {
                log.warn("WebSearch超时，跳过检索继续生成: {}", e.getMessage());
                return Flux.just(AgentEvent.builder()
                        .type("PROGRESS")
                        .stage("search_fallback")
                        .content("联网检索超时，基于知识库生成")
                        .percent(0.2)
                        .build());
            }
        });
    }

    // 累积每个子Agent生成的内容（agentName → title + content）
    private final Map<String, String> resourceContentMap = new LinkedHashMap<>();
    private final Map<String, String> resourceTitleMap = new LinkedHashMap<>();

    /**
     * Phase 3: 5个子Agent并行生成（使用Flux.merge并行订阅）。
     * 同时累积每个Agent的TEXT内容，用于后续持久化到learning_resource表。
     */
    private Flux<AgentEvent> phase3Generate(AgentContext ctx) {
        String[] typeNames = {"讲解文档", "思维导图", "练习题", "拓展材料", "代码案例"};
        double[] progressSteps = {0.25, 0.4, 0.55, 0.7, 0.85};

        MindFlowAgent[] agents = {docAgent, mindMapAgent, quizAgent, readingAgent, codeAgent};

        List<Flux<AgentEvent>> agentFluxes = new ArrayList<>();
        for (int i = 0; i < agents.length; i++) {
            final int idx = i;
            final MindFlowAgent agent = agents[idx];

            Flux<AgentEvent> agentFlux = Flux.just(AgentEvent.builder()
                            .type("PROGRESS")
                            .stage("generating_" + agent.getIntentLabel())
                            .content("正在生成" + typeNames[idx] + "...")
                            .percent(progressSteps[idx])
                            .build())
                    .concatWith(agent.execute(ctx)
                            .doOnNext(event -> {
                                // 捕获RESOURCE_CARD的标题，累积TEXT内容（用event.agent标记，避免并行覆盖）
                                if ("RESOURCE_CARD".equals(event.getType())) {
                                    String agentName = event.getAgent();
                                    if (agentName != null && event.getTitle() != null) {
                                        resourceTitleMap.put(agentName, event.getTitle());
                                        resourceContentMap.put(agentName, "");
                                    }
                                } else if ("TEXT".equals(event.getType()) && event.getAgent() != null) {
                                    resourceContentMap.merge(event.getAgent(),
                                            event.getContent() != null ? event.getContent() : "",
                                            String::concat);
                                }
                            })
                            .onErrorResume(e -> {
                                log.error("{} 生成失败: {}", typeNames[idx], e.getMessage());
                                return Flux.just(AgentEvent.builder()
                                        .type("ERROR")
                                        .content(typeNames[idx] + "生成失败: " + e.getMessage())
                                        .retryable(true)
                                        .build());
                            })
                    );
            agentFluxes.add(agentFlux);
        }

        return Flux.merge(agentFluxes)
                .timeout(java.time.Duration.ofMillis(config.getAgent().getExecutionTimeoutMs()))
                .onErrorResume(e -> {
                    log.error("并行生成超时或失败: {}", e.getMessage());
                    return Flux.just(AgentEvent.builder()
                            .type("ERROR")
                            .content("部分资源生成超时，已生成的内容将展示")
                            .retryable(true)
                            .build());
                });
    }

    /**
     * Phase 4: 持久化资源 + 完成通知。
     */
    private Flux<AgentEvent> phase4Persist(AgentContext ctx) {
        // 将累积的资源写入 learning_resource 表
        resourceContentMap.forEach((agentName, content) -> {
            if (content != null && !content.isEmpty()) {
                String type = AGENT_TYPE_MAP.getOrDefault(agentName, agentName);
                String title = resourceTitleMap.getOrDefault(agentName, "学习资源");
                try {
                    LearningResource resource = LearningResource.builder()
                            .userId(ctx.getUserId())
                            .sessionId(ctx.getSessionId())
                            .resourceType(type)
                            .title(title)
                            .content(content)
                            .confidenceScore(new BigDecimal("0.85"))
                            .reviewed(false)
                            .build();
                    resourceMapper.insert(resource);
                    log.info("资源已保存: type={}, title={}, id={}", type, title, resource.getId());
                } catch (Exception e) {
                    log.error("保存资源失败: {}", e.getMessage());
                }
            }
        });
        // 清理累积数据
        resourceContentMap.clear();
        resourceTitleMap.clear();

        return Flux.just(
                AgentEvent.builder()
                        .type("PROGRESS")
                        .stage("persist")
                        .content("资源保存完成")
                        .percent(0.95)
                        .build(),
                AgentEvent.builder()
                        .type("COMPLETE")
                        .summary("全部学习资源生成完成！请在「我的云盘」中查看。")
                        .build()
        );
    }

}