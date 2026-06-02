package com.chronoflow.backend.service;

import com.aliyun.dm20151123.Client;
import com.aliyun.dm20151123.models.SingleSendMailRequest;
import com.aliyun.dm20151123.models.SingleSendMailResponse;
import com.aliyun.teaopenapi.models.Config;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;

import java.util.concurrent.TimeUnit;

@Service
@Slf4j
public class EmailService {

    private final RedisTemplate<String, String> redisTemplate;

    @Value("${aliyun.dm.access-key-id:}")
    private String accessKeyId;

    @Value("${aliyun.dm.access-key-secret:}")
    private String accessKeySecret;

    @Value("${aliyun.dm.account-name:}")
    private String accountName;

    @Value("${aliyun.dm.from-alias:时纪流}")
    private String fromAlias;

    private static final String EMAIL_CODE_PREFIX = "email:code:";
    private static final int CODE_EXPIRE_MINUTES = 5;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private volatile Client client;
    private volatile boolean configured = false;

    public EmailService(RedisTemplate<String, String> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @PostConstruct
    public void init() {
        configured = accessKeyId != null && !accessKeyId.isEmpty()
                && accessKeySecret != null && !accessKeySecret.isEmpty()
                && accountName != null && !accountName.isEmpty();
        if (!configured) {
            log.warn("Email service not configured - emails will not be sent in production");
        }
    }

    private Client getClient() throws Exception {
        if (client == null) {
            synchronized (this) {
                if (client == null) {
                    Config config = new Config()
                            .setAccessKeyId(accessKeyId)
                            .setAccessKeySecret(accessKeySecret)
                            .setEndpoint("dm.aliyuncs.com");
                    client = new Client(config);
                }
            }
        }
        return client;
    }

    public String sendVerificationCode(String email) {
        String code = generateCode();

        if (!configured) {
            saveCode(email, code);
            log.info("[模拟邮箱验证码] email={}, code={}", email, code);
            return "验证码已发送（开发模式）";
        }

        try {
            sendSingleMail(email, "ChronoFlow 验证码", buildVerificationEmailBody(code));
            saveCode(email, code);
            log.info("Verification email sent to: {}", email);
            return "验证码已发送";
        } catch (Exception e) {
            log.error("Failed to send verification email to {}: {}", email, e.getMessage());
            return "验证码发送失败，请稍后重试";
        }
    }

    public boolean verifyCode(String email, String code) {
        String key = EMAIL_CODE_PREFIX + email;
        String storedCode = redisTemplate.opsForValue().get(key);

        if (storedCode == null) {
            return false;
        }

        if (storedCode.equals(code)) {
            redisTemplate.delete(key);
            return true;
        }

        return false;
    }

    public boolean sendCodeDirect(String email, String code) {
        if (!configured) {
            log.info("Email not configured, [MOCK] email={}, code={}", email, code);
            return false;
        }

        try {
            sendSingleMail(email, "ChronoFlow 安全验证码", buildVerificationEmailBody(code));
            log.info("Verification email sent to: {}", email);
            return true;
        } catch (Exception e) {
            log.error("Failed to send email to {}: {}", email, e.getMessage());
            return false;
        }
    }

    private void sendSingleMail(String toAddress, String subject, String htmlBody) throws Exception {
        Client c = getClient();

        SingleSendMailRequest request = new SingleSendMailRequest()
                .setAccountName(accountName)
                .setAddressType(1)
                .setReplyToAddress(true)
                .setToAddress(toAddress)
                .setSubject(subject)
                .setHtmlBody(htmlBody)
                .setFromAlias(fromAlias);

        SingleSendMailResponse response = c.singleSendMail(request);
        log.debug("Email sent: {} - requestId: {}", toAddress, response.getBody().getRequestId());
    }

    private String buildVerificationEmailBody(String code) {
        return """
                <div style="max-width:480px;margin:40px auto;font-family:Arial,sans-serif;">
                  <div style="background:#000;padding:20px;text-align:center;">
                    <span style="color:#fff;font-size:24px;font-weight:300;">时纪流</span>
                  </div>
                  <div style="background:#fff;padding:30px;border:1px solid #e0e0e0;border-top:none;">
                    <p style="font-size:16px;color:#333;">您的验证码是：</p>
                    <p style="font-size:32px;font-weight:bold;color:#000;letter-spacing:6px;text-align:center;margin:24px 0;">%s</p>
                    <p style="font-size:13px;color:#999;">验证码 %d 分钟内有效，请勿泄露给他人。</p>
                  </div>
                  <div style="text-align:center;padding:16px;">
                    <span style="font-size:12px;color:#ccc;">ChronoFlow 时纪流</span>
                  </div>
                </div>
                """.formatted(code, CODE_EXPIRE_MINUTES);
    }

    private String generateCode() {
        int code = 100000 + SECURE_RANDOM.nextInt(900000);
        return String.valueOf(code);
    }

    private void saveCode(String email, String code) {
        String key = EMAIL_CODE_PREFIX + email;
        redisTemplate.opsForValue().set(key, code, CODE_EXPIRE_MINUTES, TimeUnit.MINUTES);
    }
}
