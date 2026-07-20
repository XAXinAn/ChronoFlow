package com.chronoflow.backend.service;

import com.chronoflow.backend.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.core.userdetails.UserDetails;

import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private static final String REFRESH_TOKEN_PREFIX = "refresh_token:";
    private static final String TOKEN_FAMILY_PREFIX = "refresh_family:";

    private final RedisTemplate<String, String> redisTemplate;
    private final JwtTokenProvider jwtTokenProvider;
    private final UserService userService;

    public void saveRefreshToken(UserDetails user, String refreshToken) {
        // Use the username to get a stable user ID
        String username = user.getUsername();
        var appUser = userService.findByUsername(username);
        String key = REFRESH_TOKEN_PREFIX + appUser.getId();
        long ttl = jwtTokenProvider.extractExpiration(refreshToken).getTime() - System.currentTimeMillis();
        if (ttl <= 0) {
            log.warn("Attempting to save already-expired refresh token for user {}", appUser.getId());
            return;
        }
        redisTemplate.opsForValue().set(key, refreshToken, ttl, TimeUnit.MILLISECONDS);
    }

    public boolean validateRefreshToken(String refreshToken) {
        if (!jwtTokenProvider.validateToken(refreshToken)) {
            return false;
        }
        // Ensure it's actually a refresh token type
        if (!jwtTokenProvider.isRefreshToken(refreshToken)) {
            return false;
        }
        String username = jwtTokenProvider.extractUsername(refreshToken);
        var user = userService.findByUsername(username);
        // Check if the token family has been invalidated (reuse detection)
        String jti = jwtTokenProvider.extractJti(refreshToken);
        if (jti != null && isTokenFamilyInvalid(user.getId(), jti)) {
            log.warn("Rejected refresh token from invalidated family: userId={}", user.getId());
            return false;
        }
        String key = REFRESH_TOKEN_PREFIX + user.getId();
        String storedToken = redisTemplate.opsForValue().get(key);
        return refreshToken.equals(storedToken);
    }

    public void deleteRefreshToken(Long userId) {
        String key = REFRESH_TOKEN_PREFIX + userId;
        redisTemplate.delete(key);
    }

    /**
     * Mark a token family as invalid for reuse detection.
     * If a revoked refresh token is presented, the entire family can be invalidated.
     */
    public void markTokenFamilyInvalid(Long userId, String oldJti) {
        String familyKey = TOKEN_FAMILY_PREFIX + userId;
        redisTemplate.opsForValue().set(familyKey, oldJti, 30, TimeUnit.DAYS);
    }

    /**
     * Check if a refresh token family has been invalidated
     */
    public boolean isTokenFamilyInvalid(Long userId, String jti) {
        String familyKey = TOKEN_FAMILY_PREFIX + userId;
        String invalidatedJti = redisTemplate.opsForValue().get(familyKey);
        return jti.equals(invalidatedJti);
    }
}
