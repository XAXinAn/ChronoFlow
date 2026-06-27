package com.chronoflow.backend.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Service
@RequiredArgsConstructor
public class RateLimiterService {

    private final StringRedisTemplate redisTemplate;

    /**
     * Try to acquire a rate-limited slot. Returns true if allowed, false if limit exceeded.
     */
    public boolean tryAcquire(String key, int maxRequests, Duration window) {
        String redisKey = "ratelimit:" + key;
        Long count = redisTemplate.opsForValue().increment(redisKey);
        if (count != null && count == 1) {
            redisTemplate.expire(redisKey, window);
        }
        return count != null && count <= maxRequests;
    }
}
