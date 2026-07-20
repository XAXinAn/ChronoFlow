package com.chronoflow.backend.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chronoflow.backend.entity.Message;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.mapper.MessageMapper;
import com.chronoflow.backend.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class MessageService {

    private final MessageMapper messageMapper;
    private final UserMapper userMapper;

    // ==================== 管理员发送消息 ====================

    /**
     * Admin sends a message to a specific user. Communication is always admin-initiated.
     */
    @Transactional
    public Message sendFromAdmin(Long adminId, Long receiverId, String title, String content) {
        User receiver = userMapper.selectById(receiverId);
        if (receiver == null) throw new BusinessException("用户不存在");

        Message msg = Message.builder()
                .senderId(adminId)
                .receiverId(receiverId)
                .title(title)
                .content(content)
                .type("admin_message")
                .isRead(false)
                .build();
        messageMapper.insert(msg);
        log.info("Admin {} sent message to user {}: {}", adminId, receiverId, title);
        return msg;
    }

    /**
     * Admin sends a message to all users.
     */
    @Transactional
    public int sendToAllUsers(Long adminId, String title, String content) {
        List<User> allUsers = userMapper.selectList(new QueryWrapper<>());
        if (allUsers.isEmpty()) throw new BusinessException("暂无用户");

        int count = 0;
        for (User user : allUsers) {
            Message msg = Message.builder()
                    .senderId(adminId)
                    .receiverId(user.getId())
                    .title(title)
                    .content(content)
                    .type("admin_message")
                    .isRead(false)
                    .build();
            messageMapper.insert(msg);
            count++;
        }
        log.info("Admin {} sent message to all {} users: {}", adminId, count, title);
        return count;
    }

    // ==================== 用户查看消息 ====================

    /**
     * Get all messages for a user (both admin messages and feedback notifications).
     * Returns a flat list with the latest message per thread.
     */
    public List<Map<String, Object>> getUserMessages(Long userId) {
        // Get all top-level messages (parent_id is null) for this user
        List<Message> threads = messageMapper.selectList(
                new QueryWrapper<Message>()
                        .eq("receiver_id", userId)
                        .isNull("parent_id")
                        .orderByDesc("created_at"));

        List<Map<String, Object>> result = new ArrayList<>();
        for (Message thread : threads) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", thread.getId());
            m.put("title", thread.getTitle());
            m.put("content", thread.getContent().length() > 100
                    ? thread.getContent().substring(0, 100) + "..." : thread.getContent());
            m.put("type", thread.getType());
            m.put("isRead", thread.getIsRead());
            m.put("createdAt", thread.getCreatedAt() != null ? thread.getCreatedAt().toString() : null);

            // Count replies
            long replyCount = messageMapper.selectCount(
                    new QueryWrapper<Message>().eq("parent_id", thread.getId()));
            m.put("replyCount", replyCount);

            result.add(m);
        }
        return result;
    }

    /**
     * Get unread message count for badge display.
     */
    public int getUnreadCount(Long userId) {
        return messageMapper.selectCount(
                new QueryWrapper<Message>()
                        .eq("receiver_id", userId)
                        .eq("is_read", false)).intValue();
    }

    // ==================== 消息详情（含回复） ====================

    /**
     * Get a message thread with all replies.
     */
    public Map<String, Object> getMessageDetail(Long messageId, Long userId) {
        Message msg = messageMapper.selectById(messageId);
        if (msg == null) throw new BusinessException("消息不存在");
        if (!msg.getReceiverId().equals(userId) && !msg.getSenderId().equals(userId)) {
            throw new BusinessException("无权查看此消息");
        }

        // Mark as read
        if (msg.getReceiverId().equals(userId) && Boolean.FALSE.equals(msg.getIsRead())) {
            msg.setIsRead(true);
            messageMapper.updateById(msg);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", msg.getId());
        result.put("title", msg.getTitle());
        result.put("content", msg.getContent());
        result.put("type", msg.getType());
        result.put("isRead", msg.getIsRead());
        result.put("createdAt", msg.getCreatedAt() != null ? msg.getCreatedAt().toString() : null);

        // Load replies
        List<Message> replies = messageMapper.selectList(
                new QueryWrapper<Message>()
                        .eq("parent_id", messageId)
                        .orderByAsc("created_at"));
        List<Map<String, Object>> replyList = new ArrayList<>();
        for (Message r : replies) {
            Map<String, Object> rm = new LinkedHashMap<>();
            rm.put("id", r.getId());
            rm.put("content", r.getContent());
            rm.put("type", r.getType());
            rm.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
            // Determine if this reply is from the admin
            rm.put("isAdmin", "admin_message".equals(r.getType()) || "feedback_notify".equals(r.getType()));
            replyList.add(rm);
        }
        result.put("replies", replyList);
        result.put("canReply", "admin_message".equals(msg.getType()));

        return result;
    }

    // ==================== 用户回复 ====================

    /**
     * User replies to an admin-initiated message. Only allowed for admin_message type.
     */
    @Transactional
    public Message replyFromUser(Long userId, Long messageId, String content) {
        Message original = messageMapper.selectById(messageId);
        if (original == null) throw new BusinessException("消息不存在");
        if (!original.getReceiverId().equals(userId)) throw new BusinessException("无权回复此消息");
        if (!"admin_message".equals(original.getType())) throw new BusinessException("此消息不支持回复");

        Message reply = Message.builder()
                .senderId(userId)
                .receiverId(original.getSenderId()) // reply goes back to admin
                .title("Re: " + original.getTitle())
                .content(content)
                .parentId(messageId)
                .type("user_reply")
                .isRead(false)
                .build();
        messageMapper.insert(reply);
        log.info("User {} replied to message {}", userId, messageId);
        return reply;
    }

    // ==================== 管理员查看自己发出的消息 ====================

    public List<Map<String, Object>> getAdminMessages(Long adminId) {
        List<Message> messages = messageMapper.selectList(
                new QueryWrapper<Message>()
                        .eq("sender_id", adminId)
                        .isNull("parent_id")
                        .orderByDesc("created_at"));

        List<Map<String, Object>> result = new ArrayList<>();
        for (Message msg : messages) {
            User receiver = userMapper.selectById(msg.getReceiverId());
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", msg.getId());
            m.put("title", msg.getTitle());
            m.put("content", msg.getContent().length() > 80
                    ? msg.getContent().substring(0, 80) + "..." : msg.getContent());
            m.put("type", msg.getType());
            m.put("receiverId", msg.getReceiverId());
            m.put("receiverName", receiver != null ? receiver.getUsername() : "未知用户");
            m.put("isRead", msg.getIsRead());
            m.put("createdAt", msg.getCreatedAt() != null ? msg.getCreatedAt().toString() : null);

            long replyCount = messageMapper.selectCount(
                    new QueryWrapper<Message>().eq("parent_id", msg.getId()));
            m.put("replyCount", replyCount);
            result.add(m);
        }
        return result;
    }

    // ==================== 反馈回复自动通知 ====================

    /**
     * Auto-create a notification message when admin replies to a user's feedback.
     */
    @Transactional
    public void notifyFeedbackReply(Long userId, String feedbackContent, String adminReply) {
        String title = "管理员回复了你的反馈";
        String content = "你的反馈：「" + (feedbackContent.length() > 50
                ? feedbackContent.substring(0, 50) + "..." : feedbackContent)
                + "」\n\n管理员回复：" + adminReply;

        Message msg = Message.builder()
                .senderId(0L) // system / admin
                .receiverId(userId)
                .title(title)
                .content(content)
                .type("feedback_notify")
                .isRead(false)
                .build();
        messageMapper.insert(msg);
        log.info("Feedback reply notification sent to user {}", userId);
    }
}
