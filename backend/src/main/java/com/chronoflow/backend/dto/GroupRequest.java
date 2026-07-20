package com.chronoflow.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GroupRequest {
    @NotBlank(message = "群组名称不能为空")
    @Size(max = 100, message = "群组名称不能超过100个字符")
    private String name;

    @Size(max = 500, message = "群组描述不能超过500个字符")
    private String description;
}
