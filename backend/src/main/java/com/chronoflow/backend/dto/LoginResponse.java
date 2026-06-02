package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoginResponse {
    private String accessToken;
    private String refreshToken;
    private String tokenType;
    private Long userId;
    private String username;
    private String nickname;
    private String email;
    private String phone;
    // 风控相关
    private boolean riskRequired;  // 是否需要风控验证
    private String riskType;      // 风控类型：sms/email
    private String riskToken;      // 风控验证token
}
