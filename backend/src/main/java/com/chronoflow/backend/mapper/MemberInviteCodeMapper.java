package com.chronoflow.backend.mapper;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chronoflow.backend.entity.MemberInviteCode;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface MemberInviteCodeMapper extends BaseMapper<MemberInviteCode> {

    default MemberInviteCode selectByCode(String code) {
        return selectOne(new QueryWrapper<MemberInviteCode>().eq("code", code));
    }

    default java.util.List<MemberInviteCode> selectListByGroupId(String groupId) {
        return selectList(new QueryWrapper<MemberInviteCode>().eq("group_id", groupId));
    }
}
