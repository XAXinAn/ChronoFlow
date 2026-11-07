package com.chronoflow.backend.service.excel;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chronoflow.backend.dto.MemberInfo;
import com.chronoflow.backend.entity.Group;
import com.chronoflow.backend.entity.MemberInviteCode;
import com.chronoflow.backend.entity.MemberInviteCodeStatus;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.mapper.GroupMapper;
import com.chronoflow.backend.mapper.MemberInviteCodeMapper;
import com.chronoflow.backend.util.MaskingUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;

@Slf4j
@Service
public class MemberInviteCodeGenerator {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final String CHARSET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    private final MemberInviteCodeMapper memberInviteCodeMapper;
    private final GroupMapper groupMapper;

    @Value("${excel.member-invite-code.length:8}")
    private int codeLength;

    @Value("${excel.member-invite-code.max-retry:10}")
    private int maxRetry;

    public MemberInviteCodeGenerator(MemberInviteCodeMapper memberInviteCodeMapper, GroupMapper groupMapper) {
        this.memberInviteCodeMapper = memberInviteCodeMapper;
        this.groupMapper = groupMapper;
    }

    public String generate() {
        for (int i = 0; i < maxRetry; i++) {
            StringBuilder sb = new StringBuilder(codeLength);
            for (int j = 0; j < codeLength; j++) {
                sb.append(CHARSET.charAt(SECURE_RANDOM.nextInt(CHARSET.length())));
            }
            String candidate = sb.toString();
            if (!isCodeExists(candidate)) {
                return candidate;
            }
        }
        throw new BusinessException("生成邀请码失败，请重试");
    }

    private boolean isCodeExists(String code) {
        if (memberInviteCodeMapper.exists(new QueryWrapper<MemberInviteCode>().eq("code", code))) {
            return true;
        }
        return groupMapper.exists(new QueryWrapper<Group>().eq("invite_code", code));
    }

    public MemberInviteCode persist(String code, String groupId, Long creatorId, MemberInfo member) {
        MemberInviteCode entity = MemberInviteCode.builder()
                .code(code)
                .groupId(groupId)
                .creatorId(creatorId)
                .maskedName(MaskingUtil.maskName(member.getName()))
                .maskedStudentId(MaskingUtil.maskStudentId(member.getStudentId()))
                .maskedEmail(MaskingUtil.maskEmail(member.getEmail()))
                .maskedPhone(MaskingUtil.maskPhone(member.getPhone()))
                .status(MemberInviteCodeStatus.PENDING.name())
                .build();
        memberInviteCodeMapper.insert(entity);
        return entity;
    }
}
