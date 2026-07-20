package com.chronoflow.backend.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
public class TokenBlacklistService {

    private static final String BLACKLIST_PREFIX = "blacklist:";

    private final RedisTemplate<String, String> redisTemplate;

    public void blacklistToken(String token, long remainingTimeMillis) {
        String key = BLACKLIST_PREFIX + token;
        redisTemplate.opsForValue().set(key, "revoked", remainingTimeMillis, TimeUnit.MILLISECONDS);
    }

    public boolean isBlacklisted(String token) {
        String key = BLACKLIST_PREFIX + token;
        return Boolean.TRUE.equals(redisTemplate.hasKey(key));
    }

    public long getRemainingTimeMillis(String token) {
        String key = BLACKLIST_PREFIX + token;
        Long ttl = redisTemplate.getExpire(key, TimeUnit.MILLISECONDS);
        return ttl != null && ttl > 0 ? ttl : 0;
    }
}