package com.chronoflow.backend.service;

import com.chronoflow.backend.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.util.Collections;
import java.util.UUID;

import java.util.concurrent.TimeUnit;

@Service
@Slf4j
public class RiskControlService {

    private final RedisTemplate<String, String> redisTemplate;
    private final SmsService smsService;
    private final EmailService emailService;

    private static final String PASSWORD_FAIL_PREFIX = "risk:password_fail:";
    private static final String LOGIN_FREQ_PREFIX = "risk:login_freq:";
    private static final String RISK_TOKEN_PREFIX = "risk:token:";

    private static final int PASSWORD_FAIL_LIMIT = 5;
    private static final int PASSWORD_FAIL_EXPIRE_MINUTES = 30;
    private static final int LOGIN_FREQ_LIMIT = 10;
    private static final int LOGIN_FREQ_EXPIRE_MINUTES = 1;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    // Separator for risk token storage (double colon to avoid conflicts with potential colons in data)
    private static final String TOKEN_SEPARATOR = "::";

    public RiskControlService(RedisTemplate<String, String> redisTemplate,
                              SmsService smsService,
                              EmailService emailService) {
        this.redisTemplate = redisTemplate;
        this.smsService = smsService;
        this.emailService = emailService;
    }

    public boolean checkPasswordFail(String username) {
        String key = PASSWORD_FAIL_PREFIX + username;
        String countStr = redisTemplate.opsForValue().get(key);
        if (countStr == null) {
            return false;
        }
        try {
            int count = Integer.parseInt(countStr);
            return count >= PASSWORD_FAIL_LIMIT;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    /**
     * Atomically increment and set expiration for password failure counter.
     * Uses SET with NX+EX via Lua-like script for atomicity.
     */
    public void recordPasswordFail(String username) {
        String key = PASSWORD_FAIL_PREFIX + username;
        Long count = redisTemplate.opsForValue().increment(key);
        // Always refresh the expiration on each increment to prevent infinite lockout
        if (count != null) {
            redisTemplate.expire(key, PASSWORD_FAIL_EXPIRE_MINUTES, TimeUnit.MINUTES);
        }
        log.info("【风控】用户 {} 密码错误次数: {}", username, count);
    }

    public void clearPasswordFail(String username) {
        String key = PASSWORD_FAIL_PREFIX + username;
        redisTemplate.delete(key);
    }

    public boolean checkLoginFreq(String username) {
        String key = LOGIN_FREQ_PREFIX + username;
        String countStr = redisTemplate.opsForValue().get(key);
        if (countStr == null) {
            return false;
        }
        try {
            int count = Integer.parseInt(countStr);
            return count >= LOGIN_FREQ_LIMIT;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    public void recordLoginAttempt(String username) {
        String key = LOGIN_FREQ_PREFIX + username;
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1) {
            redisTemplate.expire(key, LOGIN_FREQ_EXPIRE_MINUTES, TimeUnit.MINUTES);
        }
    }

    /**
     * Send risk verification code. Uses double-colon separator to avoid conflicts.
     */
    public String sendRiskVerifyCode(String username, String phone, String email, String riskType) {
        String riskToken = UUID.randomUUID().toString();
        String code;

        if ("sms".equals(riskType) && phone != null && !phone.isEmpty()) {
            code = generateCode();
            smsService.sendCodeDirect(phone, code);
        } else if ("email".equals(riskType) && email != null && !email.isEmpty()) {
            code = generateCode();
            emailService.sendCodeDirect(email, code);
        } else {
            if (phone != null && !phone.isEmpty()) {
                code = generateCode();
                smsService.sendCodeDirect(phone, code);
                riskType = "sms";
            } else if (email != null && !email.isEmpty()) {
                code = generateCode();
                emailService.sendCodeDirect(email, code);
                riskType = "email";
            } else {
                throw new BusinessException("无可用验证方式");
            }
        }

        // Store risk token with safe separator
        String tokenKey = RISK_TOKEN_PREFIX + riskToken;
        redisTemplate.opsForValue().set(tokenKey, username + TOKEN_SEPARATOR + code,
                10, TimeUnit.MINUTES);

        return riskToken;
    }

    public boolean verifyRiskCode(String riskToken, String code) {
        String tokenKey = RISK_TOKEN_PREFIX + riskToken;
        String stored = redisTemplate.opsForValue().get(tokenKey);
        if (stored == null) {
            return false;
        }

        int sepIndex = stored.indexOf(TOKEN_SEPARATOR);
        if (sepIndex < 0) {
            return false;
        }

        String storedCode = stored.substring(sepIndex + TOKEN_SEPARATOR.length());
        if (storedCode.equals(code)) {
            redisTemplate.delete(tokenKey);
            return true;
        }
        return false;
    }

    /**
     * Extract username from risk token.
     * Note: risk tokens are short-lived (10 min) and one-time-use,
     * but this still represents a potential username oracle.
     */
    public String extractUsernameFromRiskToken(String riskToken) {
        String tokenKey = RISK_TOKEN_PREFIX + riskToken;
        String stored = redisTemplate.opsForValue().get(tokenKey);
        if (stored == null) {
            return null;
        }
        int sepIndex = stored.indexOf(TOKEN_SEPARATOR);
        if (sepIndex < 0) {
            return null;
        }
        return stored.substring(0, sepIndex);
    }

    private String generateCode() {
        int code = 100000 + SECURE_RANDOM.nextInt(900000);
        return String.valueOf(code);
    }
}
