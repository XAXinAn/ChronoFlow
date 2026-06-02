package com.chronoflow.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ScheduleRequest {
    @NotBlank(message = "日程标题不能为空")
    @Size(max = 255, message = "日程标题不能超过255个字符")
    private String title;

    @Size(max = 1000, message = "日程描述不能超过1000个字符")
    private String description;

    @Size(max = 255, message = "地点不能超过255个字符")
    private String location;

    @NotNull(message = "日程时间不能为空")
    private LocalDateTime time;
    private String groupId;
}