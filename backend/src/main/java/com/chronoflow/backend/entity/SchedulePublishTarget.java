package com.chronoflow.backend.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("schedule_publish_targets")
public class SchedulePublishTarget {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("schedule_id")
    private Long scheduleId;

    @TableField("target_group_id")
    private String targetGroupId;
}
