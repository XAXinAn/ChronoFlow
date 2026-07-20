package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class NotificationParseResult {
    private String title;
    private String eventDate;
    private String eventTime;
    private String location;
    private String remark;
    private String category;
}