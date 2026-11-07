package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GroupImportError {
    private int rowNumber;
    private String field;
    private String reason;
    private String maskedPhone;
}