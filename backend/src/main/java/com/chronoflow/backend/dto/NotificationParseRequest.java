package com.chronoflow.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class NotificationParseRequest {
    @NotBlank(message = "OCR文本不能为空")
    @Size(max = 50000, message = "OCR文本过长")
    private String ocrText;
}