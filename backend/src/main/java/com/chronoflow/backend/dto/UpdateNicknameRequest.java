package com.chronoflow.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdateNicknameRequest {

    @NotBlank(message = "昵称不能为空")
    private String nickname;
}
