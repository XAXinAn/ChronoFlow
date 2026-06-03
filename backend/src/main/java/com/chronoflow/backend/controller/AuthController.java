package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.*;
import com.chronoflow.backend.security.JwtTokenProvider;
import com.chronoflow.backend.service.AuthService;
import com.chronoflow.backend.service.EmailService;
import com.chronoflow.backend.service.RegisterService;
import com.chronoflow.backend.service.RiskControlService;
import com.chronoflow.backend.service.SmsService;
import com.chronoflow.backend.service.TokenBlacklistService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final RegisterService registerService;
    private final SmsService smsService;
    private final EmailService emailService;
    private final RiskControlService riskControlService;
    private final JwtTokenProvider jwtTokenProvider;
    private final TokenBlacklistService tokenBlacklistService;

    @PostMapping("/register")
    public ResponseEntity<RegisterResponse> register(@Valid @RequestBody RegisterVerifyRequest request) {
        return ResponseEntity.ok(registerService.registerWithVerify(request));
    }

    // 发送短信验证码
    @PostMapping("/send-sms")
    public ResponseEntity<SmsSendResponse> sendSms(@Valid @RequestBody SendSmsRequest request) {
        String result = smsService.sendVerificationCode(request.getPhone());
        boolean success = result.contains("已发送");
        return ResponseEntity.ok(SmsSendResponse.builder()
                .success(success)
                .message(result)
                .build());
    }

    // 短信验证码登录
    @PostMapping("/sms-login")
    public ResponseEntity<LoginResponse> smsLogin(@Valid @RequestBody SmsLoginRequest request) {
        return ResponseEntity.ok(authService.smsLogin(request));
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(authService.loginWithRiskControl(request, riskControlService));
    }

    // 风控验证
    @PostMapping("/risk-verify")
    public ResponseEntity<LoginResponse> riskVerify(@Valid @RequestBody RiskVerifyRequest request) {
        return ResponseEntity.ok(authService.riskVerifyLogin(request, riskControlService));
    }

    // 发送邮箱验证码
    @PostMapping("/send-email")
    public ResponseEntity<SmsSendResponse> sendEmail(@Valid @RequestBody SendEmailRequest request) {
        String result = emailService.sendVerificationCode(request.getEmail());
        boolean success = result.contains("已发送");
        return ResponseEntity.ok(SmsSendResponse.builder()
                .success(success)
                .message(result)
                .build());
    }

    // 邮箱验证码登录
    @PostMapping("/email-login")
    public ResponseEntity<LoginResponse> emailLogin(@Valid @RequestBody EmailLoginRequest request) {
        return ResponseEntity.ok(authService.emailLogin(request));
    }

    @PostMapping("/refresh")
    public ResponseEntity<LoginResponse> refresh(@Valid @RequestBody RefreshRequest request) {
        return ResponseEntity.ok(authService.refresh(request));
    }

    // 登出 - 黑名单 Token，不删除用户
    @PostMapping("/logout")
    public ResponseEntity<Void> logout(
            HttpServletRequest request,
            @RequestBody RefreshRequest refreshRequest
    ) {
        String authHeader = request.getHeader("Authorization");
        String accessToken = null;
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            accessToken = authHeader.substring(7);
        }

        authService.logout(accessToken, refreshRequest.getRefreshToken());
        return ResponseEntity.ok().build();
    }

    // 注销账号 - 黑名单 Token + 删除用户
    @PostMapping("/delete-account")
    public ResponseEntity<Void> deleteAccount(
            HttpServletRequest request,
            @RequestBody RefreshRequest refreshRequest
    ) {
        String authHeader = request.getHeader("Authorization");
        String accessToken = null;
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            accessToken = authHeader.substring(7);
        }

        authService.deleteAccount(accessToken, refreshRequest.getRefreshToken());
        return ResponseEntity.ok().build();
    }
}