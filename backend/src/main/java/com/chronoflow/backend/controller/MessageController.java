package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.service.MessageService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/messages")
@RequiredArgsConstructor
public class MessageController {

    private final MessageService messageService;

    /** 获取用户的所有消息列表 */
    @GetMapping
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getMessages(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        return ResponseEntity.ok(ApiResponse.success("获取成功", messageService.getUserMessages(userId)));
    }

    /** 获取未读消息数（红点角标用） */
    @GetMapping("/unread-count")
    public ResponseEntity<ApiResponse<Integer>> getUnreadCount(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        return ResponseEntity.ok(ApiResponse.success("获取成功", messageService.getUnreadCount(userId)));
    }

    /** 获取消息详情（含回复列表） */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getMessageDetail(
            HttpServletRequest request, @PathVariable Long id) {
        Long userId = (Long) request.getAttribute("userId");
        return ResponseEntity.ok(ApiResponse.success("获取成功", messageService.getMessageDetail(id, userId)));
    }

    /** 用户回复消息 */
    @PostMapping("/{id}/reply")
    public ResponseEntity<ApiResponse<Void>> reply(
            HttpServletRequest request,
            @PathVariable Long id,
            @RequestBody Map<String, String> body) {
        Long userId = (Long) request.getAttribute("userId");
        String content = body.get("content");
        if (content == null || content.isBlank()) throw new BusinessException("回复内容不能为空");
        messageService.replyFromUser(userId, id, content);
        return ResponseEntity.ok(ApiResponse.success("回复成功", null));
    }
}
