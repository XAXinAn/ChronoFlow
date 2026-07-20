package com.chronoflow.backend.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chronoflow.backend.entity.GroupMember;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface GroupMemberMapper extends BaseMapper<GroupMember> {
}
