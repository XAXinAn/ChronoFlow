package com.chronoflow.backend.service;
import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.exception.BusinessException;
import com.aliyun.green20220302.Client;
import com.aliyun.green20220302.models.TextModerationPlusRequest;
import com.aliyun.green20220302.models.TextModerationPlusResponse;
import com.aliyun.green20220302.models.TextModerationPlusResponseBody;
import com.aliyun.teaopenapi.models.Config;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
@Slf4j
public class ContentModerationService {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    @Value("${aliyun.green.access-key-id:}")
    private String accessKeyId;

    @Value("${aliyun.green.access-key-secret:}")
    private String accessKeySecret;

    @Value("${aliyun.green.service:ugc_moderation_byllm}")
    private String service;

    @Value("${aliyun.green.endpoint:green-cs.cn-shanghai.aliyuncs.com}")
    private String endpoint;

    private volatile Client client;
    private volatile boolean configured = false;

    @PostConstruct
    private void init() {
        configured = accessKeyId != null && !accessKeyId.isEmpty()
                && accessKeySecret != null && !accessKeySecret.isEmpty();
    }

    private Client getClient() throws Exception {
        if (client == null) {
            synchronized (this) {
                if (client == null) {
                    Config config = new Config()
                            .setAccessKeyId(accessKeyId)
                            .setAccessKeySecret(accessKeySecret)
                            .setEndpoint(endpoint);
                    client = new Client(config);
                }
            }
        }
        return client;
    }

    /**
     * Moderate text content. Returns null if passed, or a rejection reason string if rejected.
     * Throws if moderation service is not configured.
     */
    public String moderate(String text) {
        if (text == null || text.isBlank()) {
            return null;
        }
        if (!configured) {
            throw new ContentModerationException("内容审核服务未配置");
        }

        try {
            // Build service parameters using ObjectMapper for safe JSON construction
            ObjectNode paramsNode = OBJECT_MAPPER.createObjectNode();
            paramsNode.put("content", text);
            String paramsJson = OBJECT_MAPPER.writeValueAsString(paramsNode);

            Client c = getClient();

            TextModerationPlusRequest request = new TextModerationPlusRequest()
                    .setService(service)
                    .setServiceParameters(paramsJson);

            TextModerationPlusResponse response = c.textModerationPlus(request);
            TextModerationPlusResponseBody body = response.getBody();

            if (body == null || body.getCode() == null || body.getCode() != 200) {
                log.error("Content moderation API error: code={}, message={}",
                        body != null ? body.getCode() : null,
                        body != null ? body.getMessage() : null);
                throw new BusinessException("内容审核服务暂时不可用，请稍后重试");
            }

            TextModerationPlusResponseBody.TextModerationPlusResponseBodyData data = body.getData();
            if (data == null) {
                return null;
            }

            String riskLevel = data.getRiskLevel();
            if ("high".equals(riskLevel)) {
                String reason = buildReason(data.getResult());
                log.info("Content moderation rejected: riskLevel={}, reason={}", riskLevel, reason);
                return reason;
            }

            log.debug("Content moderation passed: riskLevel={}", riskLevel);
            return null;
        } catch (ContentModerationException e) {
            throw e;
        } catch (Exception e) {
            log.error("Content moderation service unavailable, blocking content: {}", e.getMessage());
            throw new BusinessException("内容审核服务暂时不可用，请稍后重试");
        }
    }

    private String buildReason(List<TextModerationPlusResponseBody.TextModerationPlusResponseBodyDataResult> results) {
        return "输入内容包含不当信息，请修改后重试";
    }
}
