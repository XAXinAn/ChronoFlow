package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.entity.StudentProfile;
import com.chronoflow.backend.mindflow.mapper.StudentProfileMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

import java.util.Map;

/**
 * 画像查看智能体 — 注册到 PROFILE_VIEW 意图标签。
 * 查询并展示用户现有的六维学习画像。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ProfileViewAgent implements MindFlowAgent {

    private final StudentProfileMapper profileMapper;

    @Override
    public String getIntentLabel() {
        return "PROFILE_VIEW";
    }

    @Override
    public Flux<AgentEvent> execute(AgentContext ctx) {
        StudentProfile profile = profileMapper.selectByUserId(ctx.getUserId());

        if (profile == null) {
            return Flux.just(
                    AgentEvent.builder()
                            .type("TEXT")
                            .content("您还没有学习画像，请先进行学情测评。\n\n发送 **「开始学情测评」** 即可开始。")
                            .build(),
                    AgentEvent.builder().type("COMPLETE").summary("未找到画像").build()
            );
        }

        return Flux.just(
                AgentEvent.builder()
                        .type("PROFILE_CARD")
                        .content(formatProfileCard(profile))
                        .extra(Map.of(
                                "knowledgeBase", profile.getKnowledgeBase() != null ? profile.getKnowledgeBase() : "",
                                "cognitiveStyle", profile.getCognitiveStyle() != null ? profile.getCognitiveStyle() : "",
                                "weakPoints", profile.getWeakPoints() != null ? profile.getWeakPoints() : "",
                                "pacePreference", profile.getPacePreference() != null ? profile.getPacePreference() : "",
                                "interests", profile.getInterests() != null ? profile.getInterests() : "",
                                "errorTypes", profile.getErrorTypes() != null ? profile.getErrorTypes() : "",
                                "profileVersion", profile.getProfileVersion()
                        ))
                        .build(),
                AgentEvent.builder().type("COMPLETE").summary("画像查看完成").build()
        );
    }

    private String formatProfileCard(StudentProfile profile) {
        return String.format("""
                ## 📊 我的学习画像 (v%d)

                **知识基础**：%s
                **认知风格**：%s
                **薄弱知识点**：%s
                **学习节奏偏好**：%s
                **学习兴趣方向**：%s
                **易错类型**：%s

                > 更新于 %s
                """,
                profile.getProfileVersion(),
                profile.getKnowledgeBase() != null ? profile.getKnowledgeBase() : "待测评",
                profile.getCognitiveStyle() != null ? profile.getCognitiveStyle() : "待测评",
                profile.getWeakPoints() != null ? profile.getWeakPoints() : "待测评",
                profile.getPacePreference() != null ? profile.getPacePreference() : "待测评",
                profile.getInterests() != null ? profile.getInterests() : "待测评",
                profile.getErrorTypes() != null ? profile.getErrorTypes() : "待测评",
                profile.getUpdatedAt() != null ? profile.getUpdatedAt().toString() : "未知"
        );
    }
}