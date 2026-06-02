import '../../widgets/chrono_input_field.dart';
import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../utils/message_utils.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();

  final _usernameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _codeFocus = FocusNode();

  bool _usernameFocused = false;
  bool _phoneFocused = false;
  bool _passwordFocused = false;
  bool _confirmPasswordFocused = false;
  bool _codeFocused = false;
  bool _isSendingCode = false;
  int _codeCountdown = 0;

  bool _isLoading = false;
  bool _privacyChecked = false;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(() => setState(() => _usernameFocused = _usernameFocus.hasFocus));
    _phoneFocus.addListener(() => setState(() => _phoneFocused = _phoneFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));
    _confirmPasswordFocus.addListener(() => setState(() => _confirmPasswordFocused = _confirmPasswordFocus.hasFocus));
    _codeFocus.addListener(() => setState(() => _codeFocused = _codeFocus.hasFocus));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _usernameFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(_phoneController.text)) {
      _showMessage('请输入有效的手机号');
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final authService = AuthService();
      await authService.sendSms(_phoneController.text.trim());
      if (!mounted) return;
      _showMessage('验证码已发送');
      setState(() {
        _codeCountdown = 60;
      });
      _startCountdown();
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_codeCountdown > 0) {
          _codeCountdown--;
        }
      });
      return _codeCountdown > 0;
    });
  }

  Future<void> _register() async {
    if (!_privacyChecked) {
      _showMessage('请阅读并同意隐私政策和用户协议');
      return;
    }
    if (_usernameController.text.isEmpty) {
      _showMessage('请输入用户名');
      return;
    }
    if (_usernameController.text.length < 3) {
      _showMessage('用户名至少3位');
      return;
    }
    if (_phoneController.text.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(_phoneController.text)) {
      _showMessage('请输入有效的手机号');
      return;
    }
    if (_codeController.text.isEmpty) {
      _showMessage('请输入验证码');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showMessage('请输入密码');
      return;
    }
    if (_passwordController.text.length < 8) {
      _showMessage('密码至少8位');
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(_passwordController.text)) {
      _showMessage('密码需包含大写字母');
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(_passwordController.text)) {
      _showMessage('密码需包含小写字母');
      return;
    }
    if (!RegExp(r'\d').hasMatch(_passwordController.text)) {
      _showMessage('密码需包含数字');
      return;
    }
    if (_confirmPasswordController.text.isEmpty) {
      _showMessage('请确认密码');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage('两次密码不一致');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      await authService.register(
        _usernameController.text.trim(),
        _phoneController.text.trim(),
        _codeController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      _showMessage('注册成功');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14, decoration: TextDecoration.none, decorationColor: Colors.transparent)),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('注册', style: TextStyle(fontWeight: FontWeight.w300)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Text('创建账号', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w200), textAlign: TextAlign.center),
              const SizedBox(height: 48),
              ChronoInputField(controller: _usernameController, focusNode: _usernameFocus, hint: '用户名（注册后不可修改）', focused: _usernameFocused),
              const SizedBox(height: 24),
              ChronoInputField(controller: _phoneController, focusNode: _phoneFocus, hint: '手机号', focused: _phoneFocused),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ChronoInputField(controller: _codeController, focusNode: _codeFocus, hint: '验证码', focused: _codeFocused),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: (_codeCountdown > 0 || _isSendingCode) ? null : _sendCode,
                    child: Text(
                      _codeCountdown > 0 ? '${_codeCountdown}s' : '获取验证码',
                      style: TextStyle(color: _codeCountdown > 0 ? Colors.black38 : Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ChronoInputField(controller: _passwordController, focusNode: _passwordFocus, hint: '密码', focused: _passwordFocused, obscureText: true),
              const SizedBox(height: 24),
              ChronoInputField(controller: _confirmPasswordController, focusNode: _confirmPasswordFocus, hint: '确认密码', focused: _confirmPasswordFocused, obscureText: true),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _privacyChecked = !_privacyChecked),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border.all(color: _privacyChecked ? Colors.black : Colors.black38),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _privacyChecked
                                ? const Icon(Icons.check, size: 16, color: Colors.black)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                                children: [
                                  const TextSpan(text: '我已阅读并同意'),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () => Navigator.pushNamed(context, '/privacy-policy'),
                                      child: const Text('《隐私政策》', style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const TextSpan(text: '和'),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () => Navigator.pushNamed(context, '/user-agreement'),
                                      child: const Text('《用户协议》', style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('注册'),
              ),
              const SizedBox(height: 32),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('已有账号？去登录')),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

}
