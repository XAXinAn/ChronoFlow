import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

/// Tree multi-select page for choosing descendant groups to publish a schedule to.
class SelectPublishTargetsPage extends StatefulWidget {
  final String rootGroupId;
  final String rootGroupName;
  const SelectPublishTargetsPage({super.key, required this.rootGroupId, required this.rootGroupName});
  @override
  State<SelectPublishTargetsPage> createState() => _SelectPublishTargetsPageState();
}

class _SelectPublishTargetsPageState extends State<SelectPublishTargetsPage> {
  final GroupService _groupService = GroupService();
  List<Group> _tree = [];
  final Set<String> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final flatList = await _groupService.getDescendantTree(widget.rootGroupId);
      if (mounted) setState(() { _tree = _buildTree(flatList, widget.rootGroupId); _loading = false; });
    } catch (e) { if (mounted) setState(() => _loading = false); MessageUtils.showError(context, e); }
  }

  List<Group> _buildTree(List<Group> flat, String? parentId) {
    final result = <Group>[];
    for (final g in flat) {
      if (g.parentId == parentId) {
        final children = _buildTree(flat, g.id);
        // Create a copy with children set
        result.add(Group(
          id: g.id, name: g.name, description: g.description,
          inviteCode: g.inviteCode, memberCount: g.memberCount,
          creatorId: g.creatorId, createdAt: g.createdAt,
          requireApproval: g.requireApproval, depth: g.depth,
          descendantCount: g.descendantCount,
          hasChildren: children.isNotEmpty,
          children: children.isNotEmpty ? children : null,
        ));
      }
    }
    return result;
  }

  void _toggle(String id) {
    setState(() { if (_selected.contains(id)) _selected.remove(id); else _selected.add(id); });
  }

  List<Widget> _buildItems(List<Group> groups, int depth) {
    final items = <Widget>[];
    for (final g in groups) {
      // Don't show the root group itself (already publishing to it)
      final isSelf = g.id == widget.rootGroupId;
      if (isSelf) {
        if (g.children != null) items.addAll(_buildItems(g.children!, depth));
        continue;
      }
      final selected = _selected.contains(g.id);
      items.add(Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: selected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _toggle(g.id),
            child: Padding(
              padding: EdgeInsets.only(left: 16.0 + depth * 24, right: 16, top: 12, bottom: 12),
              child: Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.blue : Colors.transparent,
                    border: Border.all(color: selected ? Colors.blue : Colors.black38, width: 2),
                  ),
                  child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(g.name, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
                Text('${g.memberCount}人', style: const TextStyle(fontSize: 12, color: Colors.black38)),
              ]),
            ),
          ),
        ),
      ));
      if (g.children != null) items.addAll(_buildItems(g.children!, depth + 1));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择下发范围'),
        centerTitle: true,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, _selected.toList()), child: const Text('确定', style: TextStyle(fontSize: 16))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tree.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('该群组没有子群组', style: TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: () => Navigator.pop(context, <String>[]), child: const Text('确定')),
                ]))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade400),
                      const SizedBox(width: 8),
                      Expanded(child: Text('已选 ${_selected.length} 个下发目标（不含本群）', style: TextStyle(fontSize: 13, color: Colors.blue.shade700))),
                    ]),
                  ),
                  Container(height: 1, color: Colors.black12),
                  Expanded(child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Root group indicator
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 16),
                        child: Row(children: [
                          Icon(Icons.group, size: 18, color: Colors.blue.shade400),
                          const SizedBox(width: 8),
                          Text(widget.rootGroupName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue)),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                            child: const Text('本群已选', style: TextStyle(fontSize: 11, color: Colors.blue))),
                        ]),
                      ),
                      Container(height: 1, color: Colors.black12),
                      const SizedBox(height: 8),
                      ..._buildItems(_tree, 0),
                    ]),
                  )),
                ]),
    );
  }
}
