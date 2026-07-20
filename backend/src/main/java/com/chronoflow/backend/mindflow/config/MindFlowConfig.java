package com.chronoflow.backend.mindflow.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/*MindFlow 配置属性 */
@Data
@Configuration
@ConfigurationProperties(prefix = "mindflow")
public class MindFlowConfig {

    /** 星火API配置 */
    private Spark spark = new Spark();

    /** Agent配置 */
    private Agent agent = new Agent();

    /** WebSearch联网检索配置 */
    private WebSearch websearch = new WebSearch();

    /** 资源生成限制配置 */
    private Resource resource = new Resource();

    /** Milvus向量数据库配置 */
    private Milvus milvus = new Milvus();

    @Data
    public static class Spark {
        private String apiKey;
        private String baseUrl = "https://maas-api.cn-huabei-1.xf-yun.com/v2";
        private String model = "xsparkx2flash";
        private double temperature = 0.7;
    }

    @Data
    public static class Agent {
        private long executionTimeoutMs = 30000;
        private long intentClassifyTimeoutMs = 5000;
    }

    @Data
    public static class WebSearch {
        private boolean enabled = true;
        private long timeoutMs = 5000;
    }

    @Data
    public static class Resource {
        private int maxPerDay = 30;
        private int cacheHours = 1;
    }

    @Data
    public static class Milvus {
        private String dbPath = "/app/data/milvus_lite.db";
        private String embeddingModel = "text-embedding-v1";
    }
}