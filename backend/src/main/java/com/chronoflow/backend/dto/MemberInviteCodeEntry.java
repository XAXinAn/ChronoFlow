package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MemberInviteCodeEntry {
    private String inviteCode;
    private String maskedName;
    private String maskedStudentId;
    private String maskedEmail;
    private String maskedPhone;
}
