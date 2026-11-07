package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.dto.ExcelImportConfirmRequest;
import com.chronoflow.backend.dto.ExcelImportPreviewResult;
import com.chronoflow.backend.dto.ExcelImportResult;
import com.chronoflow.backend.service.ExcelImportService;
import com.chronoflow.backend.service.excel.ExcelTemplateBuilder;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@Slf4j
@RestController
@RequestMapping("/api/group/import")
public class ExcelImportController {

    private final ExcelImportService excelImportService;
    private final ExcelTemplateBuilder excelTemplateBuilder;

    public ExcelImportController(@Autowired ExcelImportService excelImportService,
                                 @Autowired ExcelTemplateBuilder excelTemplateBuilder) {
        this.excelImportService = excelImportService;
        this.excelTemplateBuilder = excelTemplateBuilder;
    }

    @GetMapping("/template")
    public ResponseEntity<Resource> downloadTemplate() {
        byte[] template = excelTemplateBuilder.buildTemplate();
        ByteArrayResource resource = new ByteArrayResource(template);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"group_import_template.xlsx\"")
                .body(resource);
    }

    @PostMapping(value = "/preview", consumes = "multipart/form-data")
    public ResponseEntity<ApiResponse<ExcelImportPreviewResult>> preview(
            HttpServletRequest request,
            @RequestParam("file") MultipartFile file) {
        Long userId = (Long) request.getAttribute("userId");
        log.debug("收到Excel导入预览请求: userId={}, 文件大小={}bytes", userId, file.getSize());
        ExcelImportPreviewResult result = excelImportService.preview(userId, file);
        String message = result.isValid() ? "校验通过" : "校验失败，请修改后重试";
        return ResponseEntity.ok(ApiResponse.success(message, result));
    }

    @PostMapping("/confirm")
    public ResponseEntity<ApiResponse<ExcelImportResult>> confirm(
            HttpServletRequest request,
            @RequestBody ExcelImportConfirmRequest confirmRequest) {
        Long userId = (Long) request.getAttribute("userId");
        log.debug("收到Excel导入确认请求: userId={}", userId);
        ExcelImportResult result = excelImportService.confirm(userId, confirmRequest.getImportToken());
        return ResponseEntity.ok(ApiResponse.success("导入成功", result));
    }
}