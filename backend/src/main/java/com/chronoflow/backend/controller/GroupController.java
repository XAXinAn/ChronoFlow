package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.dto.GroupRequest;
import com.chronoflow.backend.dto.GroupResponse;
import com.chronoflow.backend.entity.Group;
import com.chronoflow.backend.entity.GroupMember;
import com.chronoflow.backend.entity.JoinRequest;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.UserMapper;
import com.chronoflow.backend.service.GroupService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/groups")
@RequiredArgsConstructor
public class GroupController {

    private final GroupService groupService;
    private final UserMapper userMapper;

    @GetMapping("/my")
    public ResponseEntity<ApiResponse<List<GroupResponse>>> getMyGroups(HttpServletRequest request) {
        Long userId = getUserIdFromRequest(request);
        List<GroupResponse> groups = groupService.getMyGroups(userId);
        return ResponseEntity.ok(ApiResponse.success("获取成功", groups));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<GroupResponse>> createGroup(
            HttpServletRequest request,
            @Valid @RequestBody GroupRequest groupRequest) {
        Long userId = getUserIdFromRequest(request);
        GroupResponse group = groupService.createGroup(userId, groupRequest);
        return ResponseEntity.ok(ApiResponse.success("创建成功", group));
    }

    @PostMapping("/join")
    public ResponseEntity<ApiResponse<GroupResponse>> joinGroup(
            HttpServletRequest request,
            @RequestBody JoinGroupRequest joinRequest) {
        Long userId = getUserIdFromRequest(request);
        GroupResponse group = groupService.joinGroup(userId, joinRequest.getInviteCode());
        return ResponseEntity.ok(ApiResponse.success("加入成功", group));
    }

    @GetMapping("/info")
    public ResponseEntity<ApiResponse<GroupResponse>> getGroupInfoByInviteCode(
            HttpServletRequest request,
            @RequestParam @NotBlank String inviteCode) {
        GroupResponse group = groupService.getGroupInfoByInviteCode(inviteCode);
        return ResponseEntity.ok(ApiResponse.success("获取成功", group));
    }

    @GetMapping("/{groupId}/members")
    public ResponseEntity<ApiResponse<GroupMembersResponse>> getGroupMembers(
            HttpServletRequest request,
            @PathVariable String groupId) {
        Long userId = getUserIdFromRequest(request);
        Group group = groupService.getGroupById(groupId);
        // Verify the requesting user is a member of this group
        if (!groupService.isGroupMember(userId, groupId)) {
            return ResponseEntity.status(403)
                    .body(ApiResponse.error("无权查看该群组的成员"));
        }
        List<GroupMember> members = groupService.getGroupMembers(groupId);
        List<GroupMemberResponse> memberList = members.stream()
                .map(m -> {
                    User user = userMapper.selectById(m.getUserId());
                    return GroupMemberResponse.builder()
                            .userId(m.getUserId())
                            .username(user != null ? user.getUsername() : "")
                            .nickname(m.getNickname() != null ? m.getNickname() : (user != null ? user.getUsername() : ""))
                            .email(user != null ? user.getEmail() : "")
                            .isCreator(group.getCreatorId().equals(m.getUserId()))
                            .isAdmin(m.getIsAdmin())
                            .build();
                })
                .toList();
        return ResponseEntity.ok(ApiResponse.success("获取成功",
                new GroupMembersResponse(group.getCreatorId(), memberList)));
    }

    @PutMapping("/{groupId}/members/{targetUserId}/nickname")
    public ResponseEntity<ApiResponse<Void>> updateMemberNickname(
            HttpServletRequest request,
            @PathVariable String groupId,
            @PathVariable Long targetUserId,
            @RequestBody Map<String, String> body) {
        Long userId = getUserIdFromRequest(request);
        if (!userId.equals(targetUserId)) {
            return ResponseEntity.badRequest().body(ApiResponse.error("只能修改自己的昵称"));
        }
        String nickname = body.get("nickname");
        if (nickname == null || nickname.isBlank()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("昵称不能为空"));
        }
        if (nickname.length() > 20) {
            return ResponseEntity.badRequest().body(ApiResponse.error("昵称不能超过20个字符"));
        }
        groupService.updateMemberNickname(groupId, targetUserId, nickname);
        return ResponseEntity.ok(ApiResponse.success("修改成功", null));
    }

    @PutMapping("/{groupId}/admins/{targetUserId}")
    public ResponseEntity<ApiResponse<Void>> setGroupAdmin(
            HttpServletRequest request,
            @PathVariable String groupId,
            @PathVariable Long targetUserId,
            @RequestBody Map<String, Boolean> body) {
        Long userId = getUserIdFromRequest(request);
        Boolean isAdmin = body.get("isAdmin");
        if (isAdmin == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("缺少isAdmin参数"));
        }
        groupService.setGroupAdmin(groupId, userId, targetUserId, isAdmin);
        return ResponseEntity.ok(ApiResponse.success("设置成功", null));
    }

    @PutMapping("/{groupId}/settings")
    public ResponseEntity<ApiResponse<Void>> updateGroupSettings(
            HttpServletRequest request,
            @PathVariable String groupId,
            @RequestBody Map<String, Boolean> body) {
        Long userId = getUserIdFromRequest(request);
        Boolean requireApproval = body.get("requireApproval");
        if (requireApproval == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("缺少requireApproval参数"));
        }
        groupService.updateGroupSettings(userId, groupId, requireApproval);
        return ResponseEntity.ok(ApiResponse.success("设置成功", null));
    }

    @GetMapping("/{groupId}/join-requests")
    public ResponseEntity<ApiResponse<List<JoinRequestResponse>>> getJoinRequests(
            HttpServletRequest request,
            @PathVariable String groupId) {
        Long userId = getUserIdFromRequest(request);
        // Authorization: verify the requesting user is an admin or creator of this group
        if (!groupService.isCreatorOrAdmin(userId, groupId)) {
            return ResponseEntity.status(403)
                    .body(ApiResponse.error("无权查看加群申请"));
        }
        List<JoinRequest> requests = groupService.getJoinRequests(groupId);
        List<JoinRequestResponse> responseList = requests.stream()
                .map(r -> {
                    User user = userMapper.selectById(r.getUserId());
                    return JoinRequestResponse.builder()
                            .userId(r.getUserId())
                            .username(user != null ? user.getUsername() : "未知用户")
                            .email(user != null ? user.getEmail() : "")
                            .createdAt(r.getCreatedAt())
                            .build();
                })
                .toList();
        return ResponseEntity.ok(ApiResponse.success("获取成功", responseList));
    }

    @GetMapping("/my-join-requests")
    public ResponseEntity<ApiResponse<List<JoinRequestResponse>>> getMyJoinRequests(
            HttpServletRequest request) {
        Long userId = getUserIdFromRequest(request);
        List<JoinRequest> requests = groupService.getMyJoinRequests(userId);
        List<JoinRequestResponse> responseList = requests.stream()
                .map(r -> {
                    Group group = groupService.getGroupById(r.getGroupId());
                    String groupName = group != null ? group.getName() : "已删除的群组";
                    User user = userMapper.selectById(r.getUserId());
                    return JoinRequestResponse.builder()
                            .userId(r.getUserId())
                            .username(user != null ? user.getUsername() : "未知用户")
                            .email(user != null ? user.getEmail() : "")
                            .groupId(r.getGroupId())
                            .groupName(groupName)
                            .status(r.getStatus())
                            .createdAt(r.getCreatedAt())
                            .build();
                })
                .toList();
        return ResponseEntity.ok(ApiResponse.success("获取成功", responseList));
    }

    @PutMapping("/{groupId}/join-requests/{targetUserId}")
    public ResponseEntity<ApiResponse<Void>> approveJoinRequest(
            HttpServletRequest request,
            @PathVariable String groupId,
            @PathVariable Long targetUserId,
            @RequestBody Map<String, Boolean> body) {
        Long userId = getUserIdFromRequest(request);
        Boolean approve = body.get("approve");
        if (approve == null) {
            return ResponseEntity.badRequest().body(ApiResponse.error("缺少approve参数"));
        }
        groupService.approveJoinRequest(userId, groupId, targetUserId, approve);
        return ResponseEntity.ok(ApiResponse.success("处理成功", null));
    }

    @DeleteMapping("/{groupId}/members/{targetUserId}")
    public ResponseEntity<ApiResponse<Void>> removeMember(
            HttpServletRequest request,
            @PathVariable String groupId,
            @PathVariable Long targetUserId) {
        Long userId = getUserIdFromRequest(request);
        groupService.removeMember(userId, groupId, targetUserId);
        return ResponseEntity.ok(ApiResponse.success("移出成功", null));
    }

    @DeleteMapping("/{groupId}/leave")
    public ResponseEntity<ApiResponse<Void>> leaveGroup(
            HttpServletRequest request,
            @PathVariable String groupId) {
        Long userId = getUserIdFromRequest(request);
        groupService.leaveGroup(userId, groupId);
        return ResponseEntity.ok(ApiResponse.success("退出成功", null));
    }

    @DeleteMapping("/{groupId}")
    public ResponseEntity<ApiResponse<Void>> deleteGroup(
            HttpServletRequest request,
            @PathVariable String groupId) {
        Long userId = getUserIdFromRequest(request);
        groupService.deleteGroup(userId, groupId);
        return ResponseEntity.ok(ApiResponse.success("删除成功", null));
    }

    private Long getUserIdFromRequest(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            throw new RuntimeException("用户未认证");
        }
        return userId;
    }

    @lombok.Data
    public static class JoinGroupRequest {
        @NotBlank(message = "邀请码不能为空")
        private String inviteCode;
    }

    @lombok.Data
    @lombok.Builder
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class GroupMemberResponse {
        private Long userId;
        private String username;
        private String nickname;
        private String email;
        private Boolean isCreator;
        private Boolean isAdmin;
    }

    @lombok.Data
    @lombok.Builder
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class GroupMembersResponse {
        private Long creatorId;
        private List<GroupMemberResponse> members;
    }

    @lombok.Data
    @lombok.Builder
    @lombok.NoArgsConstructor
    @lombok.AllArgsConstructor
    public static class JoinRequestResponse {
        private Long userId;
        private String username;
        private String email;
        private java.time.LocalDateTime createdAt;
        private String groupId;
        private String groupName;
        private String status;
    }
}
