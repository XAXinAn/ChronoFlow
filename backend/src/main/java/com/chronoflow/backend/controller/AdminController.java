package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.dto.FeedbackResponse;
import com.chronoflow.backend.dto.PageResult;
import com.chronoflow.backend.entity.AdminUser;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.mapper.AdminUserMapper;
import com.chronoflow.backend.security.JwtTokenProvider;
import com.chronoflow.backend.service.AdminService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;
    private final AdminUserMapper adminUserMapper;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    // ==================== 登录（无需认证） ====================

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<Map<String, Object>>> login(@RequestBody Map<String, String> body) {
        String username = body.get("username");
        String password = body.get("password");
        if (username == null || password == null) {
            throw new BusinessException("用户名和密码不能为空");
        }

        AdminUser admin = adminUserMapper.selectOne(
                new LambdaQueryWrapper<AdminUser>().eq(AdminUser::getUsername, username));
        if (admin == null || !passwordEncoder.matches(password, admin.getPassword())) {
            throw new BusinessException("用户名或密码错误");
        }

        // 生成 JWT（带 admin 标记，过滤器跳过 users 表查询）
        String accessToken = jwtTokenProvider.generateAccessToken(
                Map.of("admin", true), admin.getId(),
                org.springframework.security.core.userdetails.User.builder()
                        .username(username).password("").authorities("ROLE_USER").build());
        String refreshToken = jwtTokenProvider.generateRefreshToken(
                Map.of("admin", true), admin.getId(),
                org.springframework.security.core.userdetails.User.builder()
                        .username(username).password("").authorities("ROLE_USER").build());

        Map<String, Object> result = Map.of(
                "accessToken", accessToken,
                "refreshToken", refreshToken,
                "tokenType", "Bearer",
                "userId", admin.getId(),
                "username", username,
                "nickname", username
        );
        log.info("Admin login: username={}", username);
        return ResponseEntity.ok(ApiResponse.success("登录成功", result));
    }

    // ==================== 反馈管理 ====================

    @GetMapping("/feedbacks")
    public ResponseEntity<ApiResponse<PageResult<FeedbackResponse>>> listFeedbacks(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String keyword) {
        log.info("Admin list feedbacks: page={}, size={}, status={}, type={}, keyword={}", page, size, status, type, keyword);
        return ResponseEntity.ok(ApiResponse.success("获取成功",
                adminService.listFeedbacks(page, size, status, type, keyword)));
    }

    @GetMapping("/feedbacks/{id}")
    public ResponseEntity<ApiResponse<FeedbackResponse>> getFeedbackDetail(@PathVariable Long id) {
        log.info("Admin get feedback detail: id={}", id);
        return ResponseEntity.ok(ApiResponse.success("获取成功", adminService.getFeedbackDetail(id)));
    }

    @PostMapping("/feedbacks/{id}/reply")
    public ResponseEntity<ApiResponse<FeedbackResponse>> replyFeedback(
            @PathVariable Long id, @RequestBody Map<String, String> body) {
        String reply = body.get("reply");
        log.info("Admin reply feedback: id={}", id);
        return ResponseEntity.ok(ApiResponse.success("回复成功", adminService.replyFeedback(id, reply)));
    }

    @PostMapping("/feedbacks/{id}/status")
    public ResponseEntity<ApiResponse<FeedbackResponse>> updateStatus(
            @PathVariable Long id, @RequestBody Map<String, String> body) {
        String status = body.get("status");
        log.info("Admin update feedback status: id={}, status={}", id, status);
        return ResponseEntity.ok(ApiResponse.success("更新成功", adminService.updateFeedbackStatus(id, status)));
    }

    @GetMapping("/users")
    public ResponseEntity<ApiResponse<PageResult<Map<String, Object>>>> listUsers(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String keyword) {
        log.info("Admin list users: page={}, size={}, keyword={}", page, size, keyword);
        return ResponseEntity.ok(ApiResponse.success("获取成功", adminService.listUsers(page, size, keyword)));
    }

    @GetMapping("/groups")
    public ResponseEntity<ApiResponse<PageResult<Map<String, Object>>>> listGroups(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String keyword) {
        log.info("Admin list groups: page={}, size={}, keyword={}", page, size, keyword);
        return ResponseEntity.ok(ApiResponse.success("获取成功", adminService.listGroups(page, size, keyword)));
    }

    @GetMapping("/schedules")
    public ResponseEntity<ApiResponse<PageResult<Map<String, Object>>>> listSchedules(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String keyword) {
        log.info("Admin list schedules: page={}, size={}, keyword={}", page, size, keyword);
        return ResponseEntity.ok(ApiResponse.success("获取成功", adminService.listSchedules(page, size, keyword)));
    }

    @DeleteMapping("/groups/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteGroup(@PathVariable String id) {
        log.info("Admin delete group: id={}", id);
        adminService.deleteGroup(id);
        return ResponseEntity.ok(ApiResponse.success("删除成功", null));
    }

    @PutMapping("/groups/{id}")
    public ResponseEntity<ApiResponse<Void>> updateGroup(@PathVariable String id, @RequestBody Map<String, String> body) {
        log.info("Admin update group: id={}, name={}", id, body.get("name"));
        adminService.updateGroup(id, body.get("name"));
        return ResponseEntity.ok(ApiResponse.success("更新成功", null));
    }

    @PostMapping("/schedules")
    public ResponseEntity<ApiResponse<Void>> createSchedule(@RequestBody Map<String, String> body) {
        log.info("Admin create schedule: userId={}, title={}", body.get("userId"), body.get("title"));
        adminService.createSchedule(body);
        return ResponseEntity.ok(ApiResponse.success("创建成功", null));
    }

    @PutMapping("/schedules/{id}")
    public ResponseEntity<ApiResponse<Void>> updateSchedule(@PathVariable Long id, @RequestBody Map<String, String> body) {
        log.info("Admin update schedule: id={}", id);
        adminService.updateSchedule(id, body);
        return ResponseEntity.ok(ApiResponse.success("更新成功", null));
    }

    @DeleteMapping("/schedules/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteSchedule(@PathVariable Long id) {
        log.info("Admin delete schedule: id={}", id);
        adminService.deleteSchedule(id);
        return ResponseEntity.ok(ApiResponse.success("删除成功", null));
    }
}
