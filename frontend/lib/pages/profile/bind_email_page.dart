import '../../widgets/chrono_input_field.dart';
import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../utils/message_utils.dart';

class BindEmailPage extends StatefulWidget {
  final String? initialEmail;

  const BindEmailPage({super.key, this.initialEmail});

  @override
  State<BindEmailPage> createState() => _BindEmailPageState();
}

class _BindEmailPageState extends State<BindEmailPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailFocus = FocusNode();
  final _codeFocus = FocusNode();
  bool _emailFocused = false;
  bool _codeFocused = false;
  bool _isSending = false;
  int _countdown = 0;
  bool _isBinding = false;

  @override
  void initState() {
    super.initState();
    // 切换邮箱时不需要预填旧邮箱，保持输入框为空让用户输入新邮箱
    _emailFocus.addListener(() => setState(() => _emailFocused = _emailFocus.hasFocus));
    _codeFocus.addListener(() => setState(() => _codeFocused = _codeFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _emailFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_emailController.text.isEmpty) {
      MessageUtils.show(context, '请输入邮箱');
      return;
    }
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(_emailController.text)) {
      MessageUtils.show(context, '请输入有效的邮箱');
      return;
    }

    setState(() => _isSending = true);
    try {
      await AuthService().sendEmail(_emailController.text.trim());
      if (!mounted) return;
      MessageUtils.show(context, '验证码已发送');
      setState(() => _countdown = 60);
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return false;
        setState(() {
          if (_countdown > 0) _countdown--;
        });
        return _countdown > 0;
      });
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _bind() async {
    if (_emailController.text.isEmpty) {
      MessageUtils.show(context, '请输入邮箱');
      return;
    }
    if (_codeController.text.isEmpty) {
      MessageUtils.show(context, '请输入验证码');
      return;
    }

    setState(() => _isBinding = true);
    try {
      final loginResponse = await AuthService().bindEmail(
        _emailController.text.trim(),
        _codeController.text.trim(),
      );
      if (!mounted) return;
      MessageUtils.show(context, '绑定成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, loginResponse);
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isBinding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChanging = widget.initialEmail != null && widget.initialEmail!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isChanging ? '更换邮箱' : '绑定邮箱', style: const TextStyle(fontWeight: FontWeight.w300)),
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
              Text(
                isChanging ? '更换邮箱' : '绑定邮箱',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w200),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              ChronoInputField(controller: _emailController, focusNode: _emailFocus, hint: '邮箱', focused: _emailFocused),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ChronoInputField(controller: _codeController, focusNode: _codeFocus, hint: '验证码', focused: _codeFocused),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: (_countdown > 0 || _isSending) ? null : _sendCode,
                    child: Text(
                      _countdown > 0 ? '${_countdown}s' : '获取验证码',
                      style: TextStyle(color: _countdown > 0 ? Colors.black38 : Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 64),
              ElevatedButton(
                onPressed: _isBinding ? null : _bind,
                child: _isBinding
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('绑定'),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

}
