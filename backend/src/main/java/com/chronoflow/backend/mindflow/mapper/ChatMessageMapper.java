package com.chronoflow.backend.mindflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chronoflow.backend.mindflow.entity.ChatMessage;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

/**
 * 对话消息 Mapper。
 */
@Mapper
public interface ChatMessageMapper extends BaseMapper<ChatMessage> {

    /** 获取会话最近N条消息（用于构建Agent上下文） */
    @Select("SELECT * FROM chat_message WHERE session_id = #{sessionId} ORDER BY created_at DESC LIMIT #{limit}")
    List<ChatMessage> findRecentBySessionId(String sessionId, int limit);

    /** 按时间正序获取会话全部消息 */
    @Select("SELECT * FROM chat_message WHERE session_id = #{sessionId} ORDER BY created_at ASC")
    List<ChatMessage> findBySessionIdOrderByTime(String sessionId);
}