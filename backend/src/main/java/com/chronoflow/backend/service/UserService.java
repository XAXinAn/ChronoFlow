package com.chronoflow.backend.service;
import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.exception.BusinessException;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;

import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class UserService implements UserDetailsService {

    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final ContentModerationService contentModerationService;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>().eq(User::getUsername, username));
        if (user == null) {
            throw new UsernameNotFoundException("User not found: " + username);
        }
        return user;
    }

    public User findByUsername(String username) {
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>().eq(User::getUsername, username));
        if (user == null) {
            throw new UsernameNotFoundException("User not found: " + username);
        }
        return user;
    }

    public User findById(Long id) {
        User user = userMapper.selectById(id);
        if (user == null) {
            throw new UsernameNotFoundException("User not found with id: " + id);
        }
        return user;
    }

    public User save(User user) {
        userMapper.insert(user);
        return user;
    }

    public boolean existsByUsername(String username) {
        return userMapper.selectCount(new LambdaQueryWrapper<User>().eq(User::getUsername, username)) > 0;
    }

    public boolean existsByEmail(String email) {
        return userMapper.selectCount(new LambdaQueryWrapper<User>().eq(User::getEmail, email)) > 0;
    }

    public User findByEmail(String email) {
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>().eq(User::getEmail, email));
        if (user == null) {
            throw new UsernameNotFoundException("用户不存在: " + email);
        }
        return user;
    }

    public boolean existsByPhone(String phone) {
        return userMapper.selectCount(new LambdaQueryWrapper<User>().eq(User::getPhone, phone)) > 0;
    }

    public User findByPhone(String phone) {
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>().eq(User::getPhone, phone));
        if (user == null) {
            throw new UsernameNotFoundException("用户不存在: " + phone);
        }
        return user;
    }

    public void deleteUser(Long userId) {
        userMapper.deleteById(userId);
    }

    public void bindEmail(Long userId, String email) {
        // Check uniqueness: email must not be used by another user
        User existingByEmail = userMapper.selectOne(
                new LambdaQueryWrapper<User>().eq(User::getEmail, email));
        if (existingByEmail != null && !existingByEmail.getId().equals(userId)) {
            throw new BusinessException("该邮箱已被其他用户绑定");
        }

        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new UsernameNotFoundException("用户不存在");
        }
        user.setEmail(email);
        userMapper.updateById(user);
    }

    public void updateNickname(Long userId, String nickname) {
        // 内容审核
        String reason = contentModerationService.moderate(nickname);
        if (reason != null) {
            throw new ContentModerationException(reason);
        }

        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new UsernameNotFoundException("用户不存在");
        }

        if (user.getNicknameUpdatedAt() != null) {
            LocalDateTime lastUpdate = user.getNicknameUpdatedAt();
            LocalDateTime nextUpdate = lastUpdate.plusDays(30);
            if (LocalDateTime.now().isBefore(nextUpdate)) {
                java.time.Duration duration = java.time.Duration.between(LocalDateTime.now(), nextUpdate);
                String waitTime;
                if (duration.toDays() > 0) {
                    waitTime = duration.toDays() + "天";
                } else if (duration.toHours() > 0) {
                    waitTime = duration.toHours() + "小时";
                } else {
                    waitTime = duration.toMinutes() + "分钟";
                }
                throw new BusinessException("距离上次修改未满30天，还需等待" + waitTime);
            }
        }

        user.setNickname(nickname);
        user.setNicknameUpdatedAt(LocalDateTime.now());
        userMapper.updateById(user);
    }

    public void bindPhone(Long userId, String phone) {
        // Check uniqueness: phone must not be used by another user
        User existingByPhone = userMapper.selectOne(
                new LambdaQueryWrapper<User>().eq(User::getPhone, phone));
        if (existingByPhone != null && !existingByPhone.getId().equals(userId)) {
            throw new BusinessException("该手机号已被其他用户绑定");
        }

        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new UsernameNotFoundException("用户不存在");
        }
        user.setPhone(phone);
        userMapper.updateById(user);
    }

    public void changePassword(Long userId, String oldPassword, String newPassword) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new UsernameNotFoundException("用户不存在");
        }
        // 验证旧密码
        if (!passwordEncoder.matches(oldPassword, user.getPassword())) {
            throw new BusinessException("旧密码错误");
        }
        user.setPassword(passwordEncoder.encode(newPassword));
        userMapper.updateById(user);
    }
}