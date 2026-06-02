package com.chronoflow.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class RiskVerifyRequest {

    @NotBlank(message = "风控token不能为空")
    private String riskToken;

    @NotBlank(message = "验证码不能为空")
    private String code;
}
