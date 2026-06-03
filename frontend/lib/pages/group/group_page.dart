import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';
import 'create_group_page.dart';
import 'join_group_page.dart';
import 'group_detail_page.dart';

/// 我的群组页面 - 树形层级展示
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
      setState(() { _groups = tree; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = MessageUtils.cleanError(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的群组'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildActionCard(Icons.add_circle_outline, '创建群组', () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupPage()));
                  if (result != null) _loadGroups();
                })),
                const SizedBox(width: 12),
                Expanded(child: _buildActionCard(Icons.login, '加入群组', () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinGroupPage()));
                  if (result != null) _loadGroups();
                })),
              ],
            ),
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
                            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: _buildTreeList(_groups, 0)),
                          ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTreeList(List<Group> groups, int depth) {
    final widgets = <Widget>[];
    for (final group in groups) {
      widgets.add(_buildGroupItem(group, depth));
      if (group.children != null && group.children!.isNotEmpty) {
        widgets.addAll(_buildTreeList(group.children!, depth + 1));
      }
    }
    return widgets;
  }

  Widget _buildGroupItem(Group group, int depth) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GroupDetailPage(group: group)),
          ).then((result) { if (result == true) _loadGroups(); }),
          child: Container(
            padding: EdgeInsets.only(left: 16.0 + depth * 20, right: 16, top: 14, bottom: 14),
            decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                if (depth > 0) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.black26),
                  ),
                ],
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.group, color: Colors.black38),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(group.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    if (group.description.isNotEmpty)
                      Text(group.description, style: const TextStyle(fontSize: 12, color: Colors.black45), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${group.memberCount} 人', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                  ]),
                ),
                if (group.hasChildren)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text('${_countAllChildren(group)}个子群', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                  ),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _countAllChildren(Group group) {
    int count = group.children?.length ?? 0;
    if (group.children != null) {
      for (final c in group.children!) {
        count += _countAllChildren(c);
      }
    }
    return count;
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
