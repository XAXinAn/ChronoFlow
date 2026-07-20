package com.chronoflow.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class RealPersonVerifyInitRequest {

    @NotBlank(message = "MetaInfo不能为空")
    private String metaInfo;

    @NotBlank(message = "姓名不能为空")
    @Size(min = 2, max = 50, message = "姓名长度应在2-50个字符之间")
    private String realName;

    @NotBlank(message = "身份证号不能为空")
    @Pattern(regexp = "^\\d{17}[\\dXx]$", message = "请输入正确的18位身份证号")
    private String idCardNumber;
}
