package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.dto.BindEmailRequest;
import com.chronoflow.backend.dto.BindPhoneRequest;
import com.chronoflow.backend.dto.ChangePasswordRequest;
import com.chronoflow.backend.dto.RealPersonVerifyInitRequest;
import com.chronoflow.backend.dto.RealPersonVerifyResultResponse;
import com.chronoflow.backend.dto.UpdateNicknameRequest;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.service.EmailService;
import com.chronoflow.backend.service.RealPersonVerificationService;
import com.chronoflow.backend.service.SmsService;
import com.chronoflow.backend.service.UserService;
import com.chronoflow.backend.util.CryptoUtil;
import org.springframework.beans.factory.annotation.Value;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;
    private final EmailService emailService;
    private final SmsService smsService;
    private final RealPersonVerificationService realPersonVerificationService;

    @Value("${crypto.secret:${jwt.secret:default-crypto-key-32chars}}")
    private String cryptoSecret;

    @PostMapping("/bind-email")
    public ResponseEntity<Map<String, Object>> bindEmail(
            HttpServletRequest httpRequest,
            @Valid @RequestBody BindEmailRequest request) {

        Long userId = getUserIdFromRequest(httpRequest);
        User user = userService.findById(userId);

        // Check if email is already bound to another user
        try {
            User existingUser = userService.findByEmail(request.getEmail());
            if (!existingUser.getId().equals(userId)) {
                Map<String, Object> error = new HashMap<>();
                error.put("message", "该邮箱已被绑定");
                return ResponseEntity.badRequest().body(error);
            }
        } catch (UsernameNotFoundException ignored) {
            // Email not found in system - this is expected, proceed with binding
        }

        // Verify verification code
        if (!emailService.verifyCode(request.getEmail(), request.getCode())) {
            Map<String, Object> error = new HashMap<>();
            error.put("message", "验证码错误或已过期");
            return ResponseEntity.badRequest().body(error);
        }

        userService.bindEmail(userId, request.getEmail());

        user = userService.findById(userId);
        Map<String, Object> result = new HashMap<>();
        result.put("message", "邮箱绑定成功");
        result.put("id", user.getId());
        result.put("username", user.getUsername());
        result.put("nickname", user.getNickname());
        result.put("email", user.getEmail());
        result.put("phone", user.getPhone());
        return ResponseEntity.ok(result);
    }

    @PostMapping("/update-nickname")
    public ResponseEntity<Map<String, Object>> updateNickname(
            HttpServletRequest httpRequest,
            @Valid @RequestBody UpdateNicknameRequest request) {

        Long userId = getUserIdFromRequest(httpRequest);

        try {
            userService.updateNickname(userId, request.getNickname());
        } catch (RuntimeException e) {
            Map<String, Object> error = new HashMap<>();
            error.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(error);
        }

        User user = userService.findById(userId);
        Map<String, Object> result = new HashMap<>();
        result.put("message", "昵称修改成功");
        result.put("id", user.getId());
        result.put("username", user.getUsername());
        result.put("nickname", user.getNickname());
        result.put("email", user.getEmail());
        result.put("phone", user.getPhone());
        return ResponseEntity.ok(result);
    }

    @PostMapping("/bind-phone")
    public ResponseEntity<Map<String, Object>> bindPhone(
            HttpServletRequest httpRequest,
            @Valid @RequestBody BindPhoneRequest request) {

        Long userId = getUserIdFromRequest(httpRequest);

        // Check if phone is already bound to another user
        try {
            User existingUser = userService.findByPhone(request.getPhone());
            if (!existingUser.getId().equals(userId)) {
                Map<String, Object> error = new HashMap<>();
                error.put("message", "该手机号已被绑定");
                return ResponseEntity.badRequest().body(error);
            }
        } catch (UsernameNotFoundException ignored) {
            // Phone not found in system - this is expected, proceed with binding
        }

        // Verify verification code
        if (!smsService.verifyCode(request.getPhone(), request.getCode())) {
            Map<String, Object> error = new HashMap<>();
            error.put("message", "验证码错误或已过期");
            return ResponseEntity.badRequest().body(error);
        }

        userService.bindPhone(userId, request.getPhone());

        User user = userService.findById(userId);
        Map<String, Object> result = new HashMap<>();
        result.put("message", "手机号绑定成功");
        result.put("id", user.getId());
        result.put("username", user.getUsername());
        result.put("nickname", user.getNickname());
        result.put("email", user.getEmail());
        result.put("phone", user.getPhone());
        return ResponseEntity.ok(result);
    }

    @PostMapping("/change-password")
    public ResponseEntity<Map<String, Object>> changePassword(
            HttpServletRequest httpRequest,
            @Valid @RequestBody ChangePasswordRequest request) {

        Long userId = getUserIdFromRequest(httpRequest);

        try {
            userService.changePassword(userId, request.getOldPassword(), request.getNewPassword());
        } catch (RuntimeException e) {
            Map<String, Object> error = new HashMap<>();
            error.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(error);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("message", "密码修改成功");
        return ResponseEntity.ok(result);
    }

    @PostMapping("/real-person-verify")
    public ResponseEntity<Map<String, Object>> initRealPersonVerify(
            HttpServletRequest httpRequest,
            @Valid @RequestBody RealPersonVerifyInitRequest request) {
        Long userId = getUserIdFromRequest(httpRequest);
        User user = userService.findById(userId);
        if (Boolean.TRUE.equals(user.getRealNameVerified())) {
            return ResponseEntity.ok(Map.of("alreadyVerified", true, "message", "您已完成实人认证"));
        }
        try {
            String certifyId = realPersonVerificationService.initFaceVerify(
                    request.getMetaInfo(), request.getRealName(), request.getIdCardNumber(), userId);
            return ResponseEntity.ok(Map.of("certifyId", certifyId, "alreadyVerified", false));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/real-person-verify/result")
    public ResponseEntity<Map<String, Object>> getRealPersonVerifyResult(
            HttpServletRequest httpRequest, @RequestParam String certifyId) {
        Long userId = getUserIdFromRequest(httpRequest);
        try {
            RealPersonVerifyResultResponse response = realPersonVerificationService.describeFaceVerify(certifyId, userId);
            if (response.isVerified()) {
                User user = userService.findById(userId);
                userService.saveRealPersonVerification(userId, user.getRealName() != null ? user.getRealName() : "",
                        user.getIdCardNumber() != null ? user.getIdCardNumber() : "");
                user = userService.findById(userId);
                return ResponseEntity.ok(Map.of("verified", true, "message", "认证通过",
                        "realNameVerified", user.getRealNameVerified()));
            }
            return ResponseEntity.ok(Map.of("verified", false, "message", response.getMessage()));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> getUserInfo(HttpServletRequest httpRequest) {

        Long userId = getUserIdFromRequest(httpRequest);
        User user = userService.findById(userId);

        Map<String, Object> result = new HashMap<>();
        result.put("id", user.getId());
        result.put("username", user.getUsername());
        result.put("nickname", user.getNickname());
        result.put("email", user.getEmail());
        result.put("phone", user.getPhone());
        result.put("realNameVerified", user.getRealNameVerified() != null && user.getRealNameVerified());
        return ResponseEntity.ok(result);
    }

    private Long getUserIdFromRequest(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            throw new RuntimeException("用户未认证");
        }
        return userId;
    }
}
