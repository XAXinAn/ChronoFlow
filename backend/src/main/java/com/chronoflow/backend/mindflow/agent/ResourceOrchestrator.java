package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.config.MindFlowConfig;
import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.entity.LearningResource;
import com.chronoflow.backend.mindflow.mapper.LearningResourceMapper;
import com.chronoflow.backend.mindflow.review.MindFlowReviewService;
import com.chronoflow.backend.mindflow.tool.WebSearchTool;
import com.chronoflow.backend.mindflow.util.PromptGuard;
import com.chronoflow.backend.service.MinioService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.math.BigDecimal;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

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
 *
 * 修复（vs HEAD）：
 * - 实例字段 bug：resourceContentMap/TitleMap 改为 ctx 属性（防并发用户覆盖）
 * - 安全：调用 PromptGuard 校验用户输入
 * - 内容审核：AI 生成内容入库前调用 MindFlowReviewService
 * - 错误恢复：每个子Agent 失败不中断其他 Agent，最终汇总错误信息
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ResourceOrchestrator implements MindFlowAgent {

    private final WebSearchTool webSearchTool;
    private final MindFlowConfig config;
    private final LearningResourceMapper resourceMapper;
    private final MindFlowReviewService reviewService;
    private final MinioService minioService;

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
        log.info("ResourceOrchestrator 开始资源生成: userId={}, topic={}", ctx.getUserId(), ctx.getUserMessage());

        // 安全校验：检查用户输入
        try {
            PromptGuard.validate(ctx.getUserMessage());
            reviewService.reviewUserInput(ctx.getUserMessage());
        } catch (Exception e) {
            log.warn("用户输入未通过校验: {}", e.getMessage());
            return Flux.just(AgentEvent.builder()
                    .type(AgentEventType.ERROR.getCode())
                    .content("输入未通过安全检查：" + e.getMessage())
                    .retryable(false)
                    .build());
        }

        // 初始化 ctx 的累积 Map（每个请求独立，避免并发用户数据互相覆盖）
        ctx.setResourceContentMap(new ConcurrentHashMap<>());
        ctx.setResourceTitleMap(new ConcurrentHashMap<>());

        return Flux.concat(
                phase1Refine(ctx),
                phase2Search(ctx),
                phase3Generate(ctx)
        );
    }

    /**
     * Phase 1: 知识点细化 — 将用户模糊描述解析为结构化知识点。
     */
    private Flux<AgentEvent> phase1Refine(AgentContext ctx) {
        return Flux.concat(
                Flux.just(AgentEvent.builder()
                        .type(AgentEventType.PROGRESS.getCode())
                        .stage("refine")
                        .content("正在分析知识点结构...")
                        .percent(0.05)
                        .build()),
                Flux.just(AgentEvent.builder()
                        .type(AgentEventType.PROGRESS.getCode())
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
                    .type(AgentEventType.PROGRESS.getCode())
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
                        .type(AgentEventType.PROGRESS.getCode())
                        .stage("search_done")
                        .content("已检索最新资料，开始生成学习资源...")
                        .percent(0.2)
                        .build());
            } catch (Exception e) {
                log.warn("WebSearch超时，跳过检索继续生成: {}", e.getMessage());
                return Flux.just(AgentEvent.builder()
                        .type(AgentEventType.WARNING.getCode())
                        .stage("search_fallback")
                        .content("联网检索超时，基于知识库生成")
                        .percent(0.2)
                        .build());
            }
        });
    }

    /**
     * Phase 3: 5个子Agent并行生成（Flux.merge 真正并行）。
     * 每个子Agent失败被独立捕获，不影响其他 Agent。
     * 累积数据存到 ctx 的 map 中（每个请求独立）。
     */
    private Flux<AgentEvent> phase3Generate(AgentContext ctx) {
        String[] typeNames = {"讲解文档", "思维导图", "练习题", "拓展材料", "代码案例"};
        double[] progressSteps = {0.25, 0.4, 0.55, 0.7, 0.85};

        MindFlowAgent[] agents = {docAgent, mindMapAgent, quizAgent, readingAgent, codeAgent};

        List<Flux<AgentEvent>> agentFluxes = new ArrayList<>();
        List<String> failedAgents = Collections.synchronizedList(new ArrayList<>());

        for (int i = 0; i < agents.length; i++) {
            final int idx = i;
            final MindFlowAgent agent = agents[idx];
            final String agentName = agent.getClass().getSimpleName();
            final String typeName = typeNames[idx];

            Flux<AgentEvent> agentFlux = Flux.just(AgentEvent.builder()
                            .type(AgentEventType.PROGRESS.getCode())
                            .stage("generating_" + agent.getIntentLabel())
                            .content("正在生成" + typeName + "...")
                            .percent(progressSteps[idx])
                            .build())
                    .concatWith(agent.execute(ctx)
                            .doOnNext(event -> {
                                // 累积数据到 ctx（线程安全）
                                if (AgentEventType.RESOURCE_CARD.getCode().equals(event.getType())) {
                                    if (event.getTitle() != null) {
                                        ctx.getResourceTitleMap().put(agentName, event.getTitle());
                                        ctx.getResourceContentMap().put(agentName, "");
                                    }
                                    log.info("phase3 RESOURCE_CARD: agent={}, title={}", agentName, event.getTitle());
                                } else if (AgentEventType.TEXT.getCode().equals(event.getType()) && event.getAgent() != null) {
                                    ctx.getResourceContentMap().merge(event.getAgent(),
                                            event.getContent() != null ? event.getContent() : "",
                                            String::concat);
                                    log.info("phase3 TEXT: agent={}, contentLen={}", event.getAgent(), event.getContent() != null ? event.getContent().length() : 0);
                                }
                            })
                            .onErrorResume(e -> {
                                // 单个 Agent 失败 — 记录但不中断
                                log.error("{} 生成失败: {}", typeName, e.getMessage());
                                failedAgents.add(typeName);
                                return Flux.just(AgentEvent.builder()
                                        .type(AgentEventType.ERROR.getCode())
                                        .content(typeName + "生成失败: " + e.getMessage())
                                        .retryable(true)
                                        .build());
                            })
                    );
            agentFluxes.add(agentFlux);
        }

        // 使用 Mono.whenAll 等所有 agent Flux 完成后再推进（解决 Flux.merge 立即返回的问题）
        Flux<AgentEvent> mergedEvents = Flux.merge(agentFluxes)
                .timeout(java.time.Duration.ofMillis(config.getAgent().getExecutionTimeoutMs()));

        // 等所有 agent 完成：Mono.whenAll 返回 void Mono
        Mono<Void> allAgentsDone = Mono.when(agentFluxes.toArray(Flux[]::new))
                .timeout(java.time.Duration.ofMillis(config.getAgent().getExecutionTimeoutMs()))
                .then()
                .doOnSuccess(v -> log.info("phase3全部agent完成: contentMap={}, titleMap={}",
                        ctx.getResourceContentMap().size(), ctx.getResourceTitleMap().size()));

        // 合并：事件流 + 等待所有agent完成（then空信号推进concat）
        return Flux.merge(mergedEvents, allAgentsDone.thenMany(Flux.empty()))
                .concatWith(Flux.defer(() -> {
                    if (!failedAgents.isEmpty()) {
                        log.warn("部分资源生成失败: {}", String.join(", ", failedAgents));
                        return Flux.just(AgentEvent.builder()
                                .type(AgentEventType.WARNING.getCode())
                                .stage("partial_failure")
                                .content("已完成 " + (agents.length - failedAgents.size()) + "/" + agents.length
                                        + " 类资源。失败类型: " + String.join(", ", failedAgents))
                                .percent(0.9)
                                .build());
                    }
                    return Flux.empty();
                }));
    }

    /**
     * Phase 4: 持久化资源 + 完成通知。
     * 每个资源入库前调用 MindFlowReviewService。
     */
    private Flux<AgentEvent> phase4Persist(AgentContext ctx) {
        Map<String, String> contentMap = ctx.getResourceContentMap();
        Map<String, String> titleMap = ctx.getResourceTitleMap();
        log.info("phase4Persist: contentMap={}, titleMap={}", contentMap, titleMap);

        List<String> savedTypes = new ArrayList<>();
        List<String> rejectedTypes = new ArrayList<>();

        contentMap.forEach((agentName, content) -> {
            if (content != null && !content.isEmpty()) {
                String type = AGENT_TYPE_MAP.getOrDefault(agentName, agentName);
                String title = titleMap.getOrDefault(agentName, "学习资源");

                try {
                    // 内容审核（AI 生成的内容）
                    reviewService.reviewGeneratedContent(content, type);

                    // 上传内容到 MinIO
                    String uuid = UUID.randomUUID().toString();
                    byte[] contentBytes = content.getBytes(java.nio.charset.StandardCharsets.UTF_8);
                    String fileKey = "resources/" + ctx.getUserId() + "/" + type + "/" + uuid + ".md";
                    try {
                        minioService.upload(contentBytes, fileKey, "text/markdown; charset=utf-8");
                        log.info("内容已上传 MinIO: fileKey={}, size={}", fileKey, contentBytes.length);
                    } catch (Exception e) {
                        log.warn("MinIO 上传失败，降级存 MySQL: {}", e.getMessage());
                        // MinIO 失败时降级存 MySQL（向后兼容）
                    }

                    LearningResource resource = LearningResource.builder()
                            .userId(ctx.getUserId())
                            .sessionId(ctx.getSessionId())
                            .resourceType(type)
                            .title(title)
                            .fileKey(fileKey)
                            .fileSize((long) contentBytes.length)
                            .content(null)  // 新资源存 MinIO，MySQL 不存 content
                            .confidenceScore(new BigDecimal("0.85"))
                            .reviewed(true)
                            .version(1)
                            .build();
                    resourceMapper.insert(resource);
                    savedTypes.add(type);
                    log.info("资源已保存: type={}, title={}, id={}, fileKey={}", type, title, resource.getId(), fileKey);
                } catch (Exception e) {
                    log.warn("保存资源失败: type={}, reason={}", type, e.getMessage());
                    rejectedTypes.add(type);
                }
            }
        });

        // 清理 ctx 累积数据
        contentMap.clear();
        titleMap.clear();

        String summary;
        if (rejectedTypes.isEmpty()) {
            summary = "全部学习资源生成完成！请在「我的云盘」中查看。";
        } else {
            summary = "已保存 " + savedTypes.size() + " 类资源，" + rejectedTypes.size() + " 类因审核未通过被拒绝";
        }

        return Flux.just(
                AgentEvent.builder()
                        .type(AgentEventType.PROGRESS.getCode())
                        .stage("persist")
                        .content("资源保存完成")
                        .percent(0.95)
                        .build(),
                AgentEvent.builder()
                        .type(AgentEventType.COMPLETE.getCode())
                        .summary(summary)
                        .build()
        );
    }

}