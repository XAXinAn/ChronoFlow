import '../widgets/chrono_input_field.dart';
import 'package:flutter/material.dart';
import '../service/auth_service.dart';
import '../utils/message_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 账号登录
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _usernameFocused = false;
  bool _passwordFocused = false;

  // 短信登录
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _smsCodeFocus = FocusNode();
  bool _phoneFocused = false;
  bool _smsCodeFocused = false;
  bool _isSendingSms = false;
  int _smsCountdown = 0;

  // 邮箱登录
  final _emailController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _emailFocus = FocusNode();
  final _emailCodeFocus = FocusNode();
  bool _emailFocused = false;
  bool _emailCodeFocused = false;
  bool _isSendingEmail = false;
  int _emailCountdown = 0;

  bool _isLoading = false;
  bool _privacyCheckedAccount = false;
  bool _privacyCheckedSms = false;
  bool _privacyCheckedEmail = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _usernameFocus.addListener(() => setState(() => _usernameFocused = _usernameFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));
    _phoneFocus.addListener(() => setState(() => _phoneFocused = _phoneFocus.hasFocus));
    _smsCodeFocus.addListener(() => setState(() => _smsCodeFocused = _smsCodeFocus.hasFocus));
    _emailFocus.addListener(() => setState(() => _emailFocused = _emailFocus.hasFocus));
    _emailCodeFocus.addListener(() => setState(() => _emailCodeFocused = _emailCodeFocus.hasFocus));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    _phoneFocus.dispose();
    _smsCodeFocus.dispose();
    _emailController.dispose();
    _emailCodeController.dispose();
    _emailFocus.dispose();
    _emailCodeFocus.dispose();
    super.dispose();
  }

  // 账号登录
  Future<void> _login() async {
    if (_usernameController.text.isEmpty) {
      _showMessage('请输入用户名');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showMessage('请输入密码');
      return;
    }
    if (!_privacyCheckedAccount) {
      _showMessage('请阅读并同意隐私政策和用户协议');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final response = await authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      // 检查是否需要风控验证
      if (response.isRiskRequired) {
        _showRiskVerifyDialog(response);
        return;
      }

      _showMessage('登录成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home', arguments: response);
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 显示风控验证对话框
  void _showRiskVerifyDialog(dynamic response) {
    final riskType = response.riskType; // 'sms' 或 'email'
    final riskToken = response.riskToken;
    final phone = response.phone;
    final email = response.email;

    String verifyHint = '';
    if (riskType == 'sms') {
      verifyHint = '短信';
    } else if (riskType == 'email') {
      verifyHint = '邮箱';
    }

    final codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$verifyHint验证码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请输入发送到${riskType == 'sms' ? '手机 $phone' : '邮箱 $email'}的验证码'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: '请输入6位验证码',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              codeController.dispose();
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty || code.length != 6) {
                _showMessage('请输入6位验证码');
                return;
              }
              codeController.dispose();
              Navigator.of(context).pop();
              await _performRiskVerify(riskToken, code);
            },
            child: const Text('验证'),
          ),
        ],
      ),
    );
  }

  // 执行风控验证
  Future<void> _performRiskVerify(String riskToken, String code) async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final response = await authService.riskVerify(riskToken, code);

      if (!mounted) return;
      _showMessage('登录成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home', arguments: response);
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 发送短信验证码
  Future<void> _sendSmsCode() async {
    if (_phoneController.text.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(_phoneController.text)) {
      _showMessage('请输入有效的手机号');
      return;
    }

    setState(() => _isSendingSms = true);

    try {
      final authService = AuthService();
      await authService.sendSms(_phoneController.text.trim());
      if (!mounted) return;
      _showMessage('验证码已发送');
      setState(() {
        _smsCountdown = 60;
      });
      _startSmsCountdown();
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSendingSms = false);
    }
  }

  void _startSmsCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_smsCountdown > 0) {
          _smsCountdown--;
        }
      });
      return _smsCountdown > 0;
    });
  }

  // 短信登录
  Future<void> _smsLogin() async {
    if (_phoneController.text.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }
    if (_smsCodeController.text.isEmpty) {
      _showMessage('请输入验证码');
      return;
    }
    if (!_privacyCheckedSms) {
      _showMessage('请阅读并同意隐私政策和用户协议');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final response = await authService.smsLogin(
        _phoneController.text.trim(),
        _smsCodeController.text.trim(),
      );

      if (!mounted) return;
      if (response == null) {
        _showMessage('验证码错误');
        return;
      }
      _showMessage('登录成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home', arguments: response);
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 发送邮箱验证码
  Future<void> _sendEmailCode() async {
    if (_emailController.text.isEmpty) {
      _showMessage('请输入邮箱');
      return;
    }
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(_emailController.text)) {
      _showMessage('请输入有效的邮箱');
      return;
    }

    setState(() => _isSendingEmail = true);

    try {
      final authService = AuthService();
      await authService.sendEmail(_emailController.text.trim());
      if (!mounted) return;
      _showMessage('验证码已发送');
      setState(() {
        _emailCountdown = 60;
      });
      _startEmailCountdown();
    } catch (e) {
      MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  void _startEmailCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_emailCountdown > 0) {
          _emailCountdown--;
        }
      });
      return _emailCountdown > 0;
    });
  }

  // 邮箱登录
  Future<void> _emailLogin() async {
    if (_emailController.text.isEmpty) {
      _showMessage('请输入邮箱');
      return;
    }
    if (_emailCodeController.text.isEmpty) {
      _showMessage('请输入验证码');
      return;
    }
    if (!_privacyCheckedEmail) {
      _showMessage('请阅读并同意隐私政策和用户协议');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final response = await authService.emailLogin(
        _emailController.text.trim(),
        _emailCodeController.text.trim(),
      );

      if (!mounted) return;
      if (response == null) {
        _showMessage('验证码错误');
        return;
      }
      _showMessage('登录成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home', arguments: response);
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
        title: const Text('登录', style: TextStyle(fontWeight: FontWeight.w300)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black38,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '账号'),
            Tab(text: '手机号'),
            Tab(text: '邮箱'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 账号登录
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),
                  const Text('账号登录', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w200), textAlign: TextAlign.center),
                  const SizedBox(height: 64),
                  ChronoInputField(controller: _usernameController, focusNode: _usernameFocus, hint: '用户名', focused: _usernameFocused),
                  const SizedBox(height: 40),
                  ChronoInputField(controller: _passwordController, focusNode: _passwordFocus, hint: '密码', focused: _passwordFocused, obscureText: true),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _privacyCheckedAccount = !_privacyCheckedAccount),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  border: Border.all(color: _privacyCheckedAccount ? Colors.black : Colors.black38),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: _privacyCheckedAccount
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('登录'),
                  ),
                  const SizedBox(height: 32),
                  TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('没有账号？去注册')),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          // 短信登录
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),
                  const Text('手机号登录', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w200), textAlign: TextAlign.center),
                  const SizedBox(height: 64),
                  ChronoInputField(controller: _phoneController, focusNode: _phoneFocus, hint: '手机号', focused: _phoneFocused),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ChronoInputField(controller: _smsCodeController, focusNode: _smsCodeFocus, hint: '验证码', focused: _smsCodeFocused),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: (_smsCountdown > 0 || _isSendingSms) ? null : _sendSmsCode,
                        child: Text(
                          _smsCountdown > 0 ? '${_smsCountdown}s' : '获取验证码',
                          style: TextStyle(color: _smsCountdown > 0 ? Colors.black38 : Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _privacyCheckedSms = !_privacyCheckedSms),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  border: Border.all(color: _privacyCheckedSms ? Colors.black : Colors.black38),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: _privacyCheckedSms
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _smsLogin,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('登录'),
                  ),
                  const SizedBox(height: 32),
                  TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('没有账号？去注册')),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          // 邮箱登录
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),
                  const Text('邮箱登录', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w200), textAlign: TextAlign.center),
                  const SizedBox(height: 64),
                  ChronoInputField(controller: _emailController, focusNode: _emailFocus, hint: '邮箱', focused: _emailFocused),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ChronoInputField(controller: _emailCodeController, focusNode: _emailCodeFocus, hint: '验证码', focused: _emailCodeFocused),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: (_emailCountdown > 0 || _isSendingEmail) ? null : _sendEmailCode,
                        child: Text(
                          _emailCountdown > 0 ? '${_emailCountdown}s' : '获取验证码',
                          style: TextStyle(color: _emailCountdown > 0 ? Colors.black38 : Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _privacyCheckedEmail = !_privacyCheckedEmail),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  border: Border.all(color: _privacyCheckedEmail ? Colors.black : Colors.black38),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: _privacyCheckedEmail
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _emailLogin,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('登录'),
                  ),
                  const SizedBox(height: 32),
                  TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('没有账号？去注册')),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
