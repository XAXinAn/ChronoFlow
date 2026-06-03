import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/auth_service.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';
import 'create_group_page.dart';
import 'join_group_page.dart';
import 'group_detail_page.dart';

class GroupPage extends StatefulWidget {
  const GroupPage({super.key});
  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final GroupService _groupService = GroupService();
  List<Group> _createdGroups = [];
  List<Group> _joinedGroups = [];
  bool _isLoading = true;
  String? _error;
  bool _isFirstBuild = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFirstBuild) _loadGroups();
    _isFirstBuild = false;
  }

  Future<void> _loadGroups() async {
    if (!mounted) return;
    final uid = AuthService.currentUser?.userId ?? 0;
    setState(() { _isLoading = true; _error = null; });
    try {
      final groups = await _groupService.getMyGroups();
      if (!mounted) return;
      setState(() {
        _createdGroups = groups.where((g) => g.creatorId == uid).toList()..sort(_groupSort);
        _joinedGroups = groups.where((g) => g.creatorId != uid).toList()..sort(_groupSort);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = MessageUtils.cleanError(e); });
    }
  }

  int _groupSort(Group a, Group b) {
    final aChinese = _isChinese(a.name.isNotEmpty ? a.name[0] : '');
    final bChinese = _isChinese(b.name.isNotEmpty ? b.name[0] : '');
    if (aChinese && bChinese) return a.name.compareTo(b.name);
    if (aChinese && !bChinese) return -1;
    if (!aChinese && bChinese) return 1;
    return a.name.compareTo(b.name);
  }

  bool _isChinese(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF)   // CJK Unified
        || (code >= 0x3400 && code <= 0x4DBF)   // CJK Extension A
        || (code >= 0x20000 && code <= 0x2A6DF); // CJK Extension B
  }

  void _navigateToGroup(Group group) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailPage(group: group)))
        .then((result) { if (result == true) _loadGroups(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的群组'), centerTitle: true),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _buildActionCard(icon: Icons.add_circle_outline, label: '创建群组', onTap: () async {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupPage()));
              if (r != null) _loadGroups();
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildActionCard(icon: Icons.login, label: '加入群组', onTap: () async {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinGroupPage()));
              if (r != null) _loadGroups();
            })),
          ]),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)), const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadGroups, child: const Text('重试')),
                    ]))
                  : _createdGroups.isEmpty && _joinedGroups.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.group_outlined, size: 64, color: Colors.black.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          const Text('暂无群组', style: TextStyle(fontSize: 16, color: Colors.black54)),
                          const SizedBox(height: 8),
                          const Text('创建或加入一个群组开始吧', style: TextStyle(fontSize: 14, color: Colors.black38)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _loadGroups,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (_createdGroups.isNotEmpty) ...[
                                const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('我创建的', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black45))),
                                ..._createdGroups.map((g) => _buildGroupItem(g)),
                              ],
                              if (_joinedGroups.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('我加入的', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black45))),
                                ..._joinedGroups.map((g) => _buildGroupItem(g)),
                              ],
                            ],
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _buildGroupItem(Group group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToGroup(group),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.group, color: Colors.black38)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(group.description, style: const TextStyle(fontSize: 13, color: Colors.black45), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.people, size: 14, color: Colors.black38), const SizedBox(width: 4),
                  Text('${group.memberCount} 人', style: const TextStyle(fontSize: 12, color: Colors.black38)),
                  if (group.parentId != null) ...[
                    const SizedBox(width: 12), const Icon(Icons.account_tree, size: 14, color: Colors.black38), const SizedBox(width: 4),
                    Text('子群组', style: const TextStyle(fontSize: 12, color: Colors.black38)),
                  ],
                ]),
              ])),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [Icon(icon, size: 28, color: Colors.black54), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87))]),
        ),
      ),
    );
  }
}
