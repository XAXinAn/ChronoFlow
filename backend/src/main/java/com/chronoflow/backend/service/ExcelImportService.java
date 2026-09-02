package com.chronoflow.backend.service;

import com.chronoflow.backend.dto.*;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.service.excel.BatchGroupCreator;
import com.chronoflow.backend.service.excel.ExcelParser;
import com.chronoflow.backend.service.excel.ImportValidator;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
public class ExcelImportService {

    private final ExcelParser excelParser;
    private final ImportValidator importValidator;
    private final BatchGroupCreator batchGroupCreator;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    @Value("${excel.max-size-mb:5}")
    private int maxSizeMb;

    @Value("${excel.import-token-ttl-minutes:10}")
    private int tokenTtlMinutes;

    public ExcelImportService(ExcelParser excelParser, ImportValidator importValidator,
                              BatchGroupCreator batchGroupCreator, StringRedisTemplate redisTemplate) {
        this.excelParser = excelParser;
        this.importValidator = importValidator;
        this.batchGroupCreator = batchGroupCreator;
        this.redisTemplate = redisTemplate;
        this.objectMapper = new ObjectMapper();
    }

    public ExcelImportPreviewResult preview(Long userId, MultipartFile file) {
        validateFileSize(file.getSize());

        byte[] excelBytes;
        try {
            excelBytes = file.getBytes();
        } catch (Exception e) {
            throw new BusinessException("文件读取失败，请重试");
        }

        List<GroupImportItem> items = excelParser.parse(excelBytes);
        List<GroupImportError> errors = importValidator.validate(items, userId);

        if (!errors.isEmpty()) {
            return ExcelImportPreviewResult.builder()
                    .valid(false)
                    .totalCount(items.size())
                    .items(items)
                    .errors(errors)
                    .previewTree(Collections.emptyList())
                    .importToken(null)
                    .build();
        }

        String importToken = UUID.randomUUID().toString().replace("-", "");
        try {
            String json = objectMapper.writeValueAsString(items);
            String redisKey = "excel:import:" + userId + ":" + importToken;
            redisTemplate.opsForValue().set(redisKey, json, tokenTtlMinutes, TimeUnit.MINUTES);
        } catch (Exception e) {
            log.error("缓存导入数据失败: {}", e.getMessage());
            throw new BusinessException("系统繁忙，请重试");
        }

        List<GroupTreeNode> previewTree = buildPreviewTree(items);

        return ExcelImportPreviewResult.builder()
                .valid(true)
                .totalCount(items.size())
                .items(items)
                .errors(Collections.emptyList())
                .previewTree(previewTree)
                .importToken(importToken)
                .build();
    }

    public ExcelImportResult confirm(Long userId, String importToken) {
        if (importToken == null || importToken.isBlank()) {
            throw new BusinessException("预览数据已过期，请重新上传");
        }

        String redisKey = "excel:import:" + userId + ":" + importToken;
        String json = redisTemplate.opsForValue().get(redisKey);
        if (json == null) {
            throw new BusinessException("预览数据已过期，请重新上传");
        }

        List<GroupImportItem> items;
        try {
            items = objectMapper.readValue(json, new TypeReference<List<GroupImportItem>>() {});
        } catch (Exception e) {
            log.error("反序列化导入数据失败: {}", e.getMessage());
            throw new BusinessException("数据解析失败，请重新上传");
        }

        ExcelImportResult result = batchGroupCreator.create(items, userId);

        redisTemplate.delete(redisKey);
        log.info("Excel导入完成: userId={}, 成功={}, 失败={}", userId, result.getSuccessCount(), result.getFailCount());

        return result;
    }

    private void validateFileSize(long size) {
        long maxBytes = (long) maxSizeMb * 1024 * 1024;
        if (size > maxBytes) {
            throw new BusinessException("文件过大，上限 " + maxSizeMb + "MB");
        }
    }

    private List<GroupTreeNode> buildPreviewTree(List<GroupImportItem> items) {
        java.util.Map<String, List<GroupImportItem>> childrenMap = new java.util.HashMap<>();
        List<GroupImportItem> roots = new java.util.ArrayList<>();
        java.util.Set<String> names = new java.util.HashSet<>();
        for (GroupImportItem item : items) names.add(item.getName());

        for (GroupImportItem item : items) {
            String parent = item.getParentName();
            if (parent == null || parent.isBlank() || !names.contains(parent)) {
                roots.add(item);
            } else {
                childrenMap.computeIfAbsent(parent, k -> new java.util.ArrayList<>()).add(item);
            }
        }

        List<GroupTreeNode> tree = new java.util.ArrayList<>();
        for (GroupImportItem root : roots) {
            tree.add(buildPreviewNode(root, childrenMap, 0));
        }
        return tree;
    }

    private GroupTreeNode buildPreviewNode(GroupImportItem item,
                                           java.util.Map<String, List<GroupImportItem>> childrenMap, int depth) {
        List<GroupTreeNode> children = new java.util.ArrayList<>();
        List<GroupImportItem> childItems = childrenMap.get(item.getName());
        if (childItems != null) {
            for (GroupImportItem child : childItems) {
                children.add(buildPreviewNode(child, childrenMap, depth + 1));
            }
        }
        return GroupTreeNode.builder().name(item.getName()).depth(depth).children(children).build();
    }
}