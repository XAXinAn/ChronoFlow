package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.entity.StudentProfile;
import com.chronoflow.backend.mindflow.mapper.StudentProfileMapper;
import com.chronoflow.backend.mindflow.service.SparkApiService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

import java.util.Map;

/**
 * 画像构建智能体（P0）— 通过多轮AI对话引导用户完成六维学习画像测评。
 *
 * 六维画像指标：
 * - 知识基础（knowledgeBase）：用户已掌握的知识体系
 * - 认知风格（cognitiveStyle）：visual/verbal/logical/hands-on
 * - 薄弱知识点（weakPoints）：需要加强的知识领域
 * - 学习节奏偏好（pacePreference）：slow_steady/normal/fast_paced
 * - 学习兴趣方向（interests）：用户感兴趣的方向
 * - 易错类型（errorTypes）：常见的错误模式
 *
 * PROFILE_VIEW 和 PROFILE_UPDATE 分别由 ProfileViewAgent 和 ProfileUpdateAgent 处理。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ProfileAgent implements MindFlowAgent {

    private final SparkApiService sparkApiService;
    private final StudentProfileMapper profileMapper;

    @Override
    public String getIntentLabel() {
        return "PROFILE_BUILD";
    }

    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        return buildProfile(ctx);
    }

    /**
     * 构建学习画像 — 通过AI对话引导用户完成六维测评。
     */
    private Flux<AgentEvent> buildProfile(AgentContext ctx) {
        StudentProfile existing = profileMapper.selectByUserId(ctx.getUserId());
        String mode = (existing != null) ? "更新" : "创建";

        return Flux.concat(
                Flux.just(AgentEvent.builder()
                        .type("PROGRESS")
                        .stage("profile_init")
                        .content("正在为您" + mode + "学习画像，请回答以下问题...")
                        .percent(0.0)
                        .build()),

                sparkApiService.chat("""
                        你是学习画像评估专家。请通过对话了解用户的以下六维特征：
                        1. 知识基础 - 已掌握哪些学科/技能
                        2. 认知风格 - 偏好视觉/文字/逻辑/动手学习
                        3. 薄弱知识点 - 哪些领域需要加强
                        4. 学习节奏 - 偏好慢稳/正常/快节奏
                        5. 学习兴趣 - 对哪些方向感兴趣
                        6. 易错类型 - 常见错误模式

                        请用友好、引导的方式与用户对话，逐步收集信息。
                        在收集完所有维度后，输出一个JSON格式的画像总结。
                        """, ctx.getUserMessage())
                        .map(text -> AgentEvent.builder()
                                .type("TEXT")
                                .content(text)
                                .build()),

                Flux.just(AgentEvent.builder()
                        .type("PROFILE_CARD")
                        .content("画像" + mode + "完成")
                        .extra(Map.of("mode", mode))
                        .build()),

                Flux.just(AgentEvent.builder()
                        .type("COMPLETE")
                        .summary("学习画像" + mode + "完成")
                        .build())
        );
    }
}