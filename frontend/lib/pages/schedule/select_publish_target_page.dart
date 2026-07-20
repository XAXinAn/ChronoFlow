import '../../constants/app_constants.dart';
import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

/// Select the group to publish a schedule to (individual or group).
/// Shows groups in tree form with indentation.
class SelectPublishTargetPage extends StatefulWidget {
  const SelectPublishTargetPage({super.key});
  @override
  State<SelectPublishTargetPage> createState() => _SelectPublishTargetPageState();
}

class _SelectPublishTargetPageState extends State<SelectPublishTargetPage> {
  bool _isLoading = true;
  List<Group> _myGroups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tree = await GroupService().getMyGroupTree();
      setState(() { _myGroups = tree; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) MessageUtils.showError(context, e);
    }
  }

  List<Group> _flatFiltered() {
    final result = <Group>[];
    void collect(List<Group> groups) {
      for (final g in groups) {
        if (g.isAdminOrCreator) result.add(g);
        if (g.children != null) collect(g.children!);
      }
    }
    collect(_myGroups);
    return result;
  }

  List<Widget> _buildFlatItems(List<Group> groups) {
    return groups.map((g) => _buildItem(g, 0)).toList();
  }

  Widget _buildItem(Group group, int depth) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.pop(context, group),
          child: Container(
            padding: EdgeInsets.only(left: 16.0 + depth * 20, right: 16, top: 14, bottom: 14),
            decoration: BoxDecoration(border: Border.all(color: AppConstants.lightGray), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              if (depth > 0) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.black26)),
              Container(width: 36, height: 36, decoration: BoxDecoration(color: AppConstants.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.group, color: AppConstants.blue, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppConstants.primaryColor)),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(group.description, style: const TextStyle(fontSize: 13, color: AppConstants.mediumGray), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 2),
                Text('${group.memberCount} 人', style: const TextStyle(fontSize: 12, color: AppConstants.mediumGray)),
              ])),
              const Icon(Icons.chevron_right, color: AppConstants.mediumGray, size: 20),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor, elevation: 0, scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppConstants.primaryColor), onPressed: () => Navigator.pop(context)),
        title: const Text('选择发布到', style: TextStyle(color: AppConstants.primaryColor, fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myGroups.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.group_off, size: 64, color: Colors.black26), const SizedBox(height: 16),
                  const Text('你还没有加入任何群组', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 24), TextButton(onPressed: () => Navigator.pop(context), child: const Text('返回')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Individual option
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.pop(context, null),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(border: Border.all(color: AppConstants.lightGray), borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [
                                const Icon(Icons.person, color: AppConstants.primaryColor, size: 22),
                                const SizedBox(width: 12),
                                const Expanded(child: Text('个人日程', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppConstants.primaryColor))),
                                Icon(Icons.chevron_right, color: AppConstants.mediumGray, size: 20),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_flatFiltered().isNotEmpty) ...[
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('群组', style: TextStyle(fontSize: 13, color: AppConstants.mediumGray, fontWeight: FontWeight.w500))),
                        ..._buildFlatItems(_flatFiltered()),
                      ],
                    ],
                  ),
                ),
    );
  }
}
