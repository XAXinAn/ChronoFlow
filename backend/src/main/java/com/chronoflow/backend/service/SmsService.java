package com.chronoflow.backend.service;

import com.aliyun.dysmsapi20170525.Client;
import com.aliyun.dysmsapi20170525.models.SendSmsRequest;
import com.aliyun.dysmsapi20170525.models.SendSmsResponse;
import com.aliyun.teaopenapi.models.Config;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;

import java.util.concurrent.TimeUnit;

@Service
@Slf4j
public class SmsService {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private final RedisTemplate<String, String> redisTemplate;

    @Value("${aliyun.sms.access-key-id:}")
    private String accessKeyId;

    @Value("${aliyun.sms.access-key-secret:}")
    private String accessKeySecret;

    @Value("${aliyun.sms.sign-name:}")
    private String signName;

    @Value("${aliyun.sms.template-code:}")
    private String templateCode;

    private static final String SMS_CODE_PREFIX = "sms:code:";
    private static final int CODE_EXPIRE_MINUTES = 5;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private volatile Client client;
    private volatile boolean configured = false;

    public SmsService(RedisTemplate<String, String> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @PostConstruct
    public void init() {
        configured = accessKeyId != null && !accessKeyId.isEmpty()
                && accessKeySecret != null && !accessKeySecret.isEmpty()
                && signName != null && !signName.isEmpty()
                && templateCode != null && !templateCode.isEmpty();
        if (!configured) {
            log.warn("SMS service not configured - SMS will not be sent in production");
        }
    }

    private Client getClient() throws Exception {
        if (client == null) {
            synchronized (this) {
                if (client == null) {
                    Config config = new Config()
                            .setAccessKeyId(accessKeyId)
                            .setAccessKeySecret(accessKeySecret)
                            .setEndpoint("dysmsapi.aliyuncs.com");
                    client = new Client(config);
                }
            }
        }
        return client;
    }

    public String sendVerificationCode(String phone) {
        if (!configured) {
            log.warn("SMS service not configured, using mock code");
            return sendMockCode(phone);
        }

        try {
            String code = generateCode();

            // Build template params safely using ObjectMapper
            ObjectNode paramsNode = OBJECT_MAPPER.createObjectNode();
            paramsNode.put("code", code);
            String templateParam = OBJECT_MAPPER.writeValueAsString(paramsNode);

            Client c = getClient();
            SendSmsRequest request = new SendSmsRequest()
                    .setPhoneNumbers(phone)
                    .setSignName(signName)
                    .setTemplateCode(templateCode)
                    .setTemplateParam(templateParam);

            SendSmsResponse response = c.sendSms(request);

            if (response.getBody() != null && "OK".equals(response.getBody().getCode())) {
                saveCode(phone, code);
                log.info("SMS sent successfully: {}", phone);
                return "验证码已发送";
            } else {
                String errMsg = response.getBody() != null ? response.getBody().getMessage() : "未知错误";
                log.error("SMS send failed: {} - {}", phone, errMsg);
                return "发送失败，请稍后重试";
            }
        } catch (Exception e) {
            log.error("SMS send exception for {}: {}", phone, e.getMessage());
            return "发送异常，请稍后重试";
        }
    }

    private String sendMockCode(String phone) {
        String code = generateCode();
        saveCode(phone, code);
        log.info("[MOCK SMS] phone={}, code={}", phone, code);
        return "验证码已发送（开发模式）";
    }

    private String generateCode() {
        int code = 100000 + SECURE_RANDOM.nextInt(900000);
        return String.valueOf(code);
    }

    private void saveCode(String phone, String code) {
        String key = SMS_CODE_PREFIX + phone;
        redisTemplate.opsForValue().set(key, code, CODE_EXPIRE_MINUTES, TimeUnit.MINUTES);
    }

    public boolean verifyCode(String phone, String code) {
        String key = SMS_CODE_PREFIX + phone;
        String storedCode = redisTemplate.opsForValue().get(key);

        if (storedCode == null) {
            return false;
        }

        return storedCode.equals(code);
    }

    /**
     * Consume a verification code after successful business logic.
     * Call this only after the entire flow (e.g. login/registration) succeeds.
     */
    public void consumeCode(String phone) {
        String key = SMS_CODE_PREFIX + phone;
        redisTemplate.delete(key);
    }

    /**
     * Send a verification code directly (for risk control).
     * Returns true if sent successfully, false otherwise.
     */
    public boolean sendCodeDirect(String phone, String code) {
        if (!configured) {
            log.info("[MOCK SMS] phone={}, code={}", phone, code);
            return false;
        }

        try {
            ObjectNode paramsNode = OBJECT_MAPPER.createObjectNode();
            paramsNode.put("code", code);
            String templateParam = OBJECT_MAPPER.writeValueAsString(paramsNode);

            Client c = getClient();
            SendSmsRequest request = new SendSmsRequest()
                    .setPhoneNumbers(phone)
                    .setSignName(signName)
                    .setTemplateCode(templateCode)
                    .setTemplateParam(templateParam);

            c.sendSms(request);
            log.info("Risk control SMS sent: {}", phone);
            return true;
        } catch (Exception e) {
            log.error("Risk control SMS send failed for {}: {}", phone, e.getMessage());
            return false;
        }
    }
}
