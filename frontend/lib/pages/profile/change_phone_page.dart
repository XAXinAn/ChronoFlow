import '../../widgets/chrono_input_field.dart';
import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../utils/message_utils.dart';

class ChangePhonePage extends StatefulWidget {
  final String? currentPhone;

  const ChangePhonePage({super.key, this.currentPhone});

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();
  bool _phoneFocused = false;
  bool _codeFocused = false;
  bool _isSending = false;
  int _countdown = 0;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() => _phoneFocused = _phoneFocus.hasFocus));
    _codeFocus.addListener(() => setState(() => _codeFocused = _codeFocus.hasFocus));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.isEmpty) {
      MessageUtils.show(context, '请输入手机号');
      return;
    }
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(_phoneController.text)) {
      MessageUtils.show(context, '请输入有效的手机号');
      return;
    }

    setState(() => _isSending = true);
    try {
      await AuthService().sendSms(_phoneController.text.trim());
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

  Future<void> _change() async {
    if (_phoneController.text.isEmpty) {
      MessageUtils.show(context, '请输入手机号');
      return;
    }
    if (_codeController.text.isEmpty) {
      MessageUtils.show(context, '请输入验证码');
      return;
    }

    setState(() => _isChanging = true);
    try {
      final loginResponse = await AuthService().bindPhone(
        _phoneController.text.trim(),
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
      if (mounted) setState(() => _isChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChanging = widget.currentPhone != null && widget.currentPhone!.isNotEmpty;
    final title = isChanging ? '更换手机号' : '绑定手机号';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w300)),
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
              Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w200), textAlign: TextAlign.center),
              const SizedBox(height: 64),
              ChronoInputField(controller: _phoneController, focusNode: _phoneFocus, hint: isChanging ? '新手机号' : '手机号', focused: _phoneFocused),
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
                onPressed: _isChanging ? null : _change,
                child: _isChanging
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
