package com.chronoflow.backend.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("subgroup_creation_requests")
public class SubgroupCreationRequest {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("parent_group_id")
    private String parentGroupId;

    @TableField("applicant_id")
    private Long applicantId;

    private String name;

    private String description;

    private String status;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
