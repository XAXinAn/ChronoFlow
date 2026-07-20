package com.chronoflow.backend.mindflow.service;

import com.chronoflow.backend.mindflow.agent.AgentContext;
import com.chronoflow.backend.mindflow.agent.AgentEvent;
import com.chronoflow.backend.mindflow.agent.ProfileAgent;
import com.chronoflow.backend.mindflow.agent.ProfileUpdateAgent;
import com.chronoflow.backend.mindflow.agent.ProfileViewAgent;
import com.chronoflow.backend.mindflow.dto.ProfileResponse;
import com.chronoflow.backend.mindflow.entity.StudentProfile;
import com.chronoflow.backend.mindflow.mapper.StudentProfileMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

/**
 * 画像服务 — 管理六维学习画像的CRUD和对话式构建。
 *
 * 操作类型：
 * - build：开始/继续画像构建对话（多轮交互采集数据）
 * - view：查看当前画像
 * - update：更新画像（重新采集某维度数据）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProfileService {

    private final StudentProfileMapper profileMapper;
    private final ProfileAgent profileAgent;
    private final ProfileViewAgent profileViewAgent;
    private final ProfileUpdateAgent profileUpdateAgent;

    /**
     * 获取用户当前画像。
     */
    public ProfileResponse getProfile(Long userId) {
        StudentProfile profile = profileMapper.selectByUserId(userId);
        if (profile == null) {
            return null;
        }
        return toProfileResponse(profile);
    }

    /**
     * 开始/继续画像构建对话（SSE流式）。
     * 通过ProfileAgent多轮对话采集六维数据。
     */
    public Flux<AgentEvent> buildProfile(Long userId, String sessionId, String message) {
        AgentContext ctx = AgentContext.builder()
                .userId(userId)
                .sessionId(sessionId)
                .userMessage(message)
                .intentLabel("PROFILE_BUILD")
                .build();
        return profileAgent.execute(ctx);
    }

    /**
     * 更新画像（SSE流式）。
     */
    public Flux<AgentEvent> updateProfile(Long userId, String sessionId, String message) {
        AgentContext ctx = AgentContext.builder()
                .userId(userId)
                .sessionId(sessionId)
                .userMessage(message)
                .intentLabel("PROFILE_UPDATE")
                .build();
        return profileUpdateAgent.execute(ctx);
    }

    /**
     * 保存/更新画像数据。
     */
    public void saveProfile(Long userId, String knowledgeBase, String cognitiveStyle,
                            String weakPoints, String pacePreference,
                            String interests, String peakHours, String errorTypes) {
        StudentProfile existing = profileMapper.selectByUserId(userId);

        if (existing != null) {
            // 更新现有画像
            existing.setKnowledgeBase(knowledgeBase);
            existing.setCognitiveStyle(cognitiveStyle);
            existing.setWeakPoints(weakPoints);
            existing.setPacePreference(pacePreference);
            existing.setInterests(interests);
            existing.setPeakHours(peakHours);
            existing.setErrorTypes(errorTypes);
            existing.setProfileVersion((short) (existing.getProfileVersion() + 1));
            profileMapper.updateById(existing);
            log.info("更新画像: userId={}, version={}", userId, existing.getProfileVersion());
        } else {
            // 创建新画像
            StudentProfile profile = StudentProfile.builder()
                    .userId(userId)
                    .knowledgeBase(knowledgeBase)
                    .cognitiveStyle(cognitiveStyle)
                    .weakPoints(weakPoints)
                    .pacePreference(pacePreference)
                    .interests(interests)
                    .peakHours(peakHours)
                    .errorTypes(errorTypes)
                    .profileVersion((short) 1)
                    .build();
            profileMapper.insert(profile);
            log.info("创建画像: userId={}", userId);
        }
    }

    private ProfileResponse toProfileResponse(StudentProfile profile) {
        return ProfileResponse.builder()
                .userId(profile.getUserId())
                .knowledgeBase(profile.getKnowledgeBase())
                .cognitiveStyle(profile.getCognitiveStyle())
                .weakPoints(profile.getWeakPoints())
                .pacePreference(profile.getPacePreference())
                .interests(profile.getInterests())
                .peakHours(profile.getPeakHours())
                .errorTypes(profile.getErrorTypes())
                .profileVersion(profile.getProfileVersion() != null ? profile.getProfileVersion().intValue() : null)
                .createdAt(profile.getCreatedAt())
                .updatedAt(profile.getUpdatedAt())
                .build();
    }
}