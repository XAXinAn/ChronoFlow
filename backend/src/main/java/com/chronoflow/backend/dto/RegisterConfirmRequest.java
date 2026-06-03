package com.chronoflow.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request to confirm registration after face verification SDK completes.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RegisterConfirmRequest {

    @NotBlank(message = "CertifyId不能为空")
    private String certifyId;
}
