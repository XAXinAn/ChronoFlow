import '../../constants/app_constants.dart';
import 'package:flutter/material.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

/// 加入群组页面 - 黑白极简风格
class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key});

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final _codeController = TextEditingController();
  final _groupService = GroupService();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_codeController.text.trim().isEmpty) {
      MessageUtils.show(context, '请输入邀请码');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final group = await _groupService.joinGroup(_codeController.text.trim());
      _isLoading = false;

      if (mounted) {
        if (group.pendingApproval == true) {
          MessageUtils.show(context, '已提交加群申请，请等待群主/管理员确认');
        } else {
          MessageUtils.show(context, '加入成功');
        }
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
          '加入群组',
          style: TextStyle(
            color: AppConstants.primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _join,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : const Text(
                    '加入',
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

          // 邀请码
          _buildTextField(
            controller: _codeController,
            hintText: '邀请码',
            hintColor: AppConstants.mediumGray,
            textColor: AppConstants.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),

          const SizedBox(height: 16),

          const Text(
            '请输入群组邀请码加入群组',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black45,
            ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: fontWeight),
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
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
