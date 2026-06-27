package com.chronoflow.backend.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chronoflow.backend.entity.Feedback;
import org.apache.ibatis.annotations.Mapper;

/**用户反馈 */
@Mapper
public interface FeedbackMapper extends BaseMapper<Feedback> {
}