import '../../constants/app_constants.dart';
import 'package:flutter/material.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

/// 创建群组页面 - 黑白极简风格
class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _groupService = GroupService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) {
      MessageUtils.show(context, '请输入群组名称');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final group = await _groupService.createGroup(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
      );
      _isLoading = false;

      if (mounted) {
        MessageUtils.show(context, '创建成功');
        Navigator.pop(context, group);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        MessageUtils.showError(context, e);
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
          icon: const Icon(Icons.close, color: AppConstants.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '创建群组',
          style: TextStyle(
            color: AppConstants.primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _create,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : const Text(
                    '创建',
                    style: TextStyle(
                      color: AppConstants.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 40),

          // 群组名称
          _buildTextField(
            controller: _nameController,
            hintText: '群组名称',
            hintColor: AppConstants.mediumGray,
            textColor: AppConstants.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),

          const SizedBox(height: 32),

          // 群组描述
          _buildTextField(
            controller: _descController,
            hintText: '群组描述（选填）',
            hintColor: AppConstants.mediumGray,
            textColor: AppConstants.darkGray,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            maxLines: 3,
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  /// 文本输入框 - 透明背景，仅底部1px细线
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Color hintColor,
    required Color textColor,
    required double fontSize,
    required FontWeight fontWeight,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: fontWeight),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor, fontSize: fontSize, fontWeight: fontWeight),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppConstants.primaryColor, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        Container(height: 0.5, color: AppConstants.lightGray),
      ],
    );
  }
}
