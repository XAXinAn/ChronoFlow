package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GroupInviteCodeEntry {
    private String groupName;
    private String inviteCode;
    private int depth;
}