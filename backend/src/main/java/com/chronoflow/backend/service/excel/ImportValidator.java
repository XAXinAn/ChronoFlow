package com.chronoflow.backend.service.excel;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chronoflow.backend.dto.*;
import com.chronoflow.backend.entity.Group;
import com.chronoflow.backend.mapper.GroupMapper;
import com.chronoflow.backend.mapper.UserMapper;
import com.chronoflow.backend.service.ContentModerationService;
import com.chronoflow.backend.util.MaskingUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.*;

@Slf4j
@Service
public class ImportValidator {

    private final GroupMapper groupMapper;
    private final UserMapper userMapper;
    private final ContentModerationService contentModerationService;
    private final MemberIdentityMatcher memberIdentityMatcher;

    @Value("${excel.max-groups:100}")
    private int maxGroups;

    @Value("${group.max-depth:50}")
    private int maxDepth;

    public ImportValidator(GroupMapper groupMapper, UserMapper userMapper,
                           ContentModerationService contentModerationService,
                           MemberIdentityMatcher memberIdentityMatcher) {
        this.groupMapper = groupMapper;
        this.userMapper = userMapper;
        this.contentModerationService = contentModerationService;
        this.memberIdentityMatcher = memberIdentityMatcher;
    }

    public List<GroupImportError> validate(List<GroupImportItem> items, Long userId) {
        List<GroupImportError> errors = new ArrayList<>();

        if (items.size() > maxGroups) {
            errors.add(GroupImportError.builder()
                    .rowNumber(0).field("全局").reason("单次最多导入 " + maxGroups + " 个群组").build());
            return errors;
        }

        Set<String> importNames = new HashSet<>();
        for (GroupImportItem item : items) {
            importNames.add(item.getName());
        }

        Map<String, Integer> depthMap = new HashMap<>();
        for (GroupImportItem item : items) {
            validateItem(item, errors, importNames, depthMap);
        }

        if (!errors.isEmpty()) return errors;

        List<MemberInfo> allMembers = new ArrayList<>();
        for (GroupImportItem item : items) {
            if (item.getRawMembers() != null) {
                allMembers.addAll(item.getRawMembers());
            }
        }

        Map<MemberInfo, MemberIdentityMatcher.MatchResult> matchResults = memberIdentityMatcher.match(allMembers);

        for (GroupImportItem item : items) {
            List<MemberPreviewEntry> previewEntries = new ArrayList<>();
            if (item.getRawMembers() != null) {
                int rowIdx = 0;
                for (MemberInfo m : item.getRawMembers()) {
                    rowIdx++;
                    MemberIdentityMatcher.MatchResult mr = matchResults.get(m);
                    previewEntries.add(MemberPreviewEntry.builder()
                            .rowNumber(item.getRowNumber() + rowIdx)
                            .name(m.getName())
                            .studentId(MaskingUtil.maskStudentId(m.getStudentId()))
                            .email(MaskingUtil.maskEmail(m.getEmail()))
                            .phone(MaskingUtil.maskPhone(m.getPhone()))
                            .registrationStatus(mr != null ? mr.getStatus().name() : MemberRegistrationStatus.UNREGISTERED.name())
                            .matchedNickname(mr != null ? mr.getMatchedNickname() : null)
                            .matchedUserId(mr != null ? mr.getMatchedUserId() : null)
                            .build());
                }
            }
            item.setMembers(previewEntries);
        }

        return errors;
    }

    private void validateItem(GroupImportItem item, List<GroupImportError> errors,
                              Set<String> importNames, Map<String, Integer> depthMap) {
        int row = item.getRowNumber();

        if (item.getName() == null || item.getName().isBlank()) {
            errors.add(GroupImportError.builder().rowNumber(row).field("群组名称").reason("群组名称不能为空").build());
        } else if (item.getName().length() > 100) {
            errors.add(GroupImportError.builder().rowNumber(row).field("群组名称").reason("群组名称不能超过100字符").build());
        }

        if (item.getDescription() != null && item.getDescription().length() > 500) {
            errors.add(GroupImportError.builder().rowNumber(row).field("群组描述").reason("群组描述过长").build());
        }

        if (item.getParentName() != null && !item.getParentName().isBlank()) {
            if (!importNames.contains(item.getParentName())) {
                Group parent = groupMapper.selectOne(new QueryWrapper<Group>().eq("name", item.getParentName()));
                if (parent == null) {
                    errors.add(GroupImportError.builder().rowNumber(row).field("父群组名称").reason("父群组不存在").build());
                }
            }
        }

        if (item.getRawMembers() != null) {
            for (MemberInfo m : item.getRawMembers()) {
                String phone = m.getPhone();
                if (phone == null || phone.isBlank()) {
                    errors.add(GroupImportError.builder()
                            .rowNumber(row).field("成员手机号").reason("成员手机号不能为空").build());
                } else if (!phone.matches("^1\\d{10}$")) {
                    errors.add(GroupImportError.builder()
                            .rowNumber(row).field("成员手机号").reason("手机号格式错误")
                            .maskedPhone(MaskingUtil.maskPhone(phone)).build());
                }

                if (m.getEmail() != null && !m.getEmail().isBlank() && !m.getEmail().matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")) {
                    errors.add(GroupImportError.builder()
                            .rowNumber(row).field("成员邮箱").reason("邮箱格式错误")
                            .maskedPhone(MaskingUtil.maskEmail(m.getEmail())).build());
                }
                if (m.getStudentId() != null && m.getStudentId().length() > 32) {
                    errors.add(GroupImportError.builder()
                            .rowNumber(row).field("成员学号").reason("学号长度不能超过32字符").build());
                }
                if (m.getName() != null && m.getName().length() > 50) {
                    errors.add(GroupImportError.builder()
                            .rowNumber(row).field("成员姓名").reason("姓名长度不能超过50字符").build());
                }

                try {
                    if (m.getName() != null && !m.getName().isBlank()) {
                        String rejectReason = contentModerationService.moderate(m.getName());
                        if (rejectReason != null) {
                            errors.add(GroupImportError.builder().rowNumber(row).field("成员姓名").reason(rejectReason).build());
                        }
                    }
                    if (m.getStudentId() != null && !m.getStudentId().isBlank()) {
                        String rejectReason = contentModerationService.moderate(m.getStudentId());
                        if (rejectReason != null) {
                            errors.add(GroupImportError.builder().rowNumber(row).field("成员学号").reason(rejectReason).build());
                        }
                    }
                    if (m.getEmail() != null && !m.getEmail().isBlank()) {
                        String rejectReason = contentModerationService.moderate(m.getEmail());
                        if (rejectReason != null) {
                            errors.add(GroupImportError.builder().rowNumber(row).field("成员邮箱").reason(rejectReason).build());
                        }
                    }
                } catch (Exception e) {
                    log.warn("成员字段内容审核异常: {}", e.getMessage());
                }
            }
        }

        int depth = calculateDepth(item, importNames, depthMap);
        depthMap.put(item.getName(), depth);
        if (depth > maxDepth) {
            errors.add(GroupImportError.builder().rowNumber(row).field("层级深度").reason("层级深度超过" + maxDepth + "层").build());
        }

        try {
            String rejectReason = contentModerationService.moderate(item.getName());
            if (rejectReason != null) {
                errors.add(GroupImportError.builder().rowNumber(row).field("群组名称").reason(rejectReason).build());
            }
            if (item.getDescription() != null && !item.getDescription().isBlank()) {
                rejectReason = contentModerationService.moderate(item.getDescription());
                if (rejectReason != null) {
                    errors.add(GroupImportError.builder().rowNumber(row).field("群组描述").reason(rejectReason).build());
                }
            }
        } catch (Exception e) {
            log.warn("内容审核异常: {}", e.getMessage());
        }
    }

    private int calculateDepth(GroupImportItem item, Set<String> importNames, Map<String, Integer> depthMap) {
        if (item.getParentName() == null || item.getParentName().isBlank()) return 0;
        if (depthMap.containsKey(item.getParentName())) return depthMap.get(item.getParentName()) + 1;
        Group parent = groupMapper.selectOne(new QueryWrapper<Group>().eq("name", item.getParentName()));
        if (parent != null) return parent.getDepth() + 1;
        return 1;
    }

    public static String maskPhone(String phone) {
        return MaskingUtil.maskPhone(phone);
    }
}
