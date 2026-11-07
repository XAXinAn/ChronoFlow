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
public class MemberAssociationResult {
    private String groupName;
    private int associatedCount;
    @Deprecated
    private List<String> unassociatedPhones;
    private List<MemberInviteCodeEntry> unregisteredInviteCodes;
}
