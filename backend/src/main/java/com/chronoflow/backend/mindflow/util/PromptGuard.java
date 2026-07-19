package com.chronoflow.backend.mindflow.util;

import com.chronoflow.backend.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.regex.Pattern;

/**
 * Prompt 注入防护工具 — 防止用户输入覆盖 Agent 的系统指令。
 *
 * 三道防线：
 * 1. 黑名单特征检测（常见注入模式）
 * 2. 输入长度限制（防止超长输入耗尽 token）
 * 3. 结构化包裹（用 XML 标签隔离用户输入，让大模型知道边界）
 *
 * 用法：
 *   String safeUserInput = PromptGuard.sanitize(userRawInput);
 *   String prompt = "请回答 <user_input>" + safeUserInput + "</user_input>";
 */
@Slf4j
@Component
public class PromptGuard {

    /** 用户输入最大长度（防止超长输入耗尽 token） */
    public static final int MAX_INPUT_LENGTH = 2000;

    /** 黑名单：常见的 prompt 注入特征（中英文都覆盖） */
    private static final List<String> INJECTION_PATTERNS = List.of(
            "忽略以上", "忽略之前", "忽略前面", "忽略上述", "忽略上面",
            "ignore previous", "ignore above", "ignore all",
            "ignore the above", "disregard previous", "disregard above",
            "forget your instructions", "forget everything",
            "new instructions:", "new prompt:", "system:",
            "you are now", "你现在是", "从现在开始", "重新设定",
            "act as", "扮演", "pretend to be", "假装",
            "no restrictions", "没有限制", "bypass", "绕过",
            "jailbreak", "越狱", "do anything now", "DAN"
    );

    private static final Pattern COMPILED = Pattern.compile(
            String.join("|", INJECTION_PATTERNS.stream().map(Pattern::quote).toList()),
            Pattern.CASE_INSENSITIVE
    );

    /**
     * 检测输入是否包含 prompt 注入特征。
     *
     * @param userInput 原始用户输入
     * @throws BusinessException 如果检测到注入特征
     */
    public static void validate(String userInput) {
        if (userInput == null || userInput.isBlank()) {
            throw new BusinessException("输入不能为空");
        }

        // 长度检查
        if (userInput.length() > MAX_INPUT_LENGTH) {
            log.warn("用户输入超长，已截断：原始长度={}", userInput.length());
            throw new BusinessException("输入过长（超过 " + MAX_INPUT_LENGTH + " 字符），请精简后重试");
        }

        // 黑名单检测
        if (COMPILED.matcher(userInput).find()) {
            log.warn("检测到 prompt 注入特征：userInput={}", sanitizeForLog(userInput));
            throw new BusinessException("输入包含不被允许的指令模式，请重新组织问题");
        }
    }

    /**
     * 清洗用户输入：
     * 1. 移除可能破坏 prompt 结构的控制字符
     * 2. 包裹在 XML 标签内，明确边界
     */
    public static String sanitize(String userInput) {
        validate(userInput);
        // 移除控制字符（保留中文、英文、数字、常见标点）
        String cleaned = userInput.replaceAll("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F]", "");
        return "<user_input>" + cleaned + "</user_input>";
    }

    /**
     * 安全包装：将用户输入插入到 prompt 模板中。
     *
     * 用法：
     *   PromptGuard.wrap(userInput, "请解释 %s 的含义");
     *   → "请解释 <user_input>xxx</user_input> 的含义"
     */
    public static String wrap(String userInput, String template) {
        return String.format(template, sanitize(userInput));
    }

    /**
     * 日志脱敏（避免日志泄露用户隐私）。
     */
    private static String sanitizeForLog(String input) {
        if (input == null) return "";
        return input.length() > 50 ? input.substring(0, 50) + "..." : input;
    }
}