package com.chronoflow.backend.service.excel;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chronoflow.backend.dto.*;
import com.chronoflow.backend.entity.Group;
import com.chronoflow.backend.entity.GroupMember;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.GroupMapper;
import com.chronoflow.backend.mapper.GroupMemberMapper;
import com.chronoflow.backend.mapper.UserMapper;
import com.chronoflow.backend.util.MaskingUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.*;

@Slf4j
@Service
public class BatchGroupCreator {

    private final GroupMapper groupMapper;
    private final GroupMemberMapper groupMemberMapper;
    private final UserMapper userMapper;
    private final MemberInviteCodeGenerator memberInviteCodeGenerator;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    public BatchGroupCreator(GroupMapper groupMapper, GroupMemberMapper groupMemberMapper,
                             UserMapper userMapper, MemberInviteCodeGenerator memberInviteCodeGenerator) {
        this.groupMapper = groupMapper;
        this.groupMemberMapper = groupMemberMapper;
        this.userMapper = userMapper;
        this.memberInviteCodeGenerator = memberInviteCodeGenerator;
    }

    @Transactional
    public ExcelImportResult create(List<GroupImportItem> items, Long userId) {
        List<GroupImportItem> sorted = topologicalSort(items);

        Map<String, String> nameToId = new HashMap<>();
        Map<String, Integer> nameToDepth = new HashMap<>();
        List<GroupInviteCodeEntry> inviteCodes = new ArrayList<>();
        List<MemberAssociationResult> memberResults = new ArrayList<>();

        User creator = userMapper.selectById(userId);
        String creatorNickname = creator != null ? creator.getUsername() : "未知用户";

        int totalRegistered = 0;
        int totalUnregistered = 0;

        for (GroupImportItem item : sorted) {
            String groupId = UUID.randomUUID().toString().replace("-", "");
            String inviteCode = generateUniqueInviteCode();

            int depth = 0;
            String parentId = null;
            if (item.getParentName() != null && !item.getParentName().isBlank()) {
                if (nameToId.containsKey(item.getParentName())) {
                    parentId = nameToId.get(item.getParentName());
                    depth = nameToDepth.get(item.getParentName()) + 1;
                } else {
                    Group parent = groupMapper.selectOne(new QueryWrapper<Group>().eq("name", item.getParentName()));
                    if (parent != null) {
                        parentId = parent.getId();
                        depth = parent.getDepth() + 1;
                    }
                }
            }

            Group group = Group.builder()
                    .id(groupId)
                    .name(item.getName())
                    .description(item.getDescription())
                    .inviteCode(inviteCode)
                    .creatorId(userId)
                    .requireApproval(item.isRequireApproval())
                    .parentId(parentId)
                    .depth(depth)
                    .createdAt(LocalDateTime.now())
                    .updatedAt(LocalDateTime.now())
                    .build();
            groupMapper.insert(group);
            nameToId.put(item.getName(), groupId);
            nameToDepth.put(item.getName(), depth);

            GroupMember ownerMember = GroupMember.builder()
                    .groupId(groupId)
                    .userId(userId)
                    .nickname(creatorNickname)
                    .isAdmin(true)
                    .joinedAt(LocalDateTime.now())
                    .build();
            groupMemberMapper.insert(ownerMember);

            int associatedCount = 0;
            List<MemberInviteCodeEntry> unregisteredInviteCodes = new ArrayList<>();
            List<String> unassociatedPhones = new ArrayList<>();

            List<MemberPreviewEntry> previewEntries = item.getMembers();
            List<MemberInfo> rawMembers = item.getRawMembers();
            if (previewEntries != null && rawMembers != null) {
                int size = Math.min(previewEntries.size(), rawMembers.size());
                for (int i = 0; i < size; i++) {
                    MemberPreviewEntry preview = previewEntries.get(i);
                    MemberInfo raw = rawMembers.get(i);

                    if (MemberRegistrationStatus.REGISTERED.name().equals(preview.getRegistrationStatus())) {
                        Long matchedUserId = preview.getMatchedUserId();
                        if (matchedUserId != null && !matchedUserId.equals(userId)) {
                            GroupMember gm = GroupMember.builder()
                                    .groupId(groupId)
                                    .userId(matchedUserId)
                                    .nickname(preview.getMatchedNickname() != null ? preview.getMatchedNickname() : "未知用户")
                                    .isAdmin(false)
                                    .joinedAt(LocalDateTime.now())
                                    .build();
                            groupMemberMapper.insert(gm);
                            associatedCount++;
                            totalRegistered++;
                        }
                    } else {
                        String code = memberInviteCodeGenerator.generate();
                        memberInviteCodeGenerator.persist(code, groupId, userId, raw);
                        unregisteredInviteCodes.add(MemberInviteCodeEntry.builder()
                                .inviteCode(code)
                                .maskedName(MaskingUtil.maskName(raw.getName()))
                                .maskedStudentId(MaskingUtil.maskStudentId(raw.getStudentId()))
                                .maskedEmail(MaskingUtil.maskEmail(raw.getEmail()))
                                .maskedPhone(MaskingUtil.maskPhone(raw.getPhone()))
                                .build());
                        unassociatedPhones.add(MaskingUtil.maskPhone(raw.getPhone()));
                        totalUnregistered++;
                    }
                }
            }

            inviteCodes.add(GroupInviteCodeEntry.builder()
                    .groupName(item.getName()).inviteCode(inviteCode).depth(depth).build());
            memberResults.add(MemberAssociationResult.builder()
                    .groupName(item.getName()).associatedCount(associatedCount + 1)
                    .unassociatedPhones(unassociatedPhones)
                    .unregisteredInviteCodes(unregisteredInviteCodes)
                    .build());
        }

        List<GroupTreeNode> hierarchyTree = buildHierarchyTree(items, nameToDepth);

        log.info("Excel建群完成: userId={}, 群组数={}, 已注册入群={}, 未注册邀请码={}",
                userId, items.size(), totalRegistered, totalUnregistered);

        return ExcelImportResult.builder()
                .successCount(items.size())
                .failCount(0)
                .failures(Collections.emptyList())
                .groupInviteCodes(inviteCodes)
                .hierarchyTree(hierarchyTree)
                .memberAssociationResults(memberResults)
                .build();
    }

    private List<GroupImportItem> topologicalSort(List<GroupImportItem> items) {
        Map<String, GroupImportItem> nameToItem = new HashMap<>();
        for (GroupImportItem item : items) nameToItem.put(item.getName(), item);

        List<GroupImportItem> sorted = new ArrayList<>();
        Set<String> visited = new HashSet<>();
        for (GroupImportItem item : items) {
            topoVisit(item, nameToItem, visited, sorted);
        }
        return sorted;
    }

    private void topoVisit(GroupImportItem item, Map<String, GroupImportItem> nameToItem,
                           Set<String> visited, List<GroupImportItem> sorted) {
        if (visited.contains(item.getName())) return;
        visited.add(item.getName());
        if (item.getParentName() != null && !item.getParentName().isBlank()) {
            GroupImportItem parent = nameToItem.get(item.getParentName());
            if (parent != null) topoVisit(parent, nameToItem, visited, sorted);
        }
        sorted.add(item);
    }

    private String generateUniqueInviteCode() {
        for (int i = 0; i < 10; i++) {
            int code = 100000 + SECURE_RANDOM.nextInt(900000);
            String candidate = String.valueOf(code);
            if (!groupMapper.exists(new QueryWrapper<Group>().eq("invite_code", candidate))) {
                return candidate;
            }
        }
        throw new com.chronoflow.backend.exception.BusinessException("生成邀请码失败，请重试");
    }

    private List<GroupTreeNode> buildHierarchyTree(List<GroupImportItem> items, Map<String, Integer> nameToDepth) {
        Map<String, List<GroupImportItem>> childrenMap = new HashMap<>();
        List<GroupImportItem> roots = new ArrayList<>();
        for (GroupImportItem item : items) {
            if (item.getParentName() == null || item.getParentName().isBlank()
                    || !nameToDepth.containsKey(item.getParentName()) && !items.stream().anyMatch(i -> i.getName().equals(item.getParentName()))) {
                roots.add(item);
            } else {
                childrenMap.computeIfAbsent(item.getParentName(), k -> new ArrayList<>()).add(item);
            }
        }
        List<GroupTreeNode> tree = new ArrayList<>();
        for (GroupImportItem root : roots) {
            tree.add(buildNode(root, childrenMap, nameToDepth));
        }
        return tree;
    }

    private GroupTreeNode buildNode(GroupImportItem item, Map<String, List<GroupImportItem>> childrenMap,
                                    Map<String, Integer> nameToDepth) {
        List<GroupTreeNode> children = new ArrayList<>();
        List<GroupImportItem> childItems = childrenMap.get(item.getName());
        if (childItems != null) {
            for (GroupImportItem child : childItems) {
                children.add(buildNode(child, childrenMap, nameToDepth));
            }
        }
        return GroupTreeNode.builder()
                .name(item.getName())
                .depth(nameToDepth.getOrDefault(item.getName(), 0))
                .children(children)
                .build();
    }
}
