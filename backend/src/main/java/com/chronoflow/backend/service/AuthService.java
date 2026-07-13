package com.chronoflow.backend.service;

import com.chronoflow.backend.dto.*;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;

import java.util.HashMap;

import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final UserService userService;
    private final JwtTokenProvider jwtTokenProvider;
    private final RefreshTokenService refreshTokenService;
    private final TokenBlacklistService tokenBlacklistService;
    private final SmsService smsService;
    private final EmailService emailService;

    /**
     * 带风控的登录
     */
    public LoginResponse loginWithRiskControl(LoginRequest request, RiskControlService riskControlService) {
        String username = request.getUsername();

        // Check login frequency (username-based, no user lookup needed)
        if (riskControlService.checkLoginFreq(username)) {
            User user = userService.findByUsername(username);
            return triggerRiskVerify(user, "login_freq", riskControlService);
        }

        // Check password failures (username-based, no user lookup needed)
        if (riskControlService.checkPasswordFail(username)) {
            User user = userService.findByUsername(username);
            return triggerRiskVerify(user, "password_fail", riskControlService);
        }

        // Attempt authentication
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(username, request.getPassword())
            );
        } catch (BadCredentialsException e) {
            riskControlService.recordPasswordFail(username);
            riskControlService.recordLoginAttempt(username);
            throw new BadCredentialsException("用户名或密码错误");
        } catch (Exception e) {
            riskControlService.recordLoginAttempt(username);
            throw new BusinessException("认证失败");
        }

        // Authentication succeeded - clear failure records
        riskControlService.clearPasswordFail(username);

        // Single user lookup after successful auth
        User user = userService.findByUsername(username);
        UserDetails userDetails = userService.loadUserByUsername(username);

        return buildLoginResponse(user, userDetails);
    }

    /**
     * Trigger risk verification - only exposes minimal info (no PII)
     */
    private LoginResponse triggerRiskVerify(User user, String riskType, RiskControlService riskControlService) {
        // Determine verification method
        String verifyType;
        if (user.getPhone() != null && !user.getPhone().isEmpty()) {
            verifyType = "sms";
        } else if (user.getEmail() != null && !user.getEmail().isEmpty()) {
            verifyType = "email";
        } else {
            throw new BusinessException("无法进行风控验证：用户无可用验证方式");
        }

        // Send verification code
        String riskToken = riskControlService.sendRiskVerifyCode(
                user.getUsername(),
                user.getPhone(),
                user.getEmail(),
                verifyType
        );

        // Only return risk-related fields, NOT full user PII
        return LoginResponse.builder()
                .riskRequired(true)
                .riskType(verifyType)
                .riskToken(riskToken)
                .build();
    }

    /**
     * Risk verification login
     */
    public LoginResponse riskVerifyLogin(RiskVerifyRequest request, RiskControlService riskControlService) {
        if (!riskControlService.verifyRiskCode(request.getRiskToken(), request.getCode())) {
            throw new BusinessException("验证码错误或已过期");
        }

        String username = riskControlService.extractUsernameFromRiskToken(request.getRiskToken());
        if (username == null) {
            throw new BusinessException("风控令牌无效");
        }
        User user = userService.findByUsername(username);
        UserDetails userDetails = userService.loadUserByUsername(username);

        riskControlService.clearPasswordFail(username);

        return buildLoginResponse(user, userDetails);
    }

    /**
     * SMS verification code login
     */
    public LoginResponse smsLogin(SmsLoginRequest request) {
        if (!smsService.verifyCode(request.getPhone(), request.getCode())) {
            throw new BusinessException("验证码错误或已过期");
        }
        User user = userService.findByPhone(request.getPhone());
        UserDetails userDetails = userService.loadUserByUsername(user.getUsername());
        LoginResponse response = buildLoginResponse(user, userDetails);
        smsService.consumeCode(request.getPhone());
        return response;
    }

    /**
     * Email verification code login
     */
    public LoginResponse emailLogin(EmailLoginRequest request) {
        if (!emailService.verifyCode(request.getEmail(), request.getCode())) {
            throw new BusinessException("验证码错误或已过期");
        }
        User user = userService.findByEmail(request.getEmail());
        UserDetails userDetails = userService.loadUserByUsername(user.getUsername());
        return buildLoginResponse(user, userDetails);
    }

    /**
     * Build login response with tokens
     */
    private LoginResponse buildLoginResponse(User user, UserDetails userDetails) {
        Map<String, Object> extraClaims = new HashMap<>();
        extraClaims.put("username", user.getUsername());

        String accessToken = jwtTokenProvider.generateAccessToken(extraClaims, user.getId(), userDetails);
        String refreshToken = jwtTokenProvider.generateRefreshToken(extraClaims, user.getId(), userDetails);

        refreshTokenService.saveRefreshToken(userDetails, refreshToken);

        return LoginResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .userId(user.getId())
                .username(user.getUsername())
                .nickname(user.getNickname())
                .email(user.getEmail())
                .phone(user.getPhone())
                                .riskRequired(false)
                .realNameVerified(user.getRealNameVerified() != null && user.getRealNameVerified())
                .realName(user.getRealName())
                .build();
    }

    /**
     * Refresh token - also stores old token in refresh rotation history
     */
    public LoginResponse refresh(RefreshRequest request) {
        String oldRefreshToken = request.getRefreshToken();

        if (!refreshTokenService.validateRefreshToken(oldRefreshToken)) {
            throw new BusinessException("刷新令牌无效或已过期");
        }

        String username = jwtTokenProvider.extractUsername(oldRefreshToken);
        UserDetails userDetails = userService.loadUserByUsername(username);
        User user = userService.findByUsername(username);

        Map<String, Object> extraClaims = new HashMap<>();
        extraClaims.put("username", user.getUsername());

        String newAccessToken = jwtTokenProvider.generateAccessToken(extraClaims, user.getId(), userDetails);
        String newRefreshToken = jwtTokenProvider.generateRefreshToken(extraClaims, user.getId(), userDetails);

        // Save new refresh token (overwrites old in Redis)
        refreshTokenService.saveRefreshToken(userDetails, newRefreshToken);

        // Blacklist the old refresh token to prevent reuse (rotation detection)
        long remainingTime = jwtTokenProvider.getRemainingTimeMillis(oldRefreshToken);
        if (remainingTime > 0) {
            tokenBlacklistService.blacklistToken(oldRefreshToken, remainingTime);
        }

        // Also rotate the jti family stored in Redis for refresh token reuse detection
        String oldJti = jwtTokenProvider.extractJti(oldRefreshToken);
        if (oldJti != null) {
            refreshTokenService.markTokenFamilyInvalid(user.getId(), oldJti);
        }

        return LoginResponse.builder()
                .accessToken(newAccessToken)
                .refreshToken(newRefreshToken)
                .tokenType("Bearer")
                .userId(user.getId())
                .username(user.getUsername())
                .nickname(user.getNickname())
                .email(user.getEmail())
                .phone(user.getPhone())
                                .realNameVerified(user.getRealNameVerified() != null && user.getRealNameVerified())
                .realName(user.getRealName())
                .build();
    }

    /**
     * Logout - blacklist both tokens
     */
    public void logout(String accessToken, String refreshToken) {
        if (accessToken != null) {
            try {
                long remainingTime = jwtTokenProvider.getRemainingTimeMillis(accessToken);
                if (remainingTime > 0) {
                    tokenBlacklistService.blacklistToken(accessToken, remainingTime);
                }
            } catch (Exception e) {
                log.warn("Failed to blacklist access token during logout", e);
            }
        }

        if (refreshToken != null) {
            try {
                long remainingTime = jwtTokenProvider.getRemainingTimeMillis(refreshToken);
                if (remainingTime > 0) {
                    tokenBlacklistService.blacklistToken(refreshToken, remainingTime);
                }
                // Also delete from refresh token store
                String username = jwtTokenProvider.extractUsername(refreshToken);
                if (username != null) {
                    User user = userService.findByUsername(username);
                    if (user != null) {
                        refreshTokenService.deleteRefreshToken(user.getId());
                    }
                }
            } catch (Exception e) {
                log.warn("Failed to blacklist refresh token during logout", e);
            }
        }
    }

    /**
     * Delete account - validate token first, then logout and delete
     */
    public void deleteAccount(String accessToken, String refreshToken) {
        // Validate refresh token BEFORE blacklisting it
        String username = null;
        if (refreshToken != null && jwtTokenProvider.validateToken(refreshToken)) {
            username = jwtTokenProvider.extractUsername(refreshToken);
        }

        // If we couldn't get username from refresh token, try access token
        if (username == null && accessToken != null && jwtTokenProvider.validateToken(accessToken)) {
            username = jwtTokenProvider.extractUsername(accessToken);
        }

        if (username == null) {
            throw new BusinessException("无法验证用户身份，请重新登录");
        }

        User user = userService.findByUsername(username);

        // Delete account first (may throw if user owns groups with other members)
        userService.deleteUser(user.getId());

        // Then blacklist tokens (only reached if deleteUser succeeded)
        logout(accessToken, refreshToken);
    }
}
