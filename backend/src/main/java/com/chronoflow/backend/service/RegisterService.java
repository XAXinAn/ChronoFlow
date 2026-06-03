package com.chronoflow.backend.service;

import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.exception.BusinessException;
import com.chronoflow.backend.dto.RegisterResponse;
import com.chronoflow.backend.dto.RegisterVerifyRequest;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.UserMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class RegisterService {

    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final SmsService smsService;
    private final ContentModerationService contentModerationService;

    public RegisterResponse registerWithVerify(RegisterVerifyRequest request) {
        if (!smsService.verifyCode(request.getPhone(), request.getCode())) {
            throw new BusinessException("验证码错误或已过期");
        }

        if (userMapper.selectCount(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, request.getUsername())) > 0) {
            throw new BusinessException("用户名已存在");
        }

        if (userMapper.selectCount(new LambdaQueryWrapper<User>()
                .eq(User::getPhone, request.getPhone())) > 0) {
            throw new BusinessException("手机号已被注册");
        }

        String reason = contentModerationService.moderate(request.getUsername());
        if (reason != null) {
            throw new ContentModerationException(reason);
        }

        String phone = request.getPhone();
        String lastFourPhone = phone.length() >= 4 ? phone.substring(phone.length() - 4) : phone;
        String nickname = lastFourPhone + "用户";

        User user = User.builder()
                .username(request.getUsername())
                .nickname(nickname)
                .phone(request.getPhone())
                .password(passwordEncoder.encode(request.getPassword()))
                .build();

        userMapper.insert(user);

        return RegisterResponse.builder()
                .id(user.getId())
                .username(user.getUsername())
                .nickname(user.getNickname())
                .phone(user.getPhone())
                .build();
    }
}
