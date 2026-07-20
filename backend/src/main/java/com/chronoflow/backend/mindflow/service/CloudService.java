package com.chronoflow.backend.mindflow.service;

import com.chronoflow.backend.mindflow.dto.CloudDirectoryResponse;
import com.chronoflow.backend.mindflow.dto.ResourceResponse;
import com.chronoflow.backend.mindflow.entity.LearningResource;
import com.chronoflow.backend.mindflow.mapper.LearningResourceMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 云盘服务 — 管理云盘目录和文件夹内资源浏览。
 *
 * 五个文件夹（按资源类型）：
 * - DOC（讲解文档）
 * - MINDMAP（思维导图）
 * - QUIZ（练习题）
 * - READING（拓展材料）
 * - CODE（代码案例）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CloudService {

    private final LearningResourceMapper resourceMapper;

    /**
     * 5个云盘文件夹定义。
     */
    private static final List<FolderDef> FOLDERS = List.of(
            new FolderDef("DOC", "讲解文档", "description"),
            new FolderDef("MINDMAP", "思维导图", "account_tree"),
            new FolderDef("QUIZ", "练习题", "quiz"),
            new FolderDef("READING", "拓展材料", "menu_book"),
            new FolderDef("CODE", "代码案例", "code")
    );

    /**
     * 获取云盘目录结构（5个文件夹 + 各资源计数）。
     */
    public CloudDirectoryResponse getDirectory(Long userId) {
        List<CloudDirectoryResponse.FolderInfo> folders = new ArrayList<>();
        for (FolderDef def : FOLDERS) {
            List<LearningResource> resources = resourceMapper.findByUserIdAndType(userId, def.type);
            folders.add(CloudDirectoryResponse.FolderInfo.builder()
                    .type(def.type)
                    .name(def.name)
                    .icon(def.icon)
                    .count(resources.size())
                    .build());
        }
        return CloudDirectoryResponse.builder().folders(folders).build();
    }

    /**
     * 获取指定文件夹内的资源列表。
     */
    public List<ResourceResponse> getFolderContent(Long userId, String type) {
        return resourceMapper.findByUserIdAndType(userId, type.toUpperCase()).stream()
                .map(this::toResourceResponse)
                .collect(Collectors.toList());
    }

    private ResourceResponse toResourceResponse(LearningResource resource) {
        return ResourceResponse.builder()
                .id(resource.getId())
                .userId(resource.getUserId())
                .sessionId(resource.getSessionId())
                .resourceType(resource.getResourceType())
                .title(resource.getTitle())
                .fileKey(resource.getFileKey())
                .fileSize(resource.getFileSize())
                .content(resource.getContent())
                .metadata(resource.getMetadata())
                .confidenceScore(resource.getConfidenceScore())
                .reviewed(resource.getReviewed())
                .createdAt(resource.getCreatedAt())
                .build();
    }

    /** 文件夹定义 */
    private record FolderDef(String type, String name, String icon) {}
}