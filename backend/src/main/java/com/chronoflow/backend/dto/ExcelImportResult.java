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
public class ExcelImportResult {
    private int successCount;
    private int failCount;
    private List<GroupImportError> failures;
    private List<GroupInviteCodeEntry> groupInviteCodes;
    private List<GroupTreeNode> hierarchyTree;
    private List<MemberAssociationResult> memberAssociationResults;
}