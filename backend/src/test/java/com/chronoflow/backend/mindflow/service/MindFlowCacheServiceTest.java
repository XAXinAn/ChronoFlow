package com.chronoflow.backend.mindflow.service;

import com.chronoflow.backend.mindflow.constant.MindFlowConstants;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * MindFlowCacheService 单元测试 — 验证 Redis 缓存读写和降级行为。
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("MindFlowCacheService 缓存测试")
class MindFlowCacheServiceTest {

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOps;

    @InjectMocks
    private MindFlowCacheService cacheService;

    @BeforeEach
    void setUp() {
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
    }

    @Test
    @DisplayName("getResourceCache 命中时返回缓存值")
    void getResourceCache_hit_shouldReturnValue() {
        // Given
        String cached = "{\"topic\":\"机器学习\",\"content\":\"cached\"}";
        when(valueOps.get(anyString())).thenReturn(cached);

        // When
        String result = cacheService.getResourceCache(100L, "机器学习");

        // Then
        assertThat(result).isEqualTo(cached);
    }

    @Test
    @DisplayName("getResourceCache 未命中时返回 null")
    void getResourceCache_miss_shouldReturnNull() {
        when(valueOps.get(anyString())).thenReturn(null);
        assertThat(cacheService.getResourceCache(100L, "未知主题")).isNull();
    }

    @Test
    @DisplayName("getResourceCache Redis 异常时降级返回 null（不抛异常）")
    void getResourceCache_redisError_shouldFallbackToNull() {
        when(valueOps.get(anyString())).thenThrow(new RuntimeException("Redis 连接失败"));

        // 不应该抛异常
        assertThat(cacheService.getResourceCache(100L, "主题")).isNull();
    }

    @Test
    @DisplayName("getResourceCache null userId 应该返回 null")
    void getResourceCache_nullUserId_shouldReturnNull() {
        assertThat(cacheService.getResourceCache(null, "主题")).isNull();
    }

    @Test
    @DisplayName("getResourceCache null topic 应该返回 null")
    void getResourceCache_nullTopic_shouldReturnNull() {
        assertThat(cacheService.getResourceCache(100L, null)).isNull();
    }

    @Test
    @DisplayName("putResourceCache 应该正确设置 key + value + 过期时间")
    void putResourceCache_shouldSetWithTtl() {
        // When
        cacheService.putResourceCache(100L, "机器学习", "{\"data\":1}", 1);

        // Then
        verify(valueOps).set(anyString(), eq("{\"data\":1}"), anyLong(), eq(TimeUnit.HOURS));
    }

    @Test
    @DisplayName("putResourceCache Redis 异常时降级（不抛异常）")
    void putResourceCache_redisError_shouldFallbackSilently() {
        doThrow(new RuntimeException("Redis 写入失败")).when(valueOps).set(anyString(), anyString(), anyLong(), any(TimeUnit.class));

        // 不应该抛异常
        assertDoesNotThrow(() -> cacheService.putResourceCache(100L, "主题", "内容", 1));
    }

    @Test
    @DisplayName("putResourceCache null 参数应该跳过")
    void putResourceCache_nullArgs_shouldSkip() {
        cacheService.putResourceCache(null, "主题", "内容", 1);
        cacheService.putResourceCache(100L, null, "内容", 1);
        cacheService.putResourceCache(100L, "主题", null, 1);
        verify(valueOps, never()).set(anyString(), anyString(), anyLong(), any(TimeUnit.class));
    }

    @Test
    @DisplayName("invalidateUserResources 应该删除该用户的所有缓存键")
    void invalidateUserResources_shouldDeleteAllUserKeys() {
        // Given
        when(redisTemplate.keys(anyString())).thenReturn(java.util.Set.of(
                "mindflow:resource:100:abc123",
                "mindflow:resource:100:def456"
        ));

        // When
        cacheService.invalidateUserResources(100L);

        // Then
        verify(redisTemplate).keys(contains("100"));
        verify(redisTemplate).delete(anySet());
    }

    @Test
    @DisplayName("invalidateUserResources Redis 异常时降级")
    void invalidateUserResources_redisError_shouldFallbackSilently() {
        when(redisTemplate.keys(anyString())).thenThrow(new RuntimeException("Redis keys 失败"));
        assertDoesNotThrow(() -> cacheService.invalidateUserResources(100L));
    }

    @Test
    @DisplayName("缓存键应该以 MindFlowConstants 前缀开头")
    void cacheKey_shouldHavePrefix() {
        // 触发 putResourceCache，验证 key 包含正确的 prefix
        cacheService.putResourceCache(100L, "测试", "value", 1);

        // 验证 key 包含 mindflow:resource:100:
        org.mockito.ArgumentCaptor<String> keyCaptor = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(valueOps).set(keyCaptor.capture(), anyString(), anyLong(), any(TimeUnit.class));
        String capturedKey = keyCaptor.getValue();
        assertThat(capturedKey).startsWith(MindFlowConstants.CACHE_KEY_RESOURCE + "100" + MindFlowConstants.CACHE_KEY_SEPARATOR);
    }

    @Test
    @DisplayName("同一 topic 应该生成相同的缓存键（一致性）")
    void cacheKey_sameTopic_shouldProduceSameKey() {
        cacheService.putResourceCache(100L, "机器学习", "value1", 1);
        cacheService.putResourceCache(100L, "机器学习", "value2", 1);

        org.mockito.ArgumentCaptor<String> keyCaptor = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(valueOps, times(2)).set(keyCaptor.capture(), anyString(), anyLong(), any(TimeUnit.class));
        assertThat(keyCaptor.getAllValues().get(0)).isEqualTo(keyCaptor.getAllValues().get(1));
    }
}

