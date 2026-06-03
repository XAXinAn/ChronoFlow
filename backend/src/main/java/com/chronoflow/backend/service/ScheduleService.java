package com.chronoflow.backend.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.dto.ScheduleRequest;
import com.chronoflow.backend.dto.ScheduleResponse;
import com.chronoflow.backend.entity.Group;
import com.chronoflow.backend.entity.GroupMember;
import com.chronoflow.backend.entity.Schedule;
import com.chronoflow.backend.entity.SchedulePublishTarget;
import com.chronoflow.backend.mapper.GroupMapper;
import com.chronoflow.backend.mapper.GroupMemberMapper;
import com.chronoflow.backend.mapper.ScheduleMapper;
import com.chronoflow.backend.mapper.SchedulePublishTargetMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ScheduleService {

    private final ScheduleMapper scheduleMapper;
    private final GroupMapper groupMapper;
    private final GroupMemberMapper groupMemberMapper;
    private final GroupService groupService;
    private final ContentModerationService contentModerationService;
    private final SchedulePublishTargetMapper publishTargetMapper;

    public ScheduleResponse createSchedule(Long userId, ScheduleRequest request) {
        moderateScheduleContent(request);

        if (request.getGroupId() != null) {
            throw new BusinessException("请使用群组日程接口创建群组日程");
        }

        Schedule schedule = Schedule.builder()
                .userId(userId)
                .groupId(null)
                .title(request.getTitle())
                .description(request.getDescription())
                .location(request.getLocation())
                .time(request.getTime())
                .build();

        scheduleMapper.insert(schedule);
        return toResponse(schedule, null);
    }

    public ScheduleResponse createGroupSchedule(Long userId, String groupId, ScheduleRequest request) {
        moderateScheduleContent(request);

        Group group = groupMapper.selectById(groupId);
        if (group == null) {
            throw new BusinessException("群组不存在");
        }

        if (!isCreatorOrAdmin(userId, group)) {
            throw new BusinessException("只有群主/管理员可以创建群组日程");
        }

        Schedule schedule = Schedule.builder()
                .userId(userId)
                .groupId(groupId)
                .title(request.getTitle())
                .description(request.getDescription())
                .location(request.getLocation())
                .time(request.getTime())
                .build();

        scheduleMapper.insert(schedule);

        // Save publish targets
        if (request.getPublishTargetGroupIds() != null && !request.getPublishTargetGroupIds().isEmpty()) {
            for (String targetGroupId : request.getPublishTargetGroupIds()) {
                // Verify target is a descendant of this group
                if (!groupId.equals(targetGroupId)) {
                    List<String> descendantIds = groupService.getDescendantGroupIds(groupId);
                    if (!descendantIds.contains(targetGroupId)) {
                        throw new BusinessException("下发目标群组必须是当前群组的子孙群组");
                    }
                }
                SchedulePublishTarget target = new SchedulePublishTarget();
                target.setScheduleId(schedule.getId());
                target.setTargetGroupId(targetGroupId);
                publishTargetMapper.insert(target);
            }
        }

        return toResponse(schedule, group.getName());
    }

    public ScheduleResponse updateSchedule(Long userId, Long scheduleId, ScheduleRequest request) {
        moderateScheduleContent(request);

        Schedule schedule = scheduleMapper.selectById(scheduleId);
        if (schedule == null) {
            throw new BusinessException("日程不存在");
        }

        // 群组日程权限检查
        if (schedule.getGroupId() != null) {
            Group group = groupMapper.selectById(schedule.getGroupId());
            if (!isCreatorOrAdmin(userId, group)) {
                throw new BusinessException("无权修改此群组日程");
            }
        } else {
            // 个人日程只有创建者能修改
            if (!schedule.getUserId().equals(userId)) {
                throw new BusinessException("无权修改此日程");
            }
        }

        // 如果要更改群组归属，验证目标群组的权限
        if (request.getGroupId() != null && !request.getGroupId().equals(schedule.getGroupId())) {
            Group targetGroup = groupMapper.selectById(request.getGroupId());
            if (targetGroup == null) {
                throw new BusinessException("目标群组不存在");
            }
            if (!isCreatorOrAdmin(userId, targetGroup)) {
                throw new BusinessException("无权将日程移至该群组");
            }
        }

        schedule.setTitle(request.getTitle());
        schedule.setDescription(request.getDescription());
        schedule.setLocation(request.getLocation());
        schedule.setTime(request.getTime());
        schedule.setGroupId(request.getGroupId());

        scheduleMapper.updateById(schedule);

        String groupName = null;
        if (schedule.getGroupId() != null) {
            Group group = groupMapper.selectById(schedule.getGroupId());
            if (group != null) {
                groupName = group.getName();
            }
        }
        return toResponse(schedule, groupName);
    }

    public void deleteSchedule(Long userId, Long scheduleId) {
        Schedule schedule = scheduleMapper.selectById(scheduleId);
        if (schedule == null) {
            throw new BusinessException("日程不存在");
        }

        // 群组日程权限检查
        if (schedule.getGroupId() != null) {
            Group group = groupMapper.selectById(schedule.getGroupId());
            if (!isCreatorOrAdmin(userId, group)) {
                throw new BusinessException("无权删除此群组日程");
            }
        } else {
            // 个人日程只有创建者能删除
            if (!schedule.getUserId().equals(userId)) {
                throw new BusinessException("无权删除此日程");
            }
        }

        scheduleMapper.deleteById(scheduleId);
    }

    public ScheduleResponse getSchedule(Long userId, Long scheduleId) {
        Schedule schedule = scheduleMapper.selectById(scheduleId);
        if (schedule == null) {
            throw new BusinessException("日程不存在");
        }

        // 群组日程：检查是否是群成员
        if (schedule.getGroupId() != null) {
            if (!isGroupMember(userId, schedule.getGroupId())) {
                throw new BusinessException("无权查看此日程");
            }
            Group group = groupMapper.selectById(schedule.getGroupId());
            boolean canEditOrDelete = group != null && isCreatorOrAdmin(userId, group);
            return toResponse(schedule, group != null ? group.getName() : null, canEditOrDelete);
        }

        // 个人日程只有创建者能查看
        if (!schedule.getUserId().equals(userId)) {
            throw new BusinessException("无权查看此日程");
        }
        return toResponse(schedule, null, true);
    }

    public List<ScheduleResponse> getSchedulesByDate(Long userId, LocalDate date) {
        List<ScheduleResponse> schedules = new ArrayList<>();

        // 个人日程
        LocalDateTime startOfDay = date.atStartOfDay();
        LocalDateTime endOfDay = date.plusDays(1).atStartOfDay();

        List<Schedule> personalSchedules = scheduleMapper.selectList(
                new QueryWrapper<Schedule>()
                        .eq("user_id", userId)
                        .isNull("group_id")
                        .ge("schedule_time", startOfDay)
                        .lt("schedule_time", endOfDay)
                        .orderByDesc("schedule_time")
        );

        for (Schedule s : personalSchedules) {
            schedules.add(toResponse(s, null));
        }

        // 群组日程（用户所在群组的日程）
        schedules.addAll(getGroupSchedulesByDate(userId, date));

        return schedules;
    }

    public List<ScheduleResponse> getAllSchedules(Long userId) {
        List<ScheduleResponse> schedules = new ArrayList<>();

        // 个人日程
        List<Schedule> personalSchedules = scheduleMapper.selectList(
                new QueryWrapper<Schedule>()
                        .eq("user_id", userId)
                        .isNull("group_id")
                        .orderByDesc("schedule_time")
        );

        for (Schedule s : personalSchedules) {
            schedules.add(toResponse(s, null));
        }

        // 群组日程
        schedules.addAll(getAllGroupSchedules(userId));

        return schedules;
    }

    public List<ScheduleResponse> searchSchedules(Long userId, String keyword) {
        List<ScheduleResponse> schedules = new ArrayList<>();

        // 搜索个人日程
        List<Schedule> personalSchedules = scheduleMapper.selectList(
                new QueryWrapper<Schedule>()
                        .eq("user_id", userId)
                        .isNull("group_id")
                        .and(wrapper -> wrapper
                                .like("title", keyword)
                                .or()
                                .like("description", keyword)
                                .or()
                                .like("location", keyword))
                        .orderByDesc("schedule_time")
        );

        for (Schedule s : personalSchedules) {
            schedules.add(toResponse(s, null));
        }

        // 搜索群组日程
        schedules.addAll(searchGroupSchedules(userId, keyword));

        return schedules;
    }

    public List<ScheduleResponse> getAllGroupSchedules(Long userId) {
        List<String> groupIds = getUserGroupIds(userId);
        if (groupIds.isEmpty()) {
            return new ArrayList<>();
        }

        // Schedules created in user's groups
        List<Schedule> groupSchedules = scheduleMapper.selectList(
                new QueryWrapper<Schedule>()
                        .in("group_id", groupIds)
                        .orderByDesc("schedule_time")
        );

        // Also include schedules published to user's groups from ancestor groups
        List<Schedule> publishedSchedules = getPublishedSchedules(groupIds);
        // Merge and deduplicate
        java.util.Set<Long> seenIds = new java.util.HashSet<>();
        List<Schedule> allSchedules = new ArrayList<>();
        for (Schedule s : groupSchedules) {
            if (seenIds.add(s.getId())) allSchedules.add(s);
        }
        for (Schedule s : publishedSchedules) {
            if (seenIds.add(s.getId())) allSchedules.add(s);
        }
        // Re-sort
        allSchedules.sort((a, b) -> b.getTime().compareTo(a.getTime()));

        allSchedules.sort((a, b) -> b.getTime().compareTo(a.getTime()));

        // Batch load all referenced groups in one query to avoid N+1
        List<String> distinctGroupIds = allSchedules.stream()
                .map(Schedule::getGroupId)
                .distinct()
                .collect(Collectors.toList());

        java.util.Map<String, Group> groupMap = new java.util.HashMap<>();
        Set<String> adminGroupIds = new HashSet<>();

        if (!distinctGroupIds.isEmpty()) {
            List<Group> groups = groupMapper.selectList(
                    new QueryWrapper<Group>()
                            .in("id", distinctGroupIds)
            );
            for (Group g : groups) {
                groupMap.put(g.getId(), g);
            }

            // Batch check admin status for all groups at once
            List<GroupMember> memberships = groupMemberMapper.selectList(
                    new QueryWrapper<GroupMember>()
                            .in("group_id", distinctGroupIds)
                            .eq("user_id", userId)
            );
            for (GroupMember m : memberships) {
                if (Boolean.TRUE.equals(m.getIsAdmin())) {
                    adminGroupIds.add(m.getGroupId());
                }
            }
        }

        return groupSchedules.stream().map(schedule -> {
            Group group = groupMap.get(schedule.getGroupId());
            String groupName = group != null ? group.getName() : null;
            boolean isCreator = group != null && group.getCreatorId().equals(userId);
            boolean canEditOrDelete = isCreator || adminGroupIds.contains(schedule.getGroupId());
            return toResponse(schedule, groupName, canEditOrDelete);
        }).collect(Collectors.toList());
    }

    private List<ScheduleResponse> getGroupSchedulesByDate(Long userId, LocalDate date) {
        List<String> groupIds = getUserGroupIds(userId);
        if (groupIds.isEmpty()) {
            return new ArrayList<>();
        }

        LocalDateTime startOfDay = date.atStartOfDay();
        LocalDateTime endOfDay = date.plusDays(1).atStartOfDay();

        List<Schedule> groupSchedules = scheduleMapper.selectList(
                new QueryWrapper<Schedule>()
                        .in("group_id", groupIds)
                        .ge("schedule_time", startOfDay)
                        .lt("schedule_time", endOfDay)
                        .orderByDesc("schedule_time")
        );

        // Batch load groups
        java.util.Map<String, Group> groupMap = batchLoadGroups(groupSchedules);

        return groupSchedules.stream().map(schedule -> {
            Group group = groupMap.get(schedule.getGroupId());
            String groupName = group != null ? group.getName() : null;
            boolean canEditOrDelete = group != null && isCreatorOrAdmin(userId, group);
            return toResponse(schedule, groupName, canEditOrDelete);
        }).collect(Collectors.toList());
    }

    private List<ScheduleResponse> searchGroupSchedules(Long userId, String keyword) {
        List<String> groupIds = getUserGroupIds(userId);
        if (groupIds.isEmpty()) {
            return new ArrayList<>();
        }

        List<Schedule> groupSchedules = scheduleMapper.selectList(
                new QueryWrapper<Schedule>()
                        .in("group_id", groupIds)
                        .and(wrapper -> wrapper
                                .like("title", keyword)
                                .or()
                                .like("description", keyword)
                                .or()
                                .like("location", keyword))
                        .orderByDesc("schedule_time")
        );

        java.util.Map<String, Group> groupMap = batchLoadGroups(groupSchedules);

        return groupSchedules.stream().map(schedule -> {
            Group group = groupMap.get(schedule.getGroupId());
            String groupName = group != null ? group.getName() : null;
            boolean canEditOrDelete = group != null && isCreatorOrAdmin(userId, group);
            return toResponse(schedule, groupName, canEditOrDelete);
        }).collect(Collectors.toList());
    }

    private java.util.Map<String, Group> batchLoadGroups(List<Schedule> schedules) {
        List<String> distinctGroupIds = schedules.stream()
                .map(Schedule::getGroupId)
                .filter(id -> id != null)
                .distinct()
                .collect(Collectors.toList());
        java.util.Map<String, Group> groupMap = new java.util.HashMap<>();
        if (!distinctGroupIds.isEmpty()) {
            List<Group> groups = groupMapper.selectList(
                    new QueryWrapper<Group>()
                            .in("id", distinctGroupIds)
            );
            for (Group g : groups) {
                groupMap.put(g.getId(), g);
            }
        }
        return groupMap;
    }

    private List<String> getUserGroupIds(Long userId) {
        List<GroupMember> memberships = groupMemberMapper.selectList(
                new QueryWrapper<GroupMember>()
                        .eq("user_id", userId)
        );

        return memberships.stream()
                .map(GroupMember::getGroupId)
                .collect(Collectors.toList());
    }

    private boolean isGroupMember(Long userId, String groupId) {
        GroupMember member = groupMemberMapper.selectOne(
                new QueryWrapper<GroupMember>()
                        .eq("group_id", groupId)
                        .eq("user_id", userId)
        );
        return member != null;
    }

    private void moderateScheduleContent(ScheduleRequest request) {
        for (String field : new String[]{request.getTitle(), request.getDescription(), request.getLocation()}) {
            String reason = contentModerationService.moderate(field);
            if (reason != null) {
                throw new ContentModerationException(reason);
            }
        }
    }

    private boolean isCreatorOrAdmin(Long userId, Group group) {
        if (group.getCreatorId().equals(userId)) {
            return true;
        }
        return groupService.isAdmin(group.getId(), userId);
    }

    private ScheduleResponse toResponse(Schedule schedule, String groupName) {
        // 群组日程由调用方设置 canEditOrDelete，个人日程默认 true
        boolean isPersonal = schedule.getGroupId() == null;
        return toResponse(schedule, groupName, isPersonal);
    }

    private ScheduleResponse toResponse(Schedule schedule, String groupName, boolean canEditOrDelete) {
        return ScheduleResponse.builder()
                .id(schedule.getId())
                .userId(schedule.getUserId())
                .groupId(schedule.getGroupId())
                .groupName(groupName)
                .title(schedule.getTitle())
                .description(schedule.getDescription())
                .location(schedule.getLocation())
                .time(schedule.getTime())
                .canEditOrDelete(canEditOrDelete)
                .build();
    }

    /**
     * Find schedules published to any of the given groupIds from ancestor groups.
     */
    private List<Schedule> getPublishedSchedules(List<String> groupIds) {
        List<SchedulePublishTarget> targets = publishTargetMapper.selectList(
                new QueryWrapper<SchedulePublishTarget>()
                        .in("target_group_id", groupIds));
        if (targets.isEmpty()) return new ArrayList<>();

        List<Long> scheduleIds = targets.stream()
                .map(SchedulePublishTarget::getScheduleId)
                .distinct()
                .collect(Collectors.toList());
        if (scheduleIds.isEmpty()) return new ArrayList<>();

        return scheduleMapper.selectList(
                new QueryWrapper<Schedule>()
                        .in("id", scheduleIds)
                        .orderByDesc("schedule_time"));
    }
}