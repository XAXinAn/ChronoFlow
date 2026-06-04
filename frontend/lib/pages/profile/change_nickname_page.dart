import '../../widgets/chrono_input_field.dart';
import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../utils/message_utils.dart';

class ChangeNicknamePage extends StatefulWidget {
  final String currentNickname;

  const ChangeNicknamePage({super.key, required this.currentNickname});

  @override
  State<ChangeNicknamePage> createState() => _ChangeNicknamePageState();
}

class _ChangeNicknamePageState extends State<ChangeNicknamePage> {
  final _nicknameController = TextEditingController();
  final _nicknameFocus = FocusNode();
  bool _nicknameFocused = false;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _nicknameFocus.addListener(() => setState(() => _nicknameFocused = _nicknameFocus.hasFocus));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_nicknameController.text.isEmpty) {
      MessageUtils.show(context, '请输入昵称');
      return;
    }
    if (_nicknameController.text.length < 2 || _nicknameController.text.length > 20) {
      MessageUtils.show(context, '昵称长度需在2-20个字符之间');
      return;
    }

    setState(() => _isChanging = true);
    try {
      final loginResponse = await AuthService().updateNickname(_nicknameController.text.trim());
      if (!mounted) return;
      MessageUtils.show(context, '修改成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, loginResponse);
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改昵称', style: TextStyle(fontWeight: FontWeight.w300)),
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
              const Text(
                '昵称30天只能修改一次',
                style: TextStyle(fontSize: 12, color: Colors.black38),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ChronoInputField(controller: _nicknameController, focusNode: _nicknameFocus, hint: '新昵称', focused: _nicknameFocused),
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