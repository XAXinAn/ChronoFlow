package com.chronoflow.backend.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.dto.GroupRequest;
import com.chronoflow.backend.dto.GroupResponse;
import com.chronoflow.backend.entity.Group;
import com.chronoflow.backend.entity.GroupMember;
import com.chronoflow.backend.entity.JoinRequest;
import com.chronoflow.backend.entity.JoinRequestStatus;
import com.chronoflow.backend.entity.SubgroupCreationRequest;
import com.chronoflow.backend.entity.SubgroupCreationRequestStatus;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.GroupMapper;
import com.chronoflow.backend.mapper.GroupMemberMapper;
import com.chronoflow.backend.mapper.JoinRequestMapper;
import com.chronoflow.backend.mapper.SubgroupCreationRequestMapper;
import com.chronoflow.backend.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class GroupService {

    private final GroupMapper groupMapper;
    private final GroupMemberMapper groupMemberMapper;
    private final JoinRequestMapper joinRequestMapper;
    private final SubgroupCreationRequestMapper subgroupCreationRequestMapper;
    private final UserMapper userMapper;
    private final ContentModerationService contentModerationService;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    @Transactional
    public GroupResponse createGroup(Long userId, GroupRequest request) {
        // 内容审核
        moderate(request.getName(), "群组名称");
        moderate(request.getDescription(), "群组描述");

        // 生成邀请码
        String inviteCode = generateUniqueInviteCode();

        // 创建群组
        Group group = new Group();
        group.setId(UUID.randomUUID().toString().replace("-", ""));
        group.setName(request.getName());
        group.setDescription(request.getDescription());
        group.setInviteCode(inviteCode);
        group.setCreatorId(userId);
        group.setRequireApproval(false);
        group.setCreatedAt(LocalDateTime.now());
        group.setUpdatedAt(LocalDateTime.now());
        groupMapper.insert(group);

        // 创建者自动加入群组（作为管理员）
        GroupMember member = new GroupMember();
        member.setGroupId(group.getId());
        member.setUserId(userId);
        member.setNickname(getUserNickname(userId));
        member.setIsAdmin(true);
        member.setJoinedAt(LocalDateTime.now());
        groupMemberMapper.insert(member);

        return toResponse(group, 1);
    }

    @Transactional
    public GroupResponse joinGroup(Long userId, String inviteCode) {
        Group group = groupMapper.selectOne(
                new QueryWrapper<Group>().eq("invite_code", inviteCode)
        );

        if (group == null) {
            throw new BusinessException("群组不存在");
        }

        // 检查是否已经加入
        GroupMember existing = groupMemberMapper.selectOne(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", group.getId())
                        .eq("user_id", userId)
        );

        if (existing != null) {
            throw new BusinessException("已经加入该群组");
        }

        // 检查群组是否需要验证
        if (Boolean.TRUE.equals(group.getRequireApproval())) {
            // 检查是否已有申请记录
            JoinRequest existingRequest = joinRequestMapper.selectOne(
                    new QueryWrapper<JoinRequest>()
                            .eq("group_id", group.getId())
                            .eq("user_id", userId)
            );

            if (existingRequest != null) {
                if (JoinRequestStatus.APPROVED.name().equalsIgnoreCase(existingRequest.getStatus())) {
                    throw new BusinessException("您已经加入该群组");
                }
                if (JoinRequestStatus.PENDING.name().equalsIgnoreCase(existingRequest.getStatus())) {
                    // 已有待处理申请，直接返回成功（不重复插入）
                    return toResponse(group, 0, true);
                }
                // 如果是被拒绝的，更新状态重新申请
                existingRequest.setStatus(JoinRequestStatus.PENDING.name().toLowerCase());
                existingRequest.setUpdatedAt(LocalDateTime.now());
                joinRequestMapper.updateById(existingRequest);
                return toResponse(group, 0, true);
            }

            // 创建加群申请
            JoinRequest request = new JoinRequest();
            request.setGroupId(group.getId());
            request.setUserId(userId);
            request.setStatus(JoinRequestStatus.PENDING.name().toLowerCase());
            request.setCreatedAt(LocalDateTime.now());
            request.setUpdatedAt(LocalDateTime.now());
            joinRequestMapper.insert(request);

            // 返回申请已提交的状态
            return toResponse(group, 0, true);
        }

        // 直接加入群组
        GroupMember member = new GroupMember();
        member.setGroupId(group.getId());
        member.setUserId(userId);
        member.setNickname(getUserNickname(userId));
        member.setIsAdmin(false);
        member.setJoinedAt(LocalDateTime.now());
        groupMemberMapper.insert(member);

        // 返回群组信息
        int memberCount = groupMemberMapper.selectCount(
                new QueryWrapper<GroupMember>().eq("group_id", group.getId())
        ).intValue();

        return toResponse(group, memberCount);
    }

    @Transactional
    public void leaveGroup(Long userId, String groupId) {
        Group group = groupMapper.selectById(groupId);
        if (group == null) {
            throw new BusinessException("群组不存在");
        }

        if (group.getCreatorId().equals(userId)) {
            throw new BusinessException("群主无法退出群组，请先解散群组");
        }

        groupMemberMapper.delete(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", groupId)
                        .eq("user_id", userId)
        );
    }

    @Transactional
    public void deleteGroup(Long userId, String groupId) {
        Group group = groupMapper.selectById(groupId);
        if (group == null) {
            throw new BusinessException("群组不存在");
        }

        if (!group.getCreatorId().equals(userId)) {
            throw new BusinessException("只有群主可以删除群组");
        }

        // 删除所有成员
        groupMemberMapper.delete(
                new QueryWrapper<GroupMember>().eq("group_id", groupId)
        );

        // 删除所有加群申请
        joinRequestMapper.delete(
                new QueryWrapper<JoinRequest>().eq("group_id", groupId)
        );

        // 删除群组
        groupMapper.deleteById(groupId);
    }

    public List<GroupResponse> getMyGroups(Long userId) {
        List<GroupMember> memberships = groupMemberMapper.selectList(
                new QueryWrapper<GroupMember>().eq("user_id", userId)
        );

        List<String> groupIds = memberships.stream()
                .map(GroupMember::getGroupId)
                .collect(Collectors.toList());

        if (groupIds.isEmpty()) {
            return List.of();
        }

        List<Group> groups = groupMapper.selectList(
                new QueryWrapper<Group>().in("id", groupIds)
        );

        // Batch load member counts and admin status in single queries
        java.util.Map<String, Integer> memberCountMap = new java.util.HashMap<>();
        java.util.Map<String, Boolean> adminMap = new java.util.HashMap<>();

        if (!groupIds.isEmpty()) {
            // Load all members for these groups in one query
            List<GroupMember> allMembers = groupMemberMapper.selectList(
                    new QueryWrapper<GroupMember>().in("group_id", groupIds)
            );
            for (GroupMember m : allMembers) {
                memberCountMap.merge(m.getGroupId(), 1, Integer::sum);
                if (m.getUserId().equals(userId) && Boolean.TRUE.equals(m.getIsAdmin())) {
                    adminMap.put(m.getGroupId(), true);
                }
            }
        }

        return groups.stream().map(group -> {
            int memberCount = memberCountMap.getOrDefault(group.getId(), 0);
            boolean isAdminOrCreator = (group.getCreatorId() != null
                    && group.getCreatorId().longValue() == userId.longValue())
                    || Boolean.TRUE.equals(adminMap.get(group.getId()));
            return toResponse(group, memberCount, null, isAdminOrCreator);
        }).collect(Collectors.toList());
    }

    public List<GroupMember> getGroupMembers(String groupId) {
        return groupMemberMapper.selectList(
                new QueryWrapper<GroupMember>().eq("group_id", groupId)
        );
    }

    public Group getGroupById(String groupId) {
        return groupMapper.selectById(groupId);
    }

    @Transactional
    public void setGroupAdmin(String groupId, Long userId, Long targetUserId, boolean isAdmin) {
        Group group = groupMapper.selectById(groupId);
        if (group == null) {
            throw new BusinessException("群组不存在");
        }

        // 只有群主可以设置管理员
        if (!group.getCreatorId().equals(userId)) {
            throw new BusinessException("只有群主可以设置管理员");
        }

        // 群主不能被设置为管理员
        if (group.getCreatorId().equals(targetUserId)) {
            throw new BusinessException("群主不能被设置为管理员");
        }

        // 检查目标用户是否是管理员
        GroupMember targetMember = groupMemberMapper.selectOne(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", groupId)
                        .eq("user_id", targetUserId)
        );

        if (targetMember == null) {
            throw new BusinessException("该用户不是群成员");
        }

        // 统计当前管理员数量（不包括群主）
        int adminCount = groupMemberMapper.selectCount(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", groupId)
                        .eq("is_admin", true)
                        .ne("user_id", group.getCreatorId())
        ).intValue();

        if (isAdmin && adminCount >= 3) {
            throw new BusinessException("管理员数量已达上限（最多3名）");
        }

        targetMember.setIsAdmin(isAdmin);
        groupMemberMapper.updateById(targetMember);
    }

    @Transactional
    public void updateGroupSettings(Long userId, String groupId, Boolean requireApproval) {
        Group group = groupMapper.selectById(groupId);
        if (group == null) {
            throw new BusinessException("群组不存在");
        }

        // 只有群主可以修改设置
        if (!group.getCreatorId().equals(userId)) {
            throw new BusinessException("只有群主可以修改群组设置");
        }

        if (requireApproval != null) {
            group.setRequireApproval(requireApproval);
            groupMapper.updateById(group);
        }
    }

    public List<JoinRequest> getJoinRequests(String groupId) {
        return joinRequestMapper.selectList(
                new QueryWrapper<JoinRequest>()
                        .eq("group_id", groupId)
                        .eq("status", JoinRequestStatus.PENDING.name().toLowerCase())
        );
    }

    // 获取用户的所有加群申请
    public List<JoinRequest> getMyJoinRequests(Long userId) {
        return joinRequestMapper.selectList(
                new QueryWrapper<JoinRequest>()
                        .eq("user_id", userId)
                        .orderByDesc("created_at")
        );
    }

    // 获取用户在某个群组的申请状态
    public JoinRequest getUserJoinRequestStatus(Long userId, String groupId) {
        return joinRequestMapper.selectOne(
                new QueryWrapper<JoinRequest>()
                        .eq("user_id", userId)
                        .eq("group_id", groupId)
                        .orderByDesc("created_at")
                        .last("LIMIT 1")
        );
    }

    @Transactional
    public void approveJoinRequest(Long userId, String groupId, Long targetUserId, boolean approve) {
        Group group = groupMapper.selectById(groupId);
        if (group == null) {
            throw new BusinessException("群组不存在");
        }

        // 检查权限：群主或管理员
        if (!isCreatorOrAdmin(userId, group)) {
            throw new BusinessException("只有群主/管理员可以审批加群申请");
        }

        JoinRequest request = joinRequestMapper.selectOne(
                new QueryWrapper<JoinRequest>()
                        .eq("group_id", groupId)
                        .eq("user_id", targetUserId)
                        .eq("status", JoinRequestStatus.PENDING.name().toLowerCase())
        );

        if (request == null) {
            throw new BusinessException("没有待处理的加群申请");
        }

        if (approve) {
            // 批准申请，加入群组
            GroupMember member = new GroupMember();
            member.setGroupId(groupId);
            member.setUserId(targetUserId);
            member.setNickname(getUserNickname(targetUserId));
            member.setIsAdmin(false);
            member.setJoinedAt(LocalDateTime.now());
            groupMemberMapper.insert(member);

            request.setStatus(JoinRequestStatus.APPROVED.name().toLowerCase());
        } else {
            request.setStatus(JoinRequestStatus.REJECTED.name().toLowerCase());
        }

        joinRequestMapper.updateById(request);
    }

    @Transactional
    public void removeMember(Long userId, String groupId, Long targetUserId) {
        Group group = groupMapper.selectById(groupId);
        if (group == null) {
            throw new BusinessException("群组不存在");
        }

        // 检查权限：群主或管理员
        if (!isCreatorOrAdmin(userId, group)) {
            throw new BusinessException("只有群主/管理员可以移出成员");
        }

        // 不能移出群主
        if (group.getCreatorId().equals(targetUserId)) {
            throw new BusinessException("不能移出群主");
        }

        groupMemberMapper.delete(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", groupId)
                        .eq("user_id", targetUserId)
        );
    }

    public boolean isCreatorOrAdmin(Long userId, Group group) {
        // Direct creator
        if (group.getCreatorId().equals(userId)) {
            return true;
        }
        // Direct admin
        GroupMember member = groupMemberMapper.selectOne(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", group.getId())
                        .eq("user_id", userId)
        );
        if (member != null && Boolean.TRUE.equals(member.getIsAdmin())) {
            return true;
        }
        // Check ancestor chain: if user created or is admin of any ancestor group
        return isAncestorCreatorOrAdmin(userId, group.getParentId());
    }

    /**
     * Walk up the parent chain to check if userId created or is admin of any ancestor group.
     */
    private boolean isAncestorCreatorOrAdmin(Long userId, String parentId) {
        String currentId = parentId;
        while (currentId != null) {
            Group current = groupMapper.selectById(currentId);
            if (current == null) break;
            if (current.getCreatorId().equals(userId)) return true;
            // Check if user is admin of this ancestor group
            GroupMember member = groupMemberMapper.selectOne(
                    new QueryWrapper<GroupMember>()
                            .eq("group_id", current.getId())
                            .eq("user_id", userId));
            if (member != null && Boolean.TRUE.equals(member.getIsAdmin())) return true;
            currentId = current.getParentId();
        }
        return false;
    }

    public boolean isCreatorOrAdmin(Long userId, String groupId) {
        Group group = groupMapper.selectById(groupId);
        if (group == null) {
            return false;
        }
        return isCreatorOrAdmin(userId, group);
    }

    public boolean isGroupMember(Long userId, String groupId) {
        GroupMember member = groupMemberMapper.selectOne(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", groupId)
                        .eq("user_id", userId)
        );
        return member != null;
    }

    public boolean isAdmin(String groupId, Long userId) {
        GroupMember member = groupMemberMapper.selectOne(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", groupId)
                        .eq("user_id", userId)
        );
        return member != null && Boolean.TRUE.equals(member.getIsAdmin());
    }

    private String generateUniqueInviteCode() {
        for (int i = 0; i < 10; i++) {
            int code = 100000 + SECURE_RANDOM.nextInt(900000);
            String candidate = String.valueOf(code);
            if (!groupMapper.exists(new QueryWrapper<Group>().eq("invite_code", candidate))) {
                return candidate;
            }
        }
        throw new BusinessException("生成邀请码失败，请重试");
    }

    private String getUserNickname(Long userId) {
        User user = userMapper.selectById(userId);
        return user != null ? user.getUsername() : "未知用户";
    }

    public GroupResponse getGroupInfoByInviteCode(String inviteCode) {
        Group group = groupMapper.selectOne(
                new QueryWrapper<Group>().eq("invite_code", inviteCode)
        );

        if (group == null) {
            throw new BusinessException("群组不存在");
        }

        int memberCount = groupMemberMapper.selectCount(
                new QueryWrapper<GroupMember>().eq("group_id", group.getId())
        ).intValue();

        return toResponse(group, memberCount);
    }

    private GroupResponse toResponse(Group group, int memberCount) {
        return toResponse(group, memberCount, null, null);
    }

    private GroupResponse toResponse(Group group, int memberCount, Boolean pendingApproval) {
        return toResponse(group, memberCount, pendingApproval, null);
    }

    private GroupResponse toResponse(Group group, int memberCount, Boolean pendingApproval, Boolean isAdminOrCreator) {
        return toResponse(group, memberCount, pendingApproval, isAdminOrCreator, null);
    }

    private GroupResponse toResponse(Group group, int memberCount, Boolean pendingApproval, Boolean isAdminOrCreator, Boolean hasChildren) {
        return GroupResponse.builder()
                .id(group.getId())
                .name(group.getName())
                .description(group.getDescription())
                .inviteCode(group.getInviteCode())
                .memberCount(memberCount)
                .creatorId(group.getCreatorId())
                .createdAt(group.getCreatedAt())
                .requireApproval(group.getRequireApproval())
                .pendingApproval(pendingApproval)
                .isAdminOrCreator(isAdminOrCreator)
                .parentId(group.getParentId())
                .depth(group.getDepth())
                .hasChildren(hasChildren)
                .build();
    }

    public void updateMemberNickname(String groupId, Long userId, String nickname) {
        moderate(nickname, "群昵称");

        GroupMember member = groupMemberMapper.selectOne(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", groupId)
                        .eq("user_id", userId)
        );
        if (member == null) {
            throw new BusinessException("你不是该群组成员");
        }
        member.setNickname(nickname);
        groupMemberMapper.updateById(member);
    }

    private void moderate(String text, String fieldName) {
        String reason = contentModerationService.moderate(text);
        if (reason != null) {
            throw new ContentModerationException(reason);
        }
    }

    // ==================== 层级群组相关 ====================

    /**
     * Submit a request to create a sub-group under the given parent group.
     */
    public void createSubgroupRequest(String parentGroupId, Long userId, String name, String description) {
        Group parent = groupMapper.selectById(parentGroupId);
        if (parent == null) {
            throw new BusinessException("父群组不存在");
        }
        if (!isGroupMember(userId, parentGroupId)) {
            throw new BusinessException("你不是该群组成员，无法申请创建子群组");
        }
        if (parent.getDepth() != null && parent.getDepth() >= 50) {
            throw new BusinessException("已达最大层级深度（50层）");
        }
        moderate(name, "子群组名称");
        moderate(description, "子群组描述");

        SubgroupCreationRequest request = new SubgroupCreationRequest();
        request.setParentGroupId(parentGroupId);
        request.setApplicantId(userId);
        request.setName(name);
        request.setDescription(description);
        request.setStatus(SubgroupCreationRequestStatus.PENDING.name().toLowerCase());
        request.setCreatedAt(LocalDateTime.now());
        request.setUpdatedAt(LocalDateTime.now());
        subgroupCreationRequestMapper.insert(request);
    }

    /**
     * Get pending sub-group creation requests for a parent group.
     */
    public List<SubgroupCreationRequest> getSubgroupCreationRequests(String parentGroupId) {
        return subgroupCreationRequestMapper.selectList(
                new QueryWrapper<SubgroupCreationRequest>()
                        .eq("parent_group_id", parentGroupId)
                        .eq("status", SubgroupCreationRequestStatus.PENDING.name().toLowerCase())
        );
    }

    /**
     * Approve or reject a sub-group creation request.
     * On approval: creates the sub-group with the applicant as its creator (group owner).
     */
    @Transactional
    public GroupResponse approveSubgroupRequest(Long reviewerId, String parentGroupId, Long targetUserId, boolean approve) {
        Group parent = groupMapper.selectById(parentGroupId);
        if (parent == null) {
            throw new BusinessException("父群组不存在");
        }
        if (!isCreatorOrAdmin(reviewerId, parent)) {
            throw new BusinessException("只有群主/管理员可以审核子群组创建申请");
        }

        SubgroupCreationRequest request = subgroupCreationRequestMapper.selectOne(
                new QueryWrapper<SubgroupCreationRequest>()
                        .eq("parent_group_id", parentGroupId)
                        .eq("applicant_id", targetUserId)
                        .eq("status", SubgroupCreationRequestStatus.PENDING.name().toLowerCase())
        );
        if (request == null) {
            throw new BusinessException("没有待审核的子群组创建申请");
        }

        if (!approve) {
            request.setStatus(SubgroupCreationRequestStatus.REJECTED.name().toLowerCase());
            subgroupCreationRequestMapper.updateById(request);
            return null;
        }

        // Create the sub-group
        int childDepth = (parent.getDepth() != null ? parent.getDepth() : 0) + 1;
        if (childDepth > 50) {
            throw new BusinessException("已达最大层级深度（50层）");
        }

        Group subGroup = new Group();
        subGroup.setId(UUID.randomUUID().toString().replace("-", ""));
        subGroup.setName(request.getName());
        subGroup.setDescription(request.getDescription());
        subGroup.setInviteCode(generateUniqueInviteCode());
        subGroup.setCreatorId(targetUserId);
        subGroup.setRequireApproval(false);
        subGroup.setParentId(parentGroupId);
        subGroup.setDepth(childDepth);
        subGroup.setCreatedAt(LocalDateTime.now());
        subGroup.setUpdatedAt(LocalDateTime.now());
        groupMapper.insert(subGroup);

        // Applicant becomes group owner (admin member)
        GroupMember member = new GroupMember();
        member.setGroupId(subGroup.getId());
        member.setUserId(targetUserId);
        member.setNickname(getUserNickname(targetUserId));
        member.setIsAdmin(true);
        member.setJoinedAt(LocalDateTime.now());
        groupMemberMapper.insert(member);

        // Mark request as approved
        request.setStatus(SubgroupCreationRequestStatus.APPROVED.name().toLowerCase());
        request.setUpdatedAt(LocalDateTime.now());
        subgroupCreationRequestMapper.updateById(request);

        return toResponse(subGroup, 1);
    }

    /**
     * Build tree of groups for a user: root groups + their descendants.
     */
    public List<GroupResponse> getMyGroupTree(Long userId) {
        List<GroupResponse> flatList = getMyGroups(userId);
        java.util.Set<String> existingIds = flatList.stream()
                .map(GroupResponse::getId).collect(Collectors.toSet());
        // Find groups where user is creator or admin, and include descendants
        java.util.Set<String> rootGroupIds = new java.util.HashSet<>();
        List<Group> createdGroups = groupMapper.selectList(
                new QueryWrapper<Group>().eq("creator_id", userId));
        for (Group g : createdGroups) rootGroupIds.add(g.getId());
        List<GroupMember> adminMemberships = groupMemberMapper.selectList(
                new QueryWrapper<GroupMember>()
                        .eq("user_id", userId).eq("is_admin", true));
        for (GroupMember m : adminMemberships) rootGroupIds.add(m.getGroupId());
        for (String rootId : rootGroupIds) {
            List<String> descendantIds = getDescendantGroupIds(rootId);
            for (String descId : descendantIds) {
                if (!existingIds.contains(descId)) {
                    Group desc = groupMapper.selectById(descId);
                    if (desc != null) {
                        int count = groupMemberMapper.selectCount(
                                new QueryWrapper<GroupMember>().eq("group_id", descId)).intValue();
                        flatList.add(toResponse(desc, count));
                    }
                }
            }
        }
        return buildTree(flatList, null);
    }

    private List<GroupResponse> buildTree(List<GroupResponse> all, String parentId) {
        List<GroupResponse> tree = new java.util.ArrayList<>();
        java.util.Set<String> parentIdsInList = all.stream()
                .map(GroupResponse::getId).collect(Collectors.toSet());
        for (GroupResponse g : all) {
            boolean match = (parentId == null && g.getParentId() == null)
                    || (parentId != null && parentId.equals(g.getParentId()));
            // Also treat as root if parent is not in the list (orphan group)
            if (parentId == null && !match && g.getParentId() != null
                    && !parentIdsInList.contains(g.getParentId())) {
                match = true;
            }
            if (match) {
                List<GroupResponse> children = buildTree(all, g.getId());
                g.setHasChildren(!children.isEmpty());
                g.setChildren(children.isEmpty() ? null : children);
                tree.add(g);
            }
        }
        return tree;
    }

    /**
     * Get all descendant group IDs (including self) for schedule publishing.
     */
    /**
     * Get direct children of a group.
     */
    public List<GroupResponse> getDirectChildren(String parentGroupId) {
        List<Group> children = groupMapper.selectList(
                new QueryWrapper<Group>().eq("parent_id", parentGroupId));
        return children.stream()
                .map(g -> {
                    int memberCount = groupMemberMapper.selectCount(
                            new QueryWrapper<GroupMember>().eq("group_id", g.getId())).intValue();
                    boolean hasChild = groupMapper.selectCount(
                            new QueryWrapper<Group>().eq("parent_id", g.getId())) > 0;
                    int descendantCount = 0;
                    if (hasChild) {
                        descendantCount = getDescendantGroupIds(g.getId()).size() - 1; // exclude self
                    }
                    GroupResponse resp = toResponse(g, memberCount, null, null, hasChild);
                    resp.setDescendantCount(descendantCount);
                    return resp;
                })
                .collect(Collectors.toList());
    }

    public List<String> getDescendantGroupIds(String groupId) {
        List<String> result = new java.util.ArrayList<>();
        result.add(groupId);
        collectDescendantIds(groupId, result);
        return result;
    }

    private void collectDescendantIds(String parentId, List<String> result) {
        List<Group> children = groupMapper.selectList(
                new QueryWrapper<Group>().eq("parent_id", parentId));
        for (Group child : children) {
            result.add(child.getId());
            collectDescendantIds(child.getId(), result);
        }
    }

    /**
     * Get ancestor group IDs up to root (for schedule visibility).
     */
    public List<String> getAncestorGroupIds(String groupId) {
        List<String> result = new java.util.ArrayList<>();
        Group current = groupMapper.selectById(groupId);
        while (current != null && current.getParentId() != null) {
            result.add(current.getParentId());
            current = groupMapper.selectById(current.getParentId());
        }
        return result;
    }
}