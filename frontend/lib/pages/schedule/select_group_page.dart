import '../../constants/app_constants.dart';
import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

/// 群组选择页面
class SelectGroupPage extends StatefulWidget {
  const SelectGroupPage({super.key});

  @override
  State<SelectGroupPage> createState() => _SelectGroupPageState();
}

class _SelectGroupPageState extends State<SelectGroupPage> {
  bool _isLoading = true;
  List<Group> _myGroups = [];


  @override
  void initState() {
    super.initState();
    _loadMyGroups();
  }

  Future<void> _loadMyGroups() async {
    try {
      final groups = await GroupService().getMyGroups();
      setState(() {
        _myGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        MessageUtils.show(context, '获取群组列表失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppConstants.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '选择群组',
          style: TextStyle(
            color: AppConstants.primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group_off, size: 64, color: Colors.black26),
                      const SizedBox(height: 16),
                      const Text(
                        '你还没有加入任何群组',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _myGroups.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final group = _myGroups[index];
                    return _buildGroupItem(group);
                  },
                ),
    );
  }

  Widget _buildGroupItem(Group group) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.pop(context, group),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppConstants.lightGray),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppConstants.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.group, color: AppConstants.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    if (group.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppConstants.mediumGray,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppConstants.mediumGray, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}