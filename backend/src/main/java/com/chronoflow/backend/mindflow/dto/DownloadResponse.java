package com.chronoflow.backend.mindflow.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 资源下载响应 — 返回 MinIO 公开访问 URL 及文件元信息。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DownloadResponse {

    /** MinIO 公开访问 URL，前端直接跳转下载 */
    private String url;

    /** 建议的文件名 */
    private String filename;

    /** 文件大小（字节） */
    private Long fileSize;

    /** MIME 类型 */
    private String mimeType;
}
