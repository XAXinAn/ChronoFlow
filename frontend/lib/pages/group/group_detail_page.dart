import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/auth_service.dart';
import '../../service/group_service.dart';
import 'group_qr_page.dart';
import 'group_members_page.dart';
import 'group_settings_page.dart';

class GroupDetailPage extends StatefulWidget {
  final Group group;

  const GroupDetailPage({super.key, required this.group});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final GroupService _groupService = GroupService();
  bool _isLoading = true;
  bool _isCreator = false;
  bool _isAdmin = false;
  bool _isFirstBuild = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFirstBuild) {
      _checkPermissions();
    }
    _isFirstBuild = false;
  }

  Future<void> _checkPermissions() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    final isCreator = currentUser.userId == widget.group.creatorId;

    // 如果是群主，直接显示设置
    if (isCreator) {
      if (mounted) {
        setState(() {
          _isCreator = true;
          _isAdmin = false;
          _isLoading = false;
        });
      }
      return;
    }

    // 检查是否是管理员
    try {
      final members = await _groupService.getGroupMembers(widget.group.id);
      final myMember = members.where((m) => m.userId == currentUser.userId).toList();
      if (myMember.isNotEmpty && mounted) {
        setState(() {
          _isCreator = false;
          _isAdmin = myMember.first.isAdmin;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestSubgroup() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('申请创建子群组'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(hintText: '子群组名称', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: descController, decoration: const InputDecoration(hintText: '描述（选填）', border: OutlineInputBorder()), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('提交')),
        ],
      ),
    );
    if (result != true) return;
    try {
      final gs = GroupService();
      await gs.createSubgroupRequest(widget.group.id, nameController.text.trim(), descController.text.trim());
      if (!mounted) return;
      MessageUtils.show(context, '申请已提交，请等待群主/管理员审核');
    } catch (e) {
      if (mounted) MessageUtils.showError(context, e);
    }
  }

  Future<void> _refreshGroupInfo() async {
    try {
      // Re-check admin status via member list (more targeted than loading all groups)
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        final members = await _groupService.getGroupMembers(widget.group.id);
        final myMember = members.where((m) => m.userId == currentUser.userId).toList();
        if (mounted) {
          setState(() {
            _isCreator = currentUser.userId == widget.group.creatorId;
            _isAdmin = myMember.isNotEmpty && myMember.first.isAdmin;
          });
        }
      }
    } catch (e) {
      // Silently ignore - permissions will stay as-is
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.group.description.isNotEmpty) ...[
                    Text(widget.group.description, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 16),
                  ],
                  // 层级信息
                  if (widget.group.parentId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.account_tree, size: 16, color: Colors.blue.shade400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('子群组 (第${widget.group.depth}层)',
                            style: TextStyle(fontSize: 13, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                        ),
                      ]),
                    ),
                  ],
                  // 申请创建子群组按钮
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _requestSubgroup(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('申请创建子群组'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black54,
                          side: const BorderSide(color: Colors.black12),
                        ),
                      ),
                    ),
                  ),
                  // 成员数
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupMembersPage(group: widget.group),
                        ),
                      );
                      _refreshGroupInfo();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Row(
                        children: [
                          const Icon(Icons.people, size: 22, color: Colors.black54),
                          const SizedBox(width: 16),
                          Text(
                            '${widget.group.memberCount} 名成员',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 邀请码
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 22, color: Colors.black54),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '邀请码',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.group.inviteCode,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code, size: 22, color: Colors.black54),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GroupQrPage(group: widget.group),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 设置（群主/管理员可见）
                  if (_isCreator || _isAdmin)
                    InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupSettingsPage(group: widget.group),
                          ),
                        );
                        _refreshGroupInfo();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                        child: const Row(
                          children: [
                            Icon(Icons.settings, size: 22, color: Colors.black54),
                            SizedBox(width: 16),
                            Text(
                              '群组设置',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            Spacer(),
                            Icon(Icons.chevron_right, size: 20, color: Colors.black26),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
