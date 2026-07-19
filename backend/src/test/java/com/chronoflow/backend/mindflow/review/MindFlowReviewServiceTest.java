package com.chronoflow.backend.mindflow.review;

import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.service.ContentModerationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/**
 * MindFlowReviewService 单元测试 — 内容审核包装层。
 *
 * 覆盖：
 * 1. 本地兜底关键词检测
 * 2. 阿里云审核服务降级（未配置时跳过）
 * 3. AI 生成内容审核（长度、关键词、阿里云）
 * 4. 异常传递
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("MindFlowReviewService 内容审核测试")
class MindFlowReviewServiceTest {

    @Mock
    private ContentModerationService contentModerationService;

    @InjectMocks
    private MindFlowReviewService reviewService;

    // ============ reviewUserInput 测试 ============

    @Test
    @DisplayName("正常输入应该通过审核")
    void reviewUserInput_normal_shouldPass() {
        // Given: 阿里云审核未配置（抛 ContentModerationException）
        when(contentModerationService.moderate(anyString()))
                .thenThrow(new ContentModerationException("未配置"));

        // When + Then: 不抛异常
        reviewService.reviewUserInput("帮我讲解机器学习");
    }

    @Test
    @DisplayName("空输入应该抛异常")
    void reviewUserInput_empty_shouldThrow() {
        assertThatThrownBy(() -> reviewService.reviewUserInput(""))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("不能为空");

        assertThatThrownBy(() -> reviewService.reviewUserInput(null))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("包含色情关键词应该被拦截")
    void reviewUserInput_blockedKeyword_shouldThrow() {
        // 不需要 mock 阿里云审核，本地兜底先拦截
        assertThatThrownBy(() -> reviewService.reviewUserInput("这是一段包含色情的文本"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("违规");

        verify(contentModerationService, never()).moderate(anyString());
    }

    @Test
    @DisplayName("包含赌博关键词应该被拦截")
    void reviewUserInput_gamblingKeyword_shouldThrow() {
        assertThatThrownBy(() -> reviewService.reviewUserInput("casino game 介绍"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("违规");
    }

    @Test
    @DisplayName("包含毒品关键词应该被拦截")
    void reviewUserInput_drugsKeyword_shouldThrow() {
        assertThatThrownBy(() -> reviewService.reviewUserInput("drugs 制作方法"))
                .isInstanceOf(BusinessException.class);
    }

    @ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(strings = {
            "色情内容", "赌博平台", "毒品交易", "暴力血腥场景",
            "恐怖袭击计划", "porn website", "casino bonus",
            "drugs trade", "violence against", "terrorism plan"
    })
    @DisplayName("各种违规关键词组合都应该被拦截")
    void reviewUserInput_variousBlockedKeywords_shouldThrow(String blocked) {
        assertThatThrownBy(() -> reviewService.reviewUserInput(blocked))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("阿里云审核拒绝时应该抛异常")
    void reviewUserInput_aliyunReject_shouldThrow() {
        when(contentModerationService.moderate(anyString())).thenReturn("违规内容（涉政）");

        assertThatThrownBy(() -> reviewService.reviewUserInput("某些内容"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("未通过内容审核");
    }

    @Test
    @DisplayName("阿里云审核通过（返回 null）时应该正常通过")
    void reviewUserInput_aliyunPass_shouldAllow() {
        when(contentModerationService.moderate(anyString())).thenReturn(null);
        // 不抛异常
        reviewService.reviewUserInput("合规的请求");
    }

    @Test
    @DisplayName("阿里云审核异常时降级（fail-open）")
    void reviewUserInput_aliyunError_shouldFallback() {
        when(contentModerationService.moderate(anyString()))
                .thenThrow(new BusinessException("服务不可用"));

        // 不应该抛异常（降级）
        reviewService.reviewUserInput("合规的请求");
    }

    // ============ reviewGeneratedContent 测试 ============

    @Test
    @DisplayName("正常生成内容应该通过审核")
    void reviewGeneratedContent_normal_shouldPass() {
        when(contentModerationService.moderate(anyString())).thenThrow(new ContentModerationException("未配置"));
        reviewService.reviewGeneratedContent("# 机器学习\n## 监督学习", "DOC");
    }

    @Test
    @DisplayName("空内容应该抛异常")
    void reviewGeneratedContent_empty_shouldThrow() {
        assertThatThrownBy(() -> reviewService.reviewGeneratedContent("", "DOC"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("为空");

        assertThatThrownBy(() -> reviewService.reviewGeneratedContent(null, "DOC"))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("超长内容应该抛异常")
    void reviewGeneratedContent_tooLong_shouldThrow() {
        String tooLong = "a".repeat(200_001);
        assertThatThrownBy(() -> reviewService.reviewGeneratedContent(tooLong, "DOC"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("200KB");
    }

    @Test
    @DisplayName("AI 内容包含违规关键词应该被拦截")
    void reviewGeneratedContent_blockedKeyword_shouldThrow() {
        assertThatThrownBy(() -> reviewService.reviewGeneratedContent("# 讲解\n包含赌博信息", "DOC"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("违规内容");

        verify(contentModerationService, never()).moderate(anyString());
    }

    @Test
    @DisplayName("阿里云审核拒绝 AI 生成内容时应该抛异常")
    void reviewGeneratedContent_aliyunReject_shouldThrow() {
        when(contentModerationService.moderate(anyString())).thenReturn("违规标签");

        assertThatThrownBy(() -> reviewService.reviewGeneratedContent("某些内容", "QUIZ"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("QUIZ")
                .hasMessageContaining("未通过审核");
    }
}

