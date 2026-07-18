package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.mindflow.dto.CloudDirectoryResponse;
import com.chronoflow.backend.mindflow.dto.ResourceResponse;
import com.chronoflow.backend.mindflow.service.CloudService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

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
}