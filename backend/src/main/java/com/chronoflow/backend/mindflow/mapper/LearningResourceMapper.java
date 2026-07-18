package com.chronoflow.backend.mindflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chronoflow.backend.mindflow.entity.LearningResource;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

/**
 * 学习资源 Mapper。
 */
@Mapper
public interface LearningResourceMapper extends BaseMapper<LearningResource> {

    /** 按资源类型查询用户资源列表 */
    @Select("SELECT * FROM learning_resource WHERE user_id = #{userId} AND resource_type = #{resourceType} ORDER BY created_at DESC")
    List<LearningResource> findByUserIdAndType(Long userId, String resourceType);

    /** 查询用户今日生成资源数量（用于限制检查） */
    @Select("SELECT COUNT(*) FROM learning_resource WHERE user_id = #{userId} AND DATE(created_at) = CURDATE()")
    int countTodayByUserId(Long userId);
}