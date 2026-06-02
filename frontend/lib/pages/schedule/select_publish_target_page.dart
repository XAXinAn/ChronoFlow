import '../../constants/app_constants.dart';
import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

/// 选择发布目标页面（个人/群组）
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
          '选择发布到',
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
          : RefreshIndicator(
              onRefresh: _loadMyGroups,
              child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 个人日程
                _buildTargetItem(
                  icon: Icons.person,
                  iconColor: AppConstants.primaryColor,
                  title: '个人日程',
                  titleColor: AppConstants.primaryColor,
                  onTap: () => Navigator.pop(context, null),
                ),
                const SizedBox(height: 8),
                if (_myGroups.where((g) => g.isAdminOrCreator).isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '群组',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppConstants.mediumGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 群组列表（只显示我是群主/管理员的群组）
                  ..._myGroups.where((g) => g.isAdminOrCreator).map((group) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildTargetItem(
                      icon: Icons.group,
                      iconColor: AppConstants.blue,
                      title: group.name,
                      titleColor: AppConstants.blue,
                      onTap: () => Navigator.pop(context, group),
                    ),
                  )),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildTargetItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppConstants.lightGray),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: titleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppConstants.mediumGray, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}