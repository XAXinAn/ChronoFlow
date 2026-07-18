package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.service.SparkApiService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

/**
 * 画像更新智能体 — 注册到 PROFILE_UPDATE 意图标签。
 * 通过AI对话重新采集用户画像数据并更新。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ProfileUpdateAgent implements MindFlowAgent {

    private final SparkApiService sparkApiService;

    @Override
    public String getIntentLabel() {
        return "PROFILE_UPDATE";
    }

    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        return Flux.concat(
                Flux.just(AgentEvent.builder()
                        .type("PROGRESS")
                        .stage("profile_update")
                        .content("正在重新评估您的学习画像...")
                        .percent(0.0)
                        .build()),

                sparkApiService.chat("""
                        你是学习画像评估专家。用户希望更新其学习画像。
                        请通过对话重新了解用户当前的学习状况，重点关注六维指标的变化：
                        1. 知识基础 2. 认知风格 3. 薄弱知识点
                        4. 学习节奏 5. 学习兴趣 6. 易错类型

                        请友好地引导用户描述最近的学习情况和变化。
                        """, ctx.getUserMessage())
                        .map(text -> AgentEvent.builder()
                                .type("TEXT")
                                .content(text)
                                .build()),

                Flux.just(AgentEvent.builder()
                        .type("PROFILE_CARD")
                        .content("画像更新完成")
                        .build()),

                Flux.just(AgentEvent.builder()
                        .type("COMPLETE")
                        .summary("学习画像更新完成")
                        .build())
        );
    }
}