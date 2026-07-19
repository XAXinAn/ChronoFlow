package com.chronoflow.backend.mindflow.service;

import com.chronoflow.backend.mindflow.constant.MindFlowConstants;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.concurrent.TimeUnit;

/**
 * MindFlow 缓存服务 — 资源生成结果 Redis 缓存。
 *
 * 用途：
 * 1. 用户重复请求同一知识点时，直接返回缓存结果（避免重复扣 LLM token）
 * 2. 缓存有效期由 application.yaml 的 mindflow.resource.cache-hours 控制（默认 1 小时）
 * 3. Redis 不可用时降级为不缓存（fail-safe，不影响主流程）
 *
 * 缓存键设计：
 *   mindflow:resource:{userId}:{topic_hash}
 *
 * topic_hash = SHA-256(topic).substring(0, 16) — 避免超长 key
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MindFlowCacheService {

    private final StringRedisTemplate redisTemplate;

    /** 缓存 hash 前缀长度 */
    private static final int HASH_PREFIX_LEN = 16;

    /**
     * 获取缓存的资源生成结果。
     *
     * @param userId 用户ID
     * @param topic  知识点主题
     * @return 缓存的 JSON 内容，未命中返回 null
     */
    public String getResourceCache(Long userId, String topic) {
        if (userId == null || topic == null) return null;
        String key = buildKey(userId, topic);
        try {
            return redisTemplate.opsForValue().get(key);
        } catch (Exception e) {
            log.warn("Redis 缓存读取失败（降级为不缓存）: key={}, error={}", key, e.getMessage());
            return null;
        }
    }

    /**
     * 写入资源生成结果到 Redis 缓存。
     *
     * @param userId    用户ID
     * @param topic     知识点主题
     * @param content   资源内容（JSON）
     * @param ttlHours  过期时间（小时）
     */
    public void putResourceCache(Long userId, String topic, String content, int ttlHours) {
        if (userId == null || topic == null || content == null) return;
        String key = buildKey(userId, topic);
        try {
            redisTemplate.opsForValue().set(key, content, ttlHours, TimeUnit.HOURS);
        } catch (Exception e) {
            log.warn("Redis 缓存写入失败（不影响主流程）: key={}, error={}", key, e.getMessage());
        }
    }

    /**
     * 清除用户的资源缓存（用于用户重新测评时）。
     */
    public void invalidateUserResources(Long userId) {
        if (userId == null) return;
        String pattern = MindFlowConstants.CACHE_KEY_RESOURCE + userId + MindFlowConstants.CACHE_KEY_SEPARATOR + "*";
        try {
            redisTemplate.delete(redisTemplate.keys(pattern));
        } catch (Exception e) {
            log.warn("Redis 缓存清除失败: pattern={}, error={}", pattern, e.getMessage());
        }
    }

    private String buildKey(Long userId, String topic) {
        String hash = sha256(topic).substring(0, HASH_PREFIX_LEN);
        return MindFlowConstants.CACHE_KEY_RESOURCE + userId + MindFlowConstants.CACHE_KEY_SEPARATOR + hash;
    }

    /** SHA-256 摘要（用于缓存键） */
    private String sha256(String input) {
        try {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(input.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder();
            for (byte b : hash) {
                hex.append(String.format("%02x", b));
            }
            return hex.toString();
        } catch (Exception e) {
            // 降级：使用 input.hashCode()
            return String.valueOf(input.hashCode());
        }
    }
}