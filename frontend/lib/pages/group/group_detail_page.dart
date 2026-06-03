import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import '../../model/group_model.dart';
import '../../service/auth_service.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';
import 'group_qr_page.dart';
import 'group_members_page.dart';
import 'group_settings_page.dart';
import 'create_subgroup_page.dart';

class GroupDetailPage extends StatefulWidget {
  final Group group;
  const GroupDetailPage({super.key, required this.group});
  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final GroupService _groupService = GroupService();
  bool _isLoading = true;
  bool _isCreator = false, _isAdmin = false, _isFirstBuild = true;
  List<Group> _children = [];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadChildren();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFirstBuild) { _checkPermissions(); _loadChildren(); }
    _isFirstBuild = false;
  }

  void _checkPermissions() {
    final u = AuthService.currentUser; if (u == null) return;
    _isCreator = u.userId == widget.group.creatorId;
    _isAdmin = widget.group.isAdminOrCreator && !_isCreator;
    print('GroupDetail ${widget.group.name}: userId=${u.userId}, creatorId=${widget.group.creatorId}, isAdminOrCreator=${widget.group.isAdminOrCreator}, _isCreator=$_isCreator, _isAdmin=$_isAdmin');
    _isLoading = false;
  }

  Future<void> _loadChildren() async {
    try {
      final children = await _groupService.getGroupChildren(widget.group.id);
      children.sort((a, b) {
        final ap = PinyinHelper.getPinyinE(a.name, defPinyin: '');
        final bp = PinyinHelper.getPinyinE(b.name, defPinyin: '');
        if (ap.isNotEmpty && bp.isNotEmpty) return ap.compareTo(bp);
        if (ap.isNotEmpty) return -1;
        if (bp.isNotEmpty) return 1;
        return a.name.compareTo(b.name);
      });
      if (mounted) setState(() => _children = children);
    } catch (_) {}
  }

  Future<void> _requestSubgroup() async {
    final result = await Navigator.push(context,
      MaterialPageRoute(builder: (_) => CreateSubgroupPage(parentGroupId: widget.group.id, parentGroupName: widget.group.name)));
    if (result == true) _loadChildren();
  }

  String get _depthLabel {
    final d = widget.group.depth;
    if (d == 0) return '根群组';
    if (d == 1) return '直属子群组';
    return '第${d}层子群组';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name), centerTitle: true),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.group.description.isNotEmpty) ...[
            Text(widget.group.description, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 16),
          ],
          // 层级信息
          Container(
            padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.account_tree, size: 16, color: widget.group.parentId != null ? Colors.teal : Colors.blue.shade400),
              const SizedBox(width: 8),
              Text(_depthLabel, style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
            ]),
          ),
          // 申请子群
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => _requestSubgroup(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('申请创建子群组'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black54, side: const BorderSide(color: Colors.black12)),
          )),
          const SizedBox(height: 12),
          // 成员
          InkWell(
            onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupMembersPage(group: widget.group))); },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Row(children: [
                const Icon(Icons.people, size: 22, color: Colors.black54), const SizedBox(width: 16),
                Text('${widget.group.memberCount} 名成员', style: const TextStyle(fontSize: 15, color: Colors.black87)),
                const Spacer(), const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // 邀请码
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Row(children: [
              const Icon(Icons.link, size: 22, color: Colors.black54), const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('邀请码', style: TextStyle(fontSize: 12, color: Colors.black54)), const SizedBox(height: 4),
                Text(widget.group.inviteCode, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w500, fontSize: 18)),
              ])),
              IconButton(icon: const Icon(Icons.qr_code, size: 22, color: Colors.black54),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupQrPage(group: widget.group)))),
            ]),
          ),
          // 子群组列表
          if (_children.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('直属子群组', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
            const SizedBox(height: 8),
            ..._children.map((child) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailPage(group: child))),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.group, color: Colors.teal, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(child.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        Text('${child.memberCount} 人${child.descendantCount > 0 ? " · ${child.descendantCount}个子群组" : ""}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                      ])),
                      const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
                    ]),
                  ),
                ),
              ),
            )),
          ],
          const SizedBox(height: 12),
          if (_isCreator || _isAdmin) ...[
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupSettingsPage(group: widget.group))),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))]),
                child: const Row(children: [
                  Icon(Icons.settings, size: 22, color: Colors.black54), SizedBox(width: 16),
                  Text('群组设置', style: TextStyle(fontSize: 16, color: Colors.black87)),
                  Spacer(), Icon(Icons.chevron_right, size: 20, color: Colors.black26),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
