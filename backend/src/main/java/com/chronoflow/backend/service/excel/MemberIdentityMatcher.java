package com.chronoflow.backend.service.excel;

import com.chronoflow.backend.dto.MemberInfo;
import com.chronoflow.backend.dto.MemberRegistrationStatus;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.UserMapper;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;

@Slf4j
@Service
public class MemberIdentityMatcher {

    private final UserMapper userMapper;

    public MemberIdentityMatcher(UserMapper userMapper) {
        this.userMapper = userMapper;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MatchResult {
        private MemberRegistrationStatus status;
        private Long matchedUserId;
        private String matchedNickname;
    }

    public Map<MemberInfo, MatchResult> match(List<MemberInfo> members) {
        Map<MemberInfo, MatchResult> results = new LinkedHashMap<>();
        if (members == null || members.isEmpty()) {
            return results;
        }

        try {
            Set<String> phones = new HashSet<>();
            Set<String> emails = new HashSet<>();
            Set<String> studentIds = new HashSet<>();
            for (MemberInfo m : members) {
                if (m.getPhone() != null && !m.getPhone().isBlank()) phones.add(m.getPhone());
                if (m.getEmail() != null && !m.getEmail().isBlank()) emails.add(m.getEmail());
                if (m.getStudentId() != null && !m.getStudentId().isBlank()) studentIds.add(m.getStudentId());
            }

            Map<String, User> phoneToUser = new HashMap<>();
            Map<String, User> emailToUser = new HashMap<>();
            Map<String, User> studentIdToUser = new HashMap<>();

            if (!phones.isEmpty()) {
                for (User u : userMapper.selectListByPhones(new ArrayList<>(phones))) {
                    phoneToUser.put(u.getPhone(), u);
                }
            }
            if (!emails.isEmpty()) {
                for (User u : userMapper.selectListByEmails(new ArrayList<>(emails))) {
                    if (u.getEmail() != null) emailToUser.put(u.getEmail(), u);
                }
            }
            if (!studentIds.isEmpty()) {
                for (User u : userMapper.selectListByStudentIds(new ArrayList<>(studentIds))) {
                    if (u.getStudentId() != null) studentIdToUser.put(u.getStudentId(), u);
                }
            }

            for (MemberInfo m : members) {
                User matched = null;
                if (m.getPhone() != null && !m.getPhone().isBlank()) {
                    matched = phoneToUser.get(m.getPhone());
                }
                if (matched == null && m.getEmail() != null && !m.getEmail().isBlank()) {
                    matched = emailToUser.get(m.getEmail());
                }
                if (matched == null && m.getStudentId() != null && !m.getStudentId().isBlank()) {
                    matched = studentIdToUser.get(m.getStudentId());
                }

                if (matched != null) {
                    results.put(m, MatchResult.builder()
                            .status(MemberRegistrationStatus.REGISTERED)
                            .matchedUserId(matched.getId())
                            .matchedNickname(matched.getUsername())
                            .build());
                } else {
                    results.put(m, MatchResult.builder()
                            .status(MemberRegistrationStatus.UNREGISTERED)
                            .build());
                }
            }
        } catch (Exception e) {
            log.warn("成员身份匹配查询异常，降级为未注册: {}", e.getMessage());
            for (MemberInfo m : members) {
                results.put(m, MatchResult.builder()
                        .status(MemberRegistrationStatus.UNREGISTERED_DEGRADED)
                        .build());
            }
        }

        return results;
    }
}
