package com.chronoflow.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Registration request with real-person verification fields.
 * Combines SMS verification, account creation, and identity verification data.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RegisterVerifyRequest {

    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String phone;

    @NotBlank(message = "验证码不能为空")
    private String code;

    @NotBlank(message = "用户名不能为空")
    @Size(min = 3, max = 50, message = "用户名长度应在3-50个字符之间")
    private String username;

    @NotBlank(message = "密码不能为空")
    @Size(min = 6, max = 100, message = "密码长度应在6-100个字符之间")
    private String password;

    @NotBlank(message = "设备信息不能为空")
    private String metaInfo;

    @NotBlank(message = "姓名不能为空")
    @Size(min = 2, max = 50, message = "姓名长度应在2-50个字符之间")
    private String realName;

    @NotBlank(message = "身份证号不能为空")
    @Pattern(regexp = "^\\d{17}[\\dXx]$", message = "请输入正确的18位身份证号")
    private String idCardNumber;
}
