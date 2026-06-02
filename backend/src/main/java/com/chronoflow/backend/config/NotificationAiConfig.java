package com.chronoflow.backend.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Data
@Configuration
@ConfigurationProperties(prefix = "notification.ai")
public class NotificationAiConfig {

    /**
     * 使用的模型 - qwen-flash是最快的模型
     */
    private String model = "qwen-flash";

    /**
     * 随机度，0为最低
     */
    private Double temperature = 0.0;
}