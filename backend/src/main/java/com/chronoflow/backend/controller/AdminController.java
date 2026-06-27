package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.dto.FeedbackResponse;
import com.chronoflow.backend.dto.PageResult;
import com.chronoflow.backend.service.AdminService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final AdminService adminService;

    @GetMapping("/feedbacks")
    public ResponseEntity<ApiResponse<PageResult<FeedbackResponse>>> listFeedbacks(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String type) {
        log.info("Admin list feedbacks: page={}, size={}, status={}, type={}", page, size, status, type);
        PageResult<FeedbackResponse> result = adminService.listFeedbacks(page, size, status, type);
        return ResponseEntity.ok(ApiResponse.success("获取成功", result));
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
            @RequestParam(defaultValue = "20") int size) {
        log.info("Admin list users: page={}, size={}", page, size);
        return ResponseEntity.ok(ApiResponse.success("获取成功", adminService.listUsers(page, size)));
    }

    @PostMapping("/users/{id}/role")
    public ResponseEntity<ApiResponse<Void>> updateUserRole(
            @PathVariable Long id, @RequestBody Map<String, String> body) {
        String role = body.get("role");
        log.info("Admin update user role: userId={}, role={}", id, role);
        adminService.updateUserRole(id, role);
        return ResponseEntity.ok(ApiResponse.success("更新成功", null));
    }
}
