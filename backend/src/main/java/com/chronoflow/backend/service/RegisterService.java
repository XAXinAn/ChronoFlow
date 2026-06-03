package com.chronoflow.backend.service;

import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.dto.RegisterConfirmRequest;
import com.chronoflow.backend.dto.RegisterResponse;
import com.chronoflow.backend.dto.RegisterVerifyRequest;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.UserMapper;
import com.chronoflow.backend.util.CryptoUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.concurrent.TimeUnit;

/**
 * Two-step registration with mandatory real-person verification.
 *
 * Step 1: initRegistration — validates all reg fields, initiates face verification,
 *          stores pending data in Redis, returns certifyId.
 * Step 2: confirmRegistration — verifies face result, checks real-name uniqueness,
 *          creates user account with realNameVerified=true.
 */
@Service
@RequiredArgsConstructor
public class RegisterService {

    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final SmsService smsService;
    private final ContentModerationService contentModerationService;
    private final RealPersonVerificationService realPersonVerificationService;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    @Value("${crypto.secret:${jwt.secret:default-crypto-key-32chars}}")
    private String cryptoSecret;

    private static final String PENDING_REG_KEY_PREFIX = "reg:pending:";
    private static final long PENDING_TTL_MINUTES = 30;

    /**
     * Step 1: Validate registration info + initiate real-person verification.
     * Does NOT create the user account yet.
     *
     * @return certifyId for the client SDK to start face verification
     */
    public String initRegistration(RegisterVerifyRequest request) {
        // 1. Verify SMS code
        if (!smsService.verifyCode(request.getPhone(), request.getCode())) {
            throw new BusinessException("验证码错误或已过期");
        }

        // 2. Check username uniqueness
        if (userMapper.selectCount(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, request.getUsername())) > 0) {
            throw new BusinessException("用户名已存在");
        }

        // 3. Check phone uniqueness
        if (userMapper.selectCount(new LambdaQueryWrapper<User>()
                .eq(User::getPhone, request.getPhone())) > 0) {
            throw new BusinessException("手机号已被注册");
        }

        // 4. Content moderation on username
        String reason = contentModerationService.moderate(request.getUsername());
        if (reason != null) {
            throw new ContentModerationException(reason);
        }

        // 5. Initiate face verification via Alibaba Cloud
        String certifyId = realPersonVerificationService.initFaceVerify(
                request.getMetaInfo(),
                request.getRealName(),
                request.getIdCardNumber(),
                0L); // userId is 0 because user doesn't exist yet

        // 6. Store pending registration data in Redis (TTL 30 min)
        String pendingKey = PENDING_REG_KEY_PREFIX + certifyId;
        PendingRegistration pending = new PendingRegistration(
                request.getPhone(),
                request.getUsername(),
                passwordEncoder.encode(request.getPassword()),
                request.getRealName(),
                CryptoUtil.encrypt(request.getIdCardNumber(), cryptoSecret));
        try {
            redisTemplate.opsForValue().set(pendingKey, objectMapper.writeValueAsString(pending),
                    PENDING_TTL_MINUTES, TimeUnit.MINUTES);
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            throw new BusinessException("系统错误，请重试");
        }

        return certifyId;
    }

    /**
     * Step 2: After face SDK completes, confirm registration and create account.
     * Checks real-name uniqueness (one real person = one account) before creating.
     *
     * @return RegisterResponse with the newly created user
     */
    @Transactional
    public RegisterResponse confirmRegistration(RegisterConfirmRequest request) {
        String certifyId = request.getCertifyId();
        String pendingKey = PENDING_REG_KEY_PREFIX + certifyId;

        // 1. Load pending registration data from Redis
        String pendingJson = redisTemplate.opsForValue().get(pendingKey);
        if (pendingJson == null) {
            throw new BusinessException("注册会话已过期，请重新注册");
        }
        PendingRegistration pending;
        try {
            pending = objectMapper.readValue(pendingJson, PendingRegistration.class);
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            throw new BusinessException("系统错误，请重试");
        }

        // 2. Verify face verification result
        var verifyResult = realPersonVerificationService.describeFaceVerify(certifyId, 0L);
        if (!verifyResult.isVerified()) {
            // Clean up pending data on failure
            redisTemplate.delete(pendingKey);
            throw new BusinessException(verifyResult.getMessage());
        }

        // 3. Check real-name uniqueness: one real person = one account
        // We check if any existing verified user has the same encrypted ID card number
        String encryptedIdCard = pending.getIdCardNumber();
        if (userMapper.selectCount(new LambdaQueryWrapper<User>()
                .eq(User::getIdCardNumber, encryptedIdCard)
                .eq(User::getRealNameVerified, true)) > 0) {
            redisTemplate.delete(pendingKey);
            throw new BusinessException("该实名信息已被其他账号绑定");
        }

        // 4. Create user account
        String phone = pending.getPhone();
        String lastFourPhone = phone.length() >= 4 ? phone.substring(phone.length() - 4) : phone;
        String nickname = lastFourPhone + "用户";

        User user = User.builder()
                .username(pending.getUsername())
                .nickname(nickname)
                .phone(phone)
                .password(pending.getPassword())
                .realNameVerified(true)
                .realName(pending.getRealName())
                .idCardNumber(encryptedIdCard)
                .verifiedAt(java.time.LocalDateTime.now())
                .build();

        userMapper.insert(user);

        // 5. Clean up pending data
        redisTemplate.delete(pendingKey);

        return RegisterResponse.builder()
                .id(user.getId())
                .username(user.getUsername())
                .nickname(user.getNickname())
                .phone(user.getPhone())
                .build();
    }

    /**
     * Pending registration data stored in Redis while awaiting face verification.
     */
    @lombok.Data
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class PendingRegistration {
        private String phone;
        private String username;
        private String password; // already BCrypt encoded
        private String realName;
        private String idCardNumber; // AES encrypted
    }
}
