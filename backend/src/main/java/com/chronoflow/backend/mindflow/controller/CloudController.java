package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.mindflow.dto.CloudDirectoryResponse;
import com.chronoflow.backend.mindflow.dto.ResourceResponse;
import com.chronoflow.backend.mindflow.entity.LearningResource;
import com.chronoflow.backend.mindflow.mapper.LearningResourceMapper;
import com.chronoflow.backend.mindflow.service.CloudService;
import com.chronoflow.backend.service.MinioService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.io.*;
import java.net.URL;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * 云盘控制器 — 云盘目录浏览和文件夹内容查询接口。
 *
 * 接口清单：
 * - GET /api/v1/cloud/directory         云盘目录（5个文件夹 + 计数）
 * - GET /api/v1/cloud/folder/{type}     文件夹内资源列表
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/cloud")
@RequiredArgsConstructor
public class CloudController {

    private final CloudService cloudService;
    private final LearningResourceMapper resourceMapper;
    private final MinioService minioService;

    /**
     * 获取云盘目录结构。
     * GET /api/v1/cloud/directory
     *
     * 返回5个文件夹及其资源计数：
     * DOC(讲解文档) / MINDMAP(思维导图) / QUIZ(练习题) / READING(拓展材料) / CODE(代码案例)
     */
    @GetMapping("/directory")
    public ResponseEntity<ApiResponse<CloudDirectoryResponse>> getDirectory(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        CloudDirectoryResponse directory = cloudService.getDirectory(userId);
        return ResponseEntity.ok(ApiResponse.success("查询成功", directory));
    }

    /**
     * 获取指定文件夹内的资源列表。
     * GET /api/v1/cloud/folder/{type}
     *
     * @param type 资源类型：doc/mindmap/quiz/reading/code
     */
    @GetMapping("/folder/{type}")
    public ResponseEntity<ApiResponse<List<ResourceResponse>>> getFolderContent(
            HttpServletRequest request,
            @PathVariable String type) {

        Long userId = (Long) request.getAttribute("userId");
        List<ResourceResponse> resources = cloudService.getFolderContent(userId, type);
        return ResponseEntity.ok(ApiResponse.success("查询成功", resources));
    }

    /**
     * 批量导出文件夹内所有资源为 ZIP。
     * GET /api/v1/cloud/folder/{type}/export
     *
     * 流式从 MinIO 读取文件写入 ZIP，不占用大内存。
     * fileKey 为空的旧资源跳过不包含在 ZIP 中。
     */
    @GetMapping("/folder/{type}/export")
    public ResponseEntity<StreamingResponseBody> exportFolder(
            HttpServletRequest request,
            @PathVariable String type) throws IOException {

        Long userId = (Long) request.getAttribute("userId");
        List<LearningResource> resources = resourceMapper.findByUserIdAndType(userId, type.toUpperCase());

        String zipFilename = type.toLowerCase() + "_export_" + System.currentTimeMillis() + ".zip";

        HttpHeaders headers = new HttpHeaders();
        headers.set(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_OCTET_STREAM_VALUE);
        headers.set(HttpHeaders.CONTENT_DISPOSITION,
                "attachment; filename=\"" + zipFilename + "\"; filename*=UTF-8''" + zipFilename);

        StreamingResponseBody stream = outputStream -> {
            try (ZipOutputStream zipOut = new ZipOutputStream(
                    new BufferedOutputStream(outputStream))) {
                for (LearningResource resource : resources) {
                    if (resource.getFileKey() == null || resource.getFileKey().isEmpty()) {
                        continue; // 跳过旧资源
                    }
                    String entryName = sanitizeFilename(resource.getTitle()) + ".md";
                    zipOut.putNextEntry(new ZipEntry(entryName));

                    String url = minioService.getResourceUrl(resource.getFileKey());
                    try (InputStream minioStream = new URL(url).openStream()) {
                        minioStream.transferTo(zipOut);
                    }
                    zipOut.closeEntry();
                }
            }
        };

        return ResponseEntity.ok().headers(headers).body(stream);
    }

    /** 过滤文件名中的非法字符 */
    private String sanitizeFilename(String name) {
        if (name == null) return "unnamed";
        return name.replaceAll("[\\\\/:*?\"<>|]", "_");
    }
}