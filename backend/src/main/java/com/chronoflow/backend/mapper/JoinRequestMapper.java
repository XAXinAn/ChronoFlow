package com.chronoflow.backend.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chronoflow.backend.entity.JoinRequest;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface JoinRequestMapper extends BaseMapper<JoinRequest> {
}