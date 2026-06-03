import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
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
  List<Group> _groups = [];
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
    setState(() { _isLoading = true; _error = null; });
    try {
      final tree = await _groupService.getMyGroupTree();
      if (!mounted) return;
      setState(() { _groups = _flattenTree(tree); _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = MessageUtils.cleanError(e); });
    }
  }

  /// Flatten tree: root groups first, then their children, depth-first.
  /// Different roots (organizations) separated by a special marker (depth=-1 name='---').
  List<Group> _flattenTree(List<Group> roots) {
    final result = <Group>[];
    for (int i = 0; i < roots.length; i++) {
      if (i > 0) {
        result.add(Group(id: '__divider__', name: '', description: '', inviteCode: '', memberCount: 0,
            creatorId: 0, createdAt: DateTime.now(), requireApproval: false, depth: -1));
      }
      _appendWithChildren(roots[i], result);
    }
    return result;
  }

  void _appendWithChildren(Group group, List<Group> result) {
    result.add(group);
    if (group.children != null && group.children!.isNotEmpty) {
      final sorted = List<Group>.from(group.children!)..sort(_pinyinSort);
      for (final child in sorted) {
        _appendWithChildren(child, result);
      }
    }
  }

  int _pinyinSort(Group a, Group b) {
    final aPinyin = PinyinHelper.getPinyinE(a.name, defPinyin: '');
    final bPinyin = PinyinHelper.getPinyinE(b.name, defPinyin: '');
    if (aPinyin.isNotEmpty && bPinyin.isNotEmpty) return aPinyin.compareTo(bPinyin);
    if (aPinyin.isNotEmpty) return -1;
    if (bPinyin.isNotEmpty) return 1;
    return a.name.compareTo(b.name);
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
                  : _groups.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.group_outlined, size: 64, color: Colors.black.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          const Text('暂无群组', style: TextStyle(fontSize: 16, color: Colors.black54)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _loadGroups,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _groups.length,
                            itemBuilder: (ctx, i) {
                              final g = _groups[i];
                              if (g.id == '__divider__') {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(color: Colors.black12, thickness: 1),
                                );
                              }
                              return _buildGroupItem(g);
                            },
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
                if (group.description.isNotEmpty)
                  Text(group.description, style: const TextStyle(fontSize: 13, color: Colors.black45), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${group.memberCount} 人', style: const TextStyle(fontSize: 12, color: Colors.black38)),
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
