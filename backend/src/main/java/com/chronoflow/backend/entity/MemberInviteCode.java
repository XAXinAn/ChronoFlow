package com.chronoflow.backend.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("member_invite_codes")
public class MemberInviteCode {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("code")
    private String code;

    @TableField("group_id")
    private String groupId;

    @TableField("creator_id")
    private Long creatorId;

    @TableField("masked_name")
    private String maskedName;

    @TableField("masked_student_id")
    private String maskedStudentId;

    @TableField("masked_email")
    private String maskedEmail;

    @TableField("masked_phone")
    private String maskedPhone;

    @TableField("status")
    private String status;

    @TableField("expires_at")
    private LocalDateTime expiresAt;

    @TableField("created_at")
    private LocalDateTime createdAt;

    @TableField("consumed_at")
    private LocalDateTime consumedAt;
}
