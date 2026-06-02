package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GroupResponse {
    private String id;
    private String name;
    private String description;
    private String inviteCode;
    private Integer memberCount;
    private Long creatorId;
    private LocalDateTime createdAt;
    private Boolean requireApproval;
    private Boolean pendingApproval;
    private Boolean isAdminOrCreator;
}
