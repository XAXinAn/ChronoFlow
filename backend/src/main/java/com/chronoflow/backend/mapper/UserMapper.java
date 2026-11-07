package com.chronoflow.backend.mapper;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chronoflow.backend.entity.User;
import org.apache.ibatis.annotations.Mapper;

import java.util.Collections;
import java.util.List;

@Mapper
public interface UserMapper extends BaseMapper<User> {

    default List<User> selectListByPhones(List<String> phones) {
        if (phones == null || phones.isEmpty()) {
            return Collections.emptyList();
        }
        return selectList(new QueryWrapper<User>().in("phone", phones));
    }

    default List<User> selectListByEmails(List<String> emails) {
        if (emails == null || emails.isEmpty()) {
            return Collections.emptyList();
        }
        return selectList(new QueryWrapper<User>().in("email", emails));
    }

    default List<User> selectListByStudentIds(List<String> studentIds) {
        if (studentIds == null || studentIds.isEmpty()) {
            return Collections.emptyList();
        }
        return selectList(new QueryWrapper<User>().in("student_id", studentIds));
    }
}