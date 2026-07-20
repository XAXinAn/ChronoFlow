import '../../widgets/chrono_input_field.dart';
import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

class ChangeGroupNicknamePage extends StatefulWidget {
  final String groupId;
  final String currentNickname;

  const ChangeGroupNicknamePage({
    super.key,
    required this.groupId,
    required this.currentNickname,
  });

  @override
  State<ChangeGroupNicknamePage> createState() => _ChangeGroupNicknamePageState();
}

class _ChangeGroupNicknamePageState extends State<ChangeGroupNicknamePage> {
  final _nicknameController = TextEditingController();
  final _nicknameFocus = FocusNode();
  bool _nicknameFocused = false;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.text = widget.currentNickname.isNotEmpty
        ? widget.currentNickname
        : (AuthService.currentUser?.nickname ?? '');
    _nicknameFocus.addListener(() => setState(() => _nicknameFocused = _nicknameFocus.hasFocus));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      MessageUtils.show(context, '请输入昵称');
      return;
    }
    if (nickname.length > 20) {
      MessageUtils.show(context, '昵称不能超过20个字符');
      return;
    }

    setState(() => _isChanging = true);
    try {
      final currentUser = AuthService.currentUser;
      await GroupService().updateMemberNickname(widget.groupId, currentUser!.userId, nickname);

      if (!mounted) return;
      MessageUtils.show(context, '修改成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, nickname);
    } catch (e) {
      if (mounted) {
        MessageUtils.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改群昵称', style: TextStyle(fontWeight: FontWeight.w300)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              const Text('修改群昵称', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w200), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text(
                '设置你在该群里的显示昵称',
                style: TextStyle(fontSize: 12, color: Colors.black38),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ChronoInputField(controller: _nicknameController, focusNode: _nicknameFocus, hint: '群昵称', focused: _nicknameFocused),
              const SizedBox(height: 64),
              ElevatedButton(
                onPressed: _isChanging ? null : _change,
                child: _isChanging
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('保存'),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

}
