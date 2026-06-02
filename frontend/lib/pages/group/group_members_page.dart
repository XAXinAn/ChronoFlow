import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants/app_constants.dart';
import '../../model/group_model.dart';
import '../../service/auth_service.dart';
import '../../utils/message_utils.dart';

class GroupMembersPage extends StatefulWidget {
  final Group group;

  const GroupMembersPage({super.key, required this.group});

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  List<GroupMember> _members = [];
  final Set<int> _selectedMembers = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;
  bool _isCreator = false;
  bool _isAdmin = false;
  bool _isFirstBuild = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFirstBuild) {
      _loadMembers();
    }
    _isFirstBuild = false;
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final currentUser = AuthService.currentUser;
    _isCreator = currentUser?.userId == widget.group.creatorId;

    try {
      final token = await AuthService.getAccessToken();
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/groups/${widget.group.id}/members'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          final membersData = data['data']['members'] as List;
          final creatorId = data['data']['creatorId'] as int;
          final members = membersData.map((json) {
            return GroupMember(
              userId: json['userId'],
              username: json['username'] ?? '',
              nickname: json['nickname'] ?? '',
              email: json['email'] ?? '',
              isCreator: json['userId'] == creatorId,
              isAdmin: json['isAdmin'] ?? false,
            );
          }).toList();

          // 检查当前用户是否是管理员
          if (!_isCreator && currentUser != null) {
            final myMember = members.where((m) => m.userId == currentUser.userId).toList();
            _isAdmin = myMember.isNotEmpty && myMember.first.isAdmin;
          }

          if (mounted) {
            setState(() {
              _members = members;
              _isLoading = false;
            });
          }
          return;
        }
        throw Exception(data['message'] ?? '获取成员列表失败');
      }
      throw Exception('获取成员列表失败');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = MessageUtils.cleanError(e);
        });
      }
    }
  }

  bool get _canManageMembers => _isCreator || _isAdmin;

  int get _currentAdminCount {
    return _members.where((m) => m.isAdmin && m.userId != widget.group.creatorId).length;
  }

  int get _selectedAdminCount {
    return _members
        .where((m) => _selectedMembers.contains(m.userId) && m.isAdmin && m.userId != widget.group.creatorId)
        .length;
  }

  int get _totalAdminCount {
    return _currentAdminCount + _selectedAdminCount;
  }

  bool get _hasAdminSelected {
    if (_selectedMembers.isEmpty) return false;
    return _members
        .where((m) => _selectedMembers.contains(m.userId) && !_isMemberCreator(m))
        .every((m) => m.isAdmin);
  }

  bool get _canBatchSetAdmin {
    if (_selectedMembers.isEmpty) return false;
    // 只有群主可以设置/撤销管理员
    if (!_isCreator) return false;
    final selectedNonAdmins = _selectedMembers.where((uid) {
      final member = _members.where((m) => m.userId == uid).firstOrNull;
      return member != null && !member.isAdmin && !_isMemberCreator(member);
    }).length;
    final selectedAdmins = _selectedMembers.where((uid) {
      final member = _members.where((m) => m.userId == uid).firstOrNull;
      return member != null && member.isAdmin && !_isMemberCreator(member);
    }).length;

    // 只有全是管理员或全是非管理员时才显示按钮
    if (selectedAdmins > 0 && selectedNonAdmins > 0) return false;

    if (selectedNonAdmins > 0) {
      // 要设置为管理员，检查是否超过3人
      return (_totalAdminCount + selectedNonAdmins - selectedAdmins) <= 3;
    }

    return selectedAdmins > 0; // 撤销管理员总是可以
  }

  bool _isMemberCreator(GroupMember m) {
    return m.userId == widget.group.creatorId;
  }

  void _startSelection(int userId) {
    setState(() {
      _isSelectionMode = true;
      _selectedMembers.add(userId);
    });
  }

  void _toggleSelection(int userId) {
    setState(() {
      if (_selectedMembers.contains(userId)) {
        _selectedMembers.remove(userId);
        if (_selectedMembers.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMembers.add(userId);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedMembers.clear();
      _isSelectionMode = false;
    });
  }

  void _showMemberActions(GroupMember member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // 成员信息
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      member.nickname.isNotEmpty
                          ? member.nickname[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              member.nickname,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_isMemberCreator(member)) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '群主',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ] else if (member.isAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '管理员',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            // 操作选项
            // 只有群主可以设置/撤销管理员
            if (_isCreator && !_isMemberCreator(member)) ...[
              ListTile(
                leading: Icon(
                  member.isAdmin ? Icons.person_remove_outlined : Icons.person_add_alt_1,
                  color: Colors.orange,
                ),
                title: Text(member.isAdmin ? '撤销管理员' : '设为管理员'),
                subtitle: Text(
                  member.isAdmin
                      ? '取消该成员的管理员权限'
                      : '授予该成员管理员权限',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _setAdmin(member);
                },
              ),
            ],
            // 群主和管理员都可以移出成员
            if (_canManageMembers && !_isMemberCreator(member)) ...[
              ListTile(
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: Colors.red,
                ),
                title: const Text('移出群聊'),
                subtitle: const Text('将该成员移出本群'),
                onTap: () {
                  Navigator.pop(context);
                  _removeMember(member);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _setAdmin(GroupMember member) async {
    try {
      final token = await AuthService.getAccessToken();
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/groups/${widget.group.id}/admins/${member.userId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'isAdmin': !member.isAdmin}),
      );

      if (response.statusCode == 200) {
        await _loadMembers();
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? '设置失败');
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.showError(context, e);
      }
    }
  }

  Future<void> _batchSetAdmin() async {
    if (_hasAdminSelected) {
      // 撤销管理员
      await _batchRevokeAdmin();
      return;
    }

    // 加为管理员
    final canSetCount = 3 - _currentAdminCount;
    final newAdmins = _selectedMembers.where((uid) {
      final member = _members.where((m) => m.userId == uid).firstOrNull;
      return member != null && !member.isAdmin && !_isMemberCreator(member);
    }).toList();

    if (newAdmins.length > canSetCount) {
      MessageUtils.show(context, '管理员数量不能超过3人，还可添加 $canSetCount 人');
      return;
    }

    try {
      final token = await AuthService.getAccessToken();

      for (final userId in newAdmins) {
        await http.put(
          Uri.parse('${AppConstants.baseUrl}/groups/${widget.group.id}/admins/$userId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'isAdmin': true}),
        );
      }

      if (mounted) {
        MessageUtils.show(context, '已设置为管理员');
        _cancelSelection();
        await _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.showError(context, e);
      }
    }
  }

  Future<void> _batchRevokeAdmin() async {
    try {
      final token = await AuthService.getAccessToken();

      for (final userId in _selectedMembers) {
        final member = _members.where((m) => m.userId == userId).firstOrNull;
        if (member != null && member.isAdmin && !_isMemberCreator(member)) {
          await http.put(
            Uri.parse('${AppConstants.baseUrl}/groups/${widget.group.id}/admins/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'isAdmin': false}),
          );
        }
      }

      if (mounted) {
        MessageUtils.show(context, '已撤销管理员权限');
        _cancelSelection();
        await _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.showError(context, e);
      }
    }
  }

  Future<void> _batchRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('移出成员'),
        content: Text('确定要将 ${_selectedMembers.length} 名成员移出群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('移出'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await AuthService.getAccessToken();

      for (final userId in _selectedMembers) {
        final member = _members.where((m) => m.userId == userId).firstOrNull;
        if (member != null && !_isMemberCreator(member)) {
          await http.delete(
            Uri.parse('${AppConstants.baseUrl}/groups/${widget.group.id}/members/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
        }
      }

      if (mounted) {
        MessageUtils.show(context, '已移出成员');
        _cancelSelection();
        await _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.showError(context, e);
      }
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('移出成员'),
        content: Text('确定要将 ${member.nickname} 移出群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('移出'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await AuthService.getAccessToken();
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/groups/${widget.group.id}/members/${member.userId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _loadMembers();
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? '移出失败');
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.currentUser?.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '已选择 ${_selectedMembers.length} 人' : '群成员'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelSelection,
              )
            : null,
      ),
      body: Column(
        children: [
          // 成员列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadMembers,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMembers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final isMe = member.userId == currentUserId;
                            final isSelected = _selectedMembers.contains(member.userId);

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onLongPress: _canManageMembers && !_isMemberCreator(member)
                                      ? () => _startSelection(member.userId)
                                      : null,
                                  onTap: () {
                                    if (_isSelectionMode && !_isMemberCreator(member)) {
                                      _toggleSelection(member.userId);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // 选择框
                                        if (_isSelectionMode && !_isMemberCreator(member))
                                          Container(
                                            width: 22,
                                            height: 22,
                                            margin: const EdgeInsets.only(right: 12),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? Colors.blue
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.blue
                                                    : Colors.black38,
                                                width: 2,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(
                                                    Icons.check,
                                                    size: 14,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                        // 头像
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: Colors.blue.shade50,
                                          child: Text(
                                            member.nickname.isNotEmpty
                                                ? member.nickname[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade400,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // 信息
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    member.nickname,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.shade200,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        '我',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 标签
                                        if (_isMemberCreator(member))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              '群主',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          )
                                        else if (member.isAdmin)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              '管理员',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          )
                                        else if (_isSelectionMode)
                                          const Icon(
                                            Icons.chevron_right,
                                            size: 20,
                                            color: Colors.black26,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // 底部操作栏
          if (_isSelectionMode && _selectedMembers.isNotEmpty)
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.black12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_canBatchSetAdmin)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _batchSetAdmin,
                        icon: Icon(_hasAdminSelected ? Icons.person_remove : Icons.person_add_alt_1),
                        label: Text(_hasAdminSelected ? '撤销管理员' : '加为管理员'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (_canBatchSetAdmin) const SizedBox(width: 12),
                  if (_canManageMembers)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _batchRemove,
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const Text('踢出群组'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}