package com.chronoflow.backend.mindflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chronoflow.backend.mindflow.entity.StudentProfile;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/**
 * 学习画像 Mapper — MyBatis-Plus BaseMapper 提供标准CRUD。
 */
@Mapper
public interface StudentProfileMapper extends BaseMapper<StudentProfile> {

    /** 按用户ID查询画像（userId 是唯一键，非主键） */
    @Select("SELECT * FROM student_profile WHERE user_id = #{userId}")
    StudentProfile selectByUserId(@Param("userId") Long userId);
}