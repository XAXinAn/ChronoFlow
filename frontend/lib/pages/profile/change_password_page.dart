import '../../widgets/chrono_input_field.dart';
import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../utils/message_utils.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _oldPasswordFocus = FocusNode();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  bool _oldPasswordFocused = false;
  bool _newPasswordFocused = false;
  bool _confirmPasswordFocused = false;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _oldPasswordFocus.addListener(() => setState(() => _oldPasswordFocused = _oldPasswordFocus.hasFocus));
    _newPasswordFocus.addListener(() => setState(() => _newPasswordFocused = _newPasswordFocus.hasFocus));
    _confirmPasswordFocus.addListener(() => setState(() => _confirmPasswordFocused = _confirmPasswordFocus.hasFocus));
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _oldPasswordFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_oldPasswordController.text.isEmpty) {
      MessageUtils.show(context, '请输入旧密码');
      return;
    }
    if (_newPasswordController.text.isEmpty) {
      MessageUtils.show(context, '请输入新密码');
      return;
    }
    if (_newPasswordController.text.length < 8) {
      MessageUtils.show(context, '新密码至少8位');
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(_newPasswordController.text)) {
      MessageUtils.show(context, '新密码需包含大写字母');
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(_newPasswordController.text)) {
      MessageUtils.show(context, '新密码需包含小写字母');
      return;
    }
    if (!RegExp(r'\d').hasMatch(_newPasswordController.text)) {
      MessageUtils.show(context, '新密码需包含数字');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      MessageUtils.show(context, '两次密码不一致');
      return;
    }

    setState(() => _isChanging = true);
    try {
      await AuthService().changePassword(
        _oldPasswordController.text,
        _newPasswordController.text,
      );
      if (!mounted) return;
      MessageUtils.show(context, '修改成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context);
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
        title: const Text('修改密码', style: TextStyle(fontWeight: FontWeight.w300)),
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
              const Text('修改密码', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w200), textAlign: TextAlign.center),
              const SizedBox(height: 64),
              ChronoInputField(controller: _oldPasswordController, focusNode: _oldPasswordFocus, hint: '旧密码', focused: _oldPasswordFocused, obscureText: true),
              const SizedBox(height: 24),
              ChronoInputField(controller: _newPasswordController, focusNode: _newPasswordFocus, hint: '新密码', focused: _newPasswordFocused, obscureText: true),
              const SizedBox(height: 24),
              ChronoInputField(controller: _confirmPasswordController, focusNode: _confirmPasswordFocus, hint: '确认密码', focused: _confirmPasswordFocused, obscureText: true),
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
