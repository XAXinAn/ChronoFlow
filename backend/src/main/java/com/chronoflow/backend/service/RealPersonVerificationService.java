package com.chronoflow.backend.service;

import com.aliyuncs.DefaultAcsClient;
import com.aliyuncs.profile.DefaultProfile;
import com.aliyuncs.cloudauth.model.v20190307.InitFaceVerifyRequest;
import com.aliyuncs.cloudauth.model.v20190307.InitFaceVerifyResponse;
import com.aliyuncs.cloudauth.model.v20190307.DescribeFaceVerifyRequest;
import com.aliyuncs.cloudauth.model.v20190307.DescribeFaceVerifyResponse;
import com.chronoflow.backend.dto.RealPersonVerifyResultResponse;
import com.chronoflow.backend.exception.BusinessException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;
import java.util.concurrent.TimeUnit;

/**
 * Alibaba Cloud Financial-grade Identity Verification (CloudAuth) service.
 * Supports the ID_PRO scheme: name + ID card number + liveness detection.
 */
@Slf4j
@Service
public class RealPersonVerificationService {

    @Value("${aliyun.cloudauth.access-key-id:}")
    private String accessKeyId;

    @Value("${aliyun.cloudauth.access-key-secret:}")
    private String accessKeySecret;

    @Value("${aliyun.cloudauth.endpoint:cloudauth.cn-shanghai.aliyuncs.com}")
    private String endpoint;

    @Value("${aliyun.cloudauth.scene-id:}")
    private String sceneId;

    private final StringRedisTemplate redisTemplate;

    private volatile boolean configured = false;
    private volatile DefaultAcsClient client;
    private final Object lock = new Object();

    private static final String REGION_ID = "cn-shanghai";

    public RealPersonVerificationService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @PostConstruct
    public void init() {
        if (accessKeyId != null && !accessKeyId.isBlank()
                && accessKeySecret != null && !accessKeySecret.isBlank()
                && sceneId != null && !sceneId.isBlank()) {
            configured = true;
            log.info("RealPersonVerificationService configured (endpoint={})", endpoint);
        } else {
            log.warn("RealPersonVerificationService not configured — verification will be unavailable");
        }
    }

    /**
     * Call Alibaba Cloud InitFaceVerify to get a CertifyId.
     */
    public String initFaceVerify(String metaInfo, String realName, String idCardNumber, Long userId) {
        if (!configured) {
            throw new BusinessException("实人认证服务未配置，请联系管理员");
        }

        try {
            DefaultAcsClient c = getClient();

            InitFaceVerifyRequest request = new InitFaceVerifyRequest();
            request.setSceneId(Long.parseLong(sceneId));
            request.setOuterOrderNo(generateOrderNo(userId));
            request.setProductCode("ID_PRO");
            request.setModel("LIVENESS");
            request.setCertType("IDENTITY_CARD");
            request.setCertName(realName);
            request.setCertNo(idCardNumber);
            request.setMetaInfo(metaInfo);

            InitFaceVerifyResponse response = c.getAcsResponse(request);

            String code = response.getCode();
            if (!"200".equals(code)) {
                log.error("InitFaceVerify failed: code={}, message={}", code, response.getMessage());
                throw new BusinessException("实人认证初始化失败，请稍后重试");
            }

            String certifyId = response.getResultObject() != null
                    ? response.getResultObject().getCertifyId() : null;

            if (certifyId == null || certifyId.isEmpty()) {
                log.error("InitFaceVerify returned empty certifyId");
                throw new BusinessException("实人认证初始化失败，请稍后重试");
            }

            // Store mapping in Redis (30 min TTL)
            String redisKey = "verify:certify:" + certifyId;
            redisTemplate.opsForValue().set(redisKey, userId.toString(), 30, TimeUnit.MINUTES);
            redisTemplate.opsForValue().set(redisKey + ":name", realName, 30, TimeUnit.MINUTES);

            log.info("InitFaceVerify success: userId={}, certifyId={}", userId, certifyId);
            return certifyId;

        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("InitFaceVerify error: {}", e.getMessage());
            throw new BusinessException("实人认证服务暂时不可用，请稍后重试");
        }
    }

    /**
     * InitFaceVerify with retry logic for transient network errors.
     */
    public String initFaceVerifyWithRetry(String metaInfo, String realName, String idCardNumber, Long userId) {
        Exception lastException = null;
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                return initFaceVerify(metaInfo, realName, idCardNumber, userId);
            } catch (BusinessException e) {
                if (attempt < 2 && e.getMessage().contains("暂时不可用")) {
                    try { Thread.sleep((long) (500 * Math.pow(2, attempt))); } catch (InterruptedException ie) { Thread.currentThread().interrupt(); break; }
                    lastException = e;
                    continue;
                }
                throw e;
            }
        }
        throw new BusinessException("实人认证服务暂时不可用（已重试3次），请稍后重试");
    }

    /**
     * Call Alibaba Cloud DescribeFaceVerify to get the verification result.
     */
    public RealPersonVerifyResultResponse describeFaceVerify(String certifyId, Long userId) {
        // Validate certifyId ownership (anti-hijacking)
        String redisKey = "verify:certify:" + certifyId;
        String storedUserId = redisTemplate.opsForValue().get(redisKey);
        if (storedUserId == null) {
            throw new BusinessException("认证会话已过期，请重新认证");
        }
        // Allow userId=0 for registration flow
        if (!"0".equals(storedUserId) && !storedUserId.equals(userId.toString())) {
            log.warn("CertifyId hijacking attempt: certifyId={}, requestUserId={}, storedUserId={}",
                    certifyId, userId, storedUserId);
            throw new BusinessException("认证会话异常，请重新发起认证");
        }

        if (!configured) {
            throw new BusinessException("实人认证服务未配置，请联系管理员");
        }

        try {
            DefaultAcsClient c = getClient();

            DescribeFaceVerifyRequest request = new DescribeFaceVerifyRequest();
            request.setSceneId(Long.parseLong(sceneId));
            request.setCertifyId(certifyId);

            DescribeFaceVerifyResponse response = c.getAcsResponse(request);

            String code = response.getCode();
            if (!"200".equals(code)) {
                log.error("DescribeFaceVerify failed: code={}, message={}", code, response.getMessage());
                throw new BusinessException("查询认证结果失败，请稍后重试");
            }

            String passed = response.getResultObject() != null
                    ? response.getResultObject().getPassed() : null;

            // Clean up Redis regardless of result
            redisTemplate.delete(redisKey);
            redisTemplate.delete(redisKey + ":name");

            if ("T".equals(passed)) {
                log.info("DescribeFaceVerify success: userId={}, certifyId={}, verified=true", userId, certifyId);
                return RealPersonVerifyResultResponse.builder()
                        .verified(true)
                        .message("认证通过")
                        .build();
            } else {
                log.warn("DescribeFaceVerify not passed: userId={}, certifyId={}, passed={}",
                        userId, certifyId, passed);
                return RealPersonVerifyResultResponse.builder()
                        .verified(false)
                        .message("活体检测未通过或身份信息不匹配，请重试")
                        .build();
            }

        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("DescribeFaceVerify error: {}", e.getMessage());
            throw new BusinessException("查询认证结果失败，请稍后重试");
        }
    }

    /**
     * DescribeFaceVerify with retry logic for transient network errors.
     */
    public RealPersonVerifyResultResponse describeFaceVerifyWithRetry(String certifyId, Long userId) {
        Exception lastException = null;
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                return describeFaceVerify(certifyId, userId);
            } catch (BusinessException e) {
                if (attempt < 2 && e.getMessage().contains("暂时不可用")) {
                    try { Thread.sleep((long) (500 * Math.pow(2, attempt))); } catch (InterruptedException ie) { Thread.currentThread().interrupt(); break; }
                    lastException = e;
                    continue;
                }
                throw e;
            }
        }
        throw new BusinessException("查询认证结果失败（已重试3次），请稍后重试");
    }

    private DefaultAcsClient getClient() {
        if (client == null) {
            synchronized (lock) {
                if (client == null) {
                    DefaultProfile profile = DefaultProfile.getProfile(REGION_ID, accessKeyId, accessKeySecret);
                    client = new DefaultAcsClient(profile);
                }
            }
        }
        return client;
    }

    private String generateOrderNo(Long userId) {
        return "verify-" + userId + "-" + System.currentTimeMillis() + "-"
                + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
    }
}
