package com.chronoflow.backend.service;

import com.chronoflow.backend.exception.BusinessException;
import io.minio.*;
import io.minio.http.Method;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
public class MinioService {

    @Value("${minio.endpoint:http://localhost:9000}")
    private String endpoint;

    @Value("${minio.access-key:minioadmin}")
    private String accessKey;

    @Value("${minio.secret-key:minioadmin}")
    private String secretKey;

    @Value("${minio.bucket:chronoflow}")
    private String bucket;

    @Value("${minio.base-url:http://localhost:9000/chronoflow}")
    private String baseUrl;

    private volatile MinioClient client;
    private volatile boolean configured = false;

    @PostConstruct
    public void init() {
        configured = accessKey != null && !accessKey.isBlank()
                && secretKey != null && !secretKey.isBlank();
        if (configured) {
            try {
                MinioClient c = getClient();
                boolean exists = c.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
                if (!exists) {
                    c.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
                    log.info("Created MinIO bucket: {}", bucket);
                }
                log.info("MinioService configured: endpoint={}, bucket={}", endpoint, bucket);
            } catch (Exception e) {
                log.error("Failed to initialize MinIO bucket: {}", e.getMessage());
                configured = false;
            }
        } else {
            log.warn("MinioService not configured — file upload will be unavailable");
        }
    }

    /**
     * Upload file bytes to MinIO. Returns the public access URL.
     */
    public String upload(byte[] bytes, String objectName, String contentType) {
        if (!configured) throw new BusinessException("对象存储未配置");
        try {
            MinioClient c = getClient();
            c.putObject(PutObjectArgs.builder()
                    .bucket(bucket)
                    .object(objectName)
                    .stream(new ByteArrayInputStream(bytes), bytes.length, -1)
                    .contentType(contentType)
                    .build());
            return baseUrl + "/" + objectName;
        } catch (Exception e) {
            log.error("MinIO upload failed: {}", e.getMessage());
            throw new BusinessException("图片上传失败，请稍后重试");
        }
    }

    private MinioClient getClient() {
        if (client == null) {
            synchronized (this) {
                if (client == null) {
                    client = MinioClient.builder()
                            .endpoint(endpoint)
                            .credentials(accessKey, secretKey)
                            .build();
                }
            }
        }
        return client;
    }
}
