package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ExcelImportPreviewResult {
    private boolean valid;
    private int totalCount;
    private List<GroupImportItem> items;
    private List<GroupImportError> errors;
    private List<GroupTreeNode> previewTree;
    private String importToken;
}