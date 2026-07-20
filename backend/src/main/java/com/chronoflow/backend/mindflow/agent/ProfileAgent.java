package com.chronoflow.backend.mindflow.agent;

import com.chronoflow.backend.mindflow.constant.AgentEventType;
import com.chronoflow.backend.mindflow.entity.StudentProfile;
import com.chronoflow.backend.mindflow.mapper.StudentProfileMapper;
import com.chronoflow.backend.mindflow.service.SparkApiService;
import com.chronoflow.backend.mindflow.util.PromptGuard;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;

import java.time.LocalDateTime;
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
 * 安全特性：
 * - 用户输入经 PromptGuard 校验（防 prompt 注入）
 *
 * PROFILE_VIEW 和 PROFILE_UPDATE 分别由 ProfileViewAgent 和 ProfileUpdateAgent 处理。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ProfileAgent implements MindFlowAgent {

    private final SparkApiService sparkApiService;
    private final StudentProfileMapper profileMapper;
    private final ObjectMapper objectMapper = new ObjectMapper();

    private static final String SYSTEM_PROMPT = """
            你是学习画像评估专家。根据用户输入的信息，直接推断并生成六维学习画像JSON。

            六维画像（根据用户描述直接推断，不必追问）：
            1. knowledgeBase - 已掌握哪些学科/技能，根据用户身份和描述推断
            2. cognitiveStyle - 偏好视觉visual/文字verbal/逻辑logical/动手hands-on，从描述推断
            3. weakPoints - 薄弱知识点，从描述中提取
            4. pacePreference - 学习节奏slow_steady/normal/fast_paced
            5. interests - 学习兴趣方向，从描述中提取
            6. errorTypes - 易错类型，从描述中提取

            重要规则：
            - 直接根据用户输入推断生成JSON，不要追问
            - 只需要返回一个JSON，不需要其他文字：
            {"knowledgeBase":"...","cognitiveStyle":"...","weakPoints":"...","pacePreference":"...","interests":"...","errorTypes":"..."}
            - 所有字段必填，如果信息不足则基于合理推断填写
            """;

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
     * 修复：解析AI响应中的JSON并保存到数据库。
     */
    private Flux<AgentEvent> buildProfile(AgentContext ctx) {
        StudentProfile existing = profileMapper.selectByUserId(ctx.getUserId());
        String mode = (existing != null) ? "更新" : "创建";

        // 安全包装用户消息
        String safeUserMessage = PromptGuard.sanitize(ctx.getUserMessage());

        return Flux.concat(
                Flux.just(AgentEvent.builder()
                        .type(AgentEventType.PROGRESS.getCode())
                        .stage("profile_init")
                        .content("正在为您" + mode + "学习画像，请回答以下问题...")
                        .percent(0.0)
                        .build()),

                sparkApiService.chat(SYSTEM_PROMPT, safeUserMessage)
                        .flatMapMany(response -> {
                            // 1. 提取并保存画像数据
                            log.info("AI响应内容: {}", response);
                            saveProfileFromResponse(ctx.getUserId(), response);
                            // 2. 提取对话内容（去除JSON部分）返回给前端
                            String textContent = extractTextContent(response);
                            return Flux.just(AgentEvent.builder()
                                    .type(AgentEventType.TEXT.getCode())
                                    .content(textContent)
                                    .build());
                        }),

                Flux.just(AgentEvent.builder()
                        .type(AgentEventType.PROFILE_CARD.getCode())
                        .content("画像" + mode + "完成")
                        .extra(Map.of("mode", mode))
                        .build()),

                Flux.just(AgentEvent.builder()
                        .type(AgentEventType.COMPLETE.getCode())
                        .summary("学习画像" + mode + "完成")
                        .build())
        );
    }

    /**
     * 从AI响应中解析JSON并保存画像到数据库。
     * 讯飞模型返回格式：外层是OpenAI兼容格式{"choices":[{"message":{"content":"<内层JSON>"}}]}
     */
    private void saveProfileFromResponse(Long userId, String response) {
        try {
            String jsonStr = extractJson(response);
            if (jsonStr.isEmpty()) {
                log.warn("AI响应中未找到JSON数据，跳过保存: userId={}", userId);
                return;
            }
            JsonNode root = objectMapper.readTree(jsonStr);

            // 尝试从 choices[0].message.content 中提取内层JSON
            JsonNode contentNode = root.path("choices").path(0).path("message").path("content");
            String innerJson = null;
            if (!contentNode.isMissingNode() && !contentNode.isNull()) {
                innerJson = contentNode.asText();
            }

            // 如果没找到，尝试 reasoning_content
            if (innerJson == null || innerJson.isEmpty()) {
                JsonNode reasoningNode = root.path("choices").path(0).path("message").path("reasoning_content");
                if (!reasoningNode.isMissingNode() && !reasoningNode.isNull()) {
                    innerJson = reasoningNode.asText();
                }
            }

            // 如果还是空，直接用外层JSON
            if (innerJson == null || innerJson.isEmpty()) {
                innerJson = jsonStr;
            }

            // 解析内层JSON
            JsonNode json = null;
            try {
                // 尝试解析内层JSON（可能是被```json包裹的）
                String cleanJson = extractJson(innerJson);
                if (!cleanJson.isEmpty()) {
                    json = objectMapper.readTree(cleanJson);
                }
            } catch (Exception e) {
                // 内层不是JSON，直接用外层
                json = root;
            }

            String knowledgeBase = getText(json, "knowledgeBase");
            String cognitiveStyle = getText(json, "cognitiveStyle");
            String weakPoints = getText(json, "weakPoints");
            String pacePreference = getText(json, "pacePreference");
            String interests = getText(json, "interests");
            String errorTypes = getText(json, "errorTypes");

            // 直接使用 profileMapper 插入/更新，避免循环依赖
            StudentProfile existing = profileMapper.selectByUserId(userId);
            if (existing != null) {
                existing.setKnowledgeBase(knowledgeBase);
                existing.setCognitiveStyle(cognitiveStyle);
                existing.setWeakPoints(weakPoints);
                existing.setPacePreference(pacePreference);
                existing.setInterests(interests);
                existing.setPeakHours(null);
                existing.setErrorTypes(errorTypes);
                existing.setProfileVersion((short) (existing.getProfileVersion() + 1));
                existing.setUpdatedAt(LocalDateTime.now());
                profileMapper.updateById(existing);
                log.info("画像更新成功: userId={}, version={}", userId, existing.getProfileVersion());
            } else {
                StudentProfile profile = StudentProfile.builder()
                        .userId(userId)
                        .knowledgeBase(knowledgeBase)
                        .cognitiveStyle(cognitiveStyle)
                        .weakPoints(weakPoints)
                        .pacePreference(pacePreference)
                        .interests(interests)
                        .peakHours(null)
                        .errorTypes(errorTypes)
                        .profileVersion((short) 1)
                        .createdAt(LocalDateTime.now())
                        .updatedAt(LocalDateTime.now())
                        .build();
                profileMapper.insert(profile);
                log.info("画像创建成功: userId={}", userId);
            }
        } catch (Exception e) {
            log.error("保存画像失败: userId={}, error={}", userId, e.getMessage(), e);
        }
    }

    /**
     * 从AI响应中提取JSON字符串。
     */
    private String extractJson(String response) {
        if (response == null || response.isEmpty()) return "";
        int start = response.indexOf('{');
        int end = response.lastIndexOf('}');
        if (start >= 0 && end > start) {
            return response.substring(start, end + 1);
        }
        return "";
    }

    /**
     * 从AI响应中提取纯文本内容（去除JSON部分）。
     */
    private String extractTextContent(String response) {
        if (response == null || response.isEmpty()) return "";
        String jsonStr = extractJson(response);
        if (!jsonStr.isEmpty()) {
            return response.replace(jsonStr, "").trim();
        }
        return response;
    }

    private String getText(JsonNode json, String field) {
        JsonNode node = json.get(field);
        return (node != null && !node.isNull()) ? node.asText() : "";
    }
}