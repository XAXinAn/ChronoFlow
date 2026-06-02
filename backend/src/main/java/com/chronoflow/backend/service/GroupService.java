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
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.GroupMapper;
import com.chronoflow.backend.mapper.GroupMemberMapper;
import com.chronoflow.backend.mapper.JoinRequestMapper;
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
        if (group.getCreatorId().equals(userId)) {
            return true;
        }

        GroupMember member = groupMemberMapper.selectOne(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", group.getId())
                        .eq("user_id", userId)
        );

        return member != null && Boolean.TRUE.equals(member.getIsAdmin());
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

    private GroupResponse toResponse(Group group, int memberCount, Boolean pendingApproval, Boolean isAdminOrCreator) {
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
                .build();
    }

    private GroupResponse toResponse(Group group, int memberCount) {
        return toResponse(group, memberCount, null, null);
    }

    private GroupResponse toResponse(Group group, int memberCount, Boolean pendingApproval) {
        return toResponse(group, memberCount, pendingApproval, null);
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
}