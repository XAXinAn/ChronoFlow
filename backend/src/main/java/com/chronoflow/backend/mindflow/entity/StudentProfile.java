package com.chronoflow.backend.mindflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/*六维学习画像实体*/
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("student_profile")
public class StudentProfile {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    /** 知识基础 */
    @TableField("knowledge_base")
    private String knowledgeBase;

    /** 认知风格 */
    @TableField("cognitive_style")
    private String cognitiveStyle;

    /** 薄弱知识点*/
    @TableField("weak_points")
    private String weakPoints;

    /** 学习节奏偏好*/
    @TableField("pace_preference")
    private String pacePreference;

    /** 学习兴趣方向 */
    @TableField("interests")
    private String interests;

    /** 高效学习时段*/
    @TableField("peak_hours")
    private String peakHours;

    /** 易错类型 */
    @TableField("error_types")
    private String errorTypes;

    /** 画像版本号*/
    @TableField("profile_version")
    private Integer profileVersion;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}