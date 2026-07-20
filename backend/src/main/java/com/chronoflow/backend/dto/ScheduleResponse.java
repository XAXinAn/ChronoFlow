package com.chronoflow.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ScheduleResponse {
    private Long id;
    private Long userId;
    private String title;
    private String description;
    private String location;
    private LocalDateTime time;
    private String groupId;
    private String groupName;
    private Boolean canEditOrDelete;
}