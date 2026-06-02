import 'dart:convert';
import '../model/group_model.dart';
import 'api_client.dart';

class GroupService {
  static const _baseUrl = '/groups';

  Future<List<Group>> getMyGroups() async {
    final response = await ApiClient.get('$_baseUrl/my');
    final data = json.decode(response);

    if (data['code'] == 200) {
      final List<dynamic> list = data['data'] ?? [];
      return list.map((json) => Group.fromJson(json)).toList();
    }
    throw Exception(data['message'] ?? '获取群组列表失败');
  }

  Future<Group> createGroup({
    required String name,
    required String description,
  }) async {
    final response = await ApiClient.post(
      _baseUrl,
      body: {
        'name': name,
        'description': description,
      },
    );
    final data = json.decode(response);

    if (data['code'] == 200) {
      return Group.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? '创建群组失败');
  }

  Future<Group> joinGroup(String inviteCode) async {
    final response = await ApiClient.post(
      '$_baseUrl/join',
      body: {'inviteCode': inviteCode},
    );
    final data = json.decode(response);

    if (data['code'] == 200) {
      return Group.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? '加入群组失败');
  }

  Future<void> leaveGroup(String groupId) async {
    final response = await ApiClient.delete('$_baseUrl/$groupId/leave');
    final data = json.decode(response);

    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '退出群组失败');
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final response = await ApiClient.delete('$_baseUrl/$groupId');
    final data = json.decode(response);

    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '删除群组失败');
    }
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final response = await ApiClient.get('$_baseUrl/$groupId/members');
    final data = json.decode(response);

    if (data['code'] == 200) {
      final List<dynamic> list = data['data']['members'] ?? [];
      return list.map((json) => GroupMember.fromJson(json)).toList();
    }
    throw Exception(data['message'] ?? '获取成员列表失败');
  }

  Future<void> setGroupAdmin(String groupId, int userId, bool isAdmin) async {
    final response = await ApiClient.put(
      '$_baseUrl/$groupId/admins/$userId',
      body: {'isAdmin': isAdmin},
    );
    final data = json.decode(response);

    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '设置管理员失败');
    }
  }

  Future<void> updateGroupSettings(String groupId, {bool? requireApproval}) async {
    final body = <String, dynamic>{};
    if (requireApproval != null) {
      body['requireApproval'] = requireApproval;
    }

    final response = await ApiClient.put(
      '$_baseUrl/$groupId/settings',
      body: body,
    );
    final data = json.decode(response);

    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '更新群组设置失败');
    }
  }

  Future<List<JoinRequest>> getJoinRequests(String groupId) async {
    final response = await ApiClient.get('$_baseUrl/$groupId/join-requests');
    final data = json.decode(response);

    if (data['code'] == 200) {
      final List<dynamic> list = data['data'] ?? [];
      return list.map((json) => JoinRequest.fromJson(json)).toList();
    }
    throw Exception(data['message'] ?? '获取加群申请失败');
  }

  Future<void> approveJoinRequest(String groupId, int userId, bool approve) async {
    final response = await ApiClient.put(
      '$_baseUrl/$groupId/join-requests/$userId',
      body: {'approve': approve},
    );
    final data = json.decode(response);

    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '处理加群申请失败');
    }
  }

  Future<void> removeMember(String groupId, int userId) async {
    final response = await ApiClient.delete('$_baseUrl/$groupId/members/$userId');
    final data = json.decode(response);

    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '移除成员失败');
    }
  }

  Future<List<JoinRequest>> getMyJoinRequests() async {
    final response = await ApiClient.get('/groups/my-join-requests');
    final data = json.decode(response);

    if (data['code'] == 200) {
      final List<dynamic> list = data['data'] ?? [];
      return list.map((json) => JoinRequest.fromJson(json)).toList();
    }
    throw Exception(data['message'] ?? '获取加群申请失败');
  }

  Future<Group> getGroupInfoByInviteCode(String inviteCode) async {
    final response = await ApiClient.get('$_baseUrl/info', params: {'inviteCode': inviteCode});
    final data = json.decode(response);

    if (data['code'] == 200) {
      return Group.fromJson(data['data']);
    }
    throw Exception(data['message'] ?? '获取群组信息失败');
  }
}
