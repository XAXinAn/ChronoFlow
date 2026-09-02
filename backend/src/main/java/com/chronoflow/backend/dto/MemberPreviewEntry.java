package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MemberPreviewEntry {
    private int rowNumber;
    private String name;
    private String studentId;
    private String email;
    private String phone;
    private String registrationStatus;
    private String matchedNickname;
    private Long matchedUserId;
}
