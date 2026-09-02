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
public class GroupImportItem {
    private int rowNumber;
    private String name;
    private String description;
    private String parentName;
    @Deprecated
    private List<String> memberPhones;
    private boolean requireApproval;
    private List<MemberInfo> rawMembers;
    private List<MemberPreviewEntry> members;
}
