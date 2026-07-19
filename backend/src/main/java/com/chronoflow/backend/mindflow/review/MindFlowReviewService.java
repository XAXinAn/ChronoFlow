package com.chronoflow.backend.mindflow.review;

import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.service.ContentModerationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * MindFlow 内容审核包装服务 — 在调用星火 API 之前/之后对文本进行安全检查。
 *
 * 设计目标：
 * 1. 用户输入的对话/主题 — 必须通过审核才能调用 LLM（防 prompt 注入 + 违规内容）
 * 2. AI 生成的资源内容 — 必须通过审核才能入库（防幻觉 + 违规内容）
 * 3. 审核服务未配置时 — 降级为本地规则检查（仅基础关键词）
 * 4. 审核失败 — 抛出 BusinessException，上层捕获后转换为 SSE ERROR 事件
 *
 * 与 ContentModerationService 的区别：
 * - ContentModerationService 是底层 SDK 包装（阿里云 Green），未配置会抛 ContentModerationException
 * - MindFlowReviewService 是 MindFlow 业务层包装（带降级 + 上下文 + MindFlow 业务异常）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MindFlowReviewService {

    private final ContentModerationService contentModerationService;

    /** 违规内容兜底关键词（审核服务未启用时使用） */
    private static final List<String> BLOCKED_KEYWORDS = List.of(
            "色情", "赌博", "毒品", "暴力血腥", "恐怖袭击",
            "porn", "casino", "drugs", "violence", "terrorism"
    );

    /**
     * 审核用户输入文本。
     *
     * @throws BusinessException 审核未通过时抛出
     */
    public void reviewUserInput(String text) {
        if (text == null || text.isBlank()) {
            throw new BusinessException("输入文本不能为空");
        }

        // 1. 兜底关键词检查（始终执行，即使审核服务可用也作为第一道防线）
        if (containsBlockedKeyword(text)) {
            log.warn("用户输入命中兜底关键词拦截");
            throw new BusinessException("输入包含违规内容，请重新组织问题");
        }

        // 2. 调用阿里云 Green 审核（如可用），未配置则降级
        String reason = safeModerate(text);
        if (reason != null) {
            log.warn("阿里云审核拦截用户输入: {}", reason);
            throw new BusinessException("输入未通过内容审核：" + reason);
        }
    }

    /**
     * 审核 AI 生成的资源内容。
     */
    public void reviewGeneratedContent(String text, String resourceType) {
        if (text == null || text.isBlank()) {
            throw new BusinessException("AI 生成内容为空，无法入库");
        }

        // 1. 长度上限检查（防止数据库写入异常）
        if (text.length() > 200_000) {
            log.warn("AI 生成内容超长: type={}, length={}", resourceType, text.length());
            throw new BusinessException("AI 生成内容超过 200KB 限制");
        }

        // 2. 兜底关键词
        if (containsBlockedKeyword(text)) {
            log.warn("AI 生成内容命中兜底关键词: type={}", resourceType);
            throw new BusinessException("AI 生成的" + resourceType + "包含违规内容，已拒绝入库");
        }

        // 3. 阿里云审核（如可用）
        String reason = safeModerate(text);
        if (reason != null) {
            log.warn("阿里云审核拦截 AI 生成内容: type={}, reason={}", resourceType, reason);
            throw new BusinessException("AI 生成的" + resourceType + "未通过审核：" + reason);
        }
    }

    /**
     * 安全调用 ContentModerationService.moderate()，捕获"未配置"异常并降级。
     *
     * @return null=通过；非null=拒绝原因
     */
    private String safeModerate(String text) {
        try {
            return contentModerationService.moderate(text);
        } catch (ContentModerationException e) {
            // 阿里云审核未配置 — 降级为本地规则检查（已在外层执行）
            log.debug("阿里云审核未配置，使用本地兜底检查: {}", e.getMessage());
            return null;
        } catch (BusinessException e) {
            // 服务不可用 — 降级（fail-open 行为由 ContentModerationService 控制）
            log.warn("阿里云审核服务异常，降级处理: {}", e.getMessage());
            return null;
        }
    }

    /**
     * 本地兜底关键词检测。
     */
    private boolean containsBlockedKeyword(String text) {
        String lower = text.toLowerCase();
        return BLOCKED_KEYWORDS.stream().anyMatch(lower::contains);
    }
}