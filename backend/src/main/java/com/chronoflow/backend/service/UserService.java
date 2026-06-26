package com.chronoflow.backend.service;
import com.chronoflow.backend.exception.ContentModerationException;
import com.chronoflow.backend.exception.BusinessException;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.chronoflow.backend.entity.GroupMember;
import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.GroupMemberMapper;
import com.chronoflow.backend.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class UserService implements UserDetailsService {

    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final ContentModerationService contentModerationService;
    private final GroupMemberMapper groupMemberMapper;
    private final com.chronoflow.backend.mapper.GroupMapper groupMapper;

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

    @Transactional
    public void deleteUser(Long userId) {
        // Safety check: don't delete user if they own groups with other members
        java.util.List<com.chronoflow.backend.entity.Group> ownedGroups =
                groupMapper.selectList(new com.baomidou.mybatisplus.core.conditions.query.QueryWrapper<com.chronoflow.backend.entity.Group>()
                        .eq("creator_id", userId));
        for (com.chronoflow.backend.entity.Group g : ownedGroups) {
            long memberCount = groupMemberMapper.selectCount(
                    new com.baomidou.mybatisplus.core.conditions.query.QueryWrapper<GroupMember>()
                            .eq("group_id", g.getId()));
            boolean creatorIsMember = groupMemberMapper.exists(
                    new com.baomidou.mybatisplus.core.conditions.query.QueryWrapper<GroupMember>()
                            .eq("group_id", g.getId())
                            .eq("user_id", userId));
            long otherCount = memberCount - (creatorIsMember ? 1 : 0);
            if (otherCount > 0) {
                throw new BusinessException("你创建的群组「" + g.getName() + "」中还有其他成员，请先将群主转让给其他管理员后再注销");
            }
            // Check for child groups before dissolving
            long childCount = groupMapper.selectCount(
                    new com.baomidou.mybatisplus.core.conditions.query.QueryWrapper<com.chronoflow.backend.entity.Group>()
                            .eq("parent_id", g.getId()));
            if (childCount > 0) {
                throw new BusinessException("你创建的群组「" + g.getName() + "」下有 " + childCount + " 个子群组，请先逐个解散子群组后再注销");
            }
            groupMapper.deleteById(g.getId());
        }
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

    @Transactional
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

        String oldUsername = user.getUsername();
        user.setNickname(nickname);
        user.setNicknameUpdatedAt(LocalDateTime.now());
        userMapper.updateById(user);

        // 同步群组成员昵称：只更新未自定义过的（昵称仍等于旧用户名的）
        LambdaQueryWrapper<GroupMember> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(GroupMember::getUserId, userId)
               .eq(GroupMember::getNickname, oldUsername);
        GroupMember updateMember = new GroupMember();
        updateMember.setNickname(nickname);
        groupMemberMapper.update(updateMember, wrapper);
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

    /**
     * Save real-person verification result to user record.
     *
     * @param userId         authenticated user
     * @param realName       user's real name (plaintext)
     * @param idCardNumber   user's ID card number (already encrypted by caller)
     */
    @Transactional
    public void saveRealPersonVerification(Long userId, String realName, String idCardNumber) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new UsernameNotFoundException("用户不存在");
        }
        if (Boolean.TRUE.equals(user.getRealNameVerified())) {
            // Already verified — idempotent, don't overwrite
            return;
        }
        user.setRealNameVerified(true);
        user.setRealName(realName);
        user.setIdCardNumber(idCardNumber);
        user.setVerifiedAt(LocalDateTime.now());
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