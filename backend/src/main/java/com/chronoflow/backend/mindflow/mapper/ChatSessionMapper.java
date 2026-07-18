package com.chronoflow.backend.mindflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chronoflow.backend.mindflow.entity.ChatSession;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

/**
 * 对话会话 Mapper。
 */
@Mapper
public interface ChatSessionMapper extends BaseMapper<ChatSession> {

    /** 查询用户的所有活跃会话，按更新时间倒序 */
    @Select("SELECT * FROM chat_session WHERE user_id = #{userId} AND status = 'ACTIVE' ORDER BY updated_at DESC")
    List<ChatSession> findActiveByUserId(Long userId);
}