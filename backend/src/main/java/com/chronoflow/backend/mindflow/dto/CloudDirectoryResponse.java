package com.chronoflow.backend.mindflow.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 云盘目录响应 — 云盘页面的文件夹结构。
 * 包含5个文件夹（讲解文档/思维导图/练习题/拓展材料/代码案例），每个文件夹含资源计数。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CloudDirectoryResponse {

    private List<FolderInfo> folders;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class FolderInfo {
        /** 资源类型标识 */
        private String type;
        /** 文件夹显示名称 */
        private String name;
        /** 文件夹图标标识 */
        private String icon;
        /** 该文件夹内的资源数量 */
        private int count;
    }
}