import 'package:flutter/material.dart';
import '../../widgets/chrono_input_field.dart';
import '../../service/auth_service.dart';
import '../../service/real_person_service.dart';
import '../../service/face_verify_bridge.dart';
import '../../utils/message_utils.dart';

/// Real-name verification page. Two modes:
/// - Registration flow: receives {phone, code, username, password} as arguments
/// - Profile flow: no arguments, calls /api/user/real-person-verify
class RealPersonVerifyPage extends StatefulWidget {
  const RealPersonVerifyPage({super.key});
  @override
  State<RealPersonVerifyPage> createState() => _RealPersonVerifyPageState();
}

class _RealPersonVerifyPageState extends State<RealPersonVerifyPage> {
  final _nameCtrl = TextEditingController(), _idCtrl = TextEditingController();
  final _nameFocus = FocusNode(), _idFocus = FocusNode();
  bool _loading = false;
  String _status = '';
  bool _isRegistration = false;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    _idFocus.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    _isRegistration = args is Map && args.containsKey('phone');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _idCtrl.dispose(); _nameFocus.dispose(); _idFocus.dispose();
    super.dispose();
  }

  Future<void> _startVerify() async {
    final name = _nameCtrl.text.trim(), idCard = _idCtrl.text.trim();
    if (name.length < 2) { MessageUtils.show(context, '请输入正确的姓名'); return; }
    if (!RegExp(r'^\d{17}[\dXx]$').hasMatch(idCard)) { MessageUtils.show(context, '请输入正确的18位身份证号'); return; }

    setState(() { _loading = true; _status = '正在获取设备信息...'; });
    try {
      String metaInfo = '';
      try { await FaceVerifyBridge.init(); metaInfo = await FaceVerifyBridge.getMetaInfo(); } catch (_) {}

      if (_isRegistration) {
        await _registrationFlow(name, idCard, metaInfo);
      } else {
        await _profileFlow(name, idCard, metaInfo);
      }
    } catch (e) {
      setState(() { _loading = false; _status = ''; });
      if (mounted) MessageUtils.showError(context, e);
    }
  }

  Future<void> _registrationFlow(String name, String idCard, String metaInfo) async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    setState(() => _status = '正在初始化认证...');
    final authService = AuthService();
    final certifyId = await authService.registerInit(
      username: args['username'], phone: args['phone'],
      code: args['code'], password: args['password'],
      metaInfo: metaInfo, realName: name, idCardNumber: idCard,
    );

    setState(() => _status = '正在进行人脸识别，请按提示操作...');
    final faceResult = await FaceVerifyBridge.verify(certifyId);
    if (faceResult['passed'] != true) {
      setState(() { _loading = false; _status = ''; });
      MessageUtils.show(context, '人脸识别未通过');
      return;
    }

    setState(() => _status = '正在完成注册...');
    await authService.registerConfirm(certifyId);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _profileFlow(String name, String idCard, String metaInfo) async {
    setState(() => _status = '正在初始化认证...');
    final rps = RealPersonService();
    final certifyId = await rps.initVerification(metaInfo, name, idCard);

    setState(() => _status = '正在进行人脸识别，请按提示操作...');
    final faceResult = await FaceVerifyBridge.verify(certifyId);
    if (faceResult['passed'] != true) {
      setState(() { _loading = false; _status = ''; });
      MessageUtils.show(context, '人脸识别未通过');
      return;
    }

    setState(() => _status = '正在完成认证...');
    final result = await rps.getResult(certifyId);
    if (result['verified'] == true) {
      MessageUtils.show(context, '实名认证通过');
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() { _loading = false; _status = ''; });
      MessageUtils.show(context, result['message'] ?? '认证失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(), const SizedBox(height: 24),
        Text(_status, style: const TextStyle(fontSize: 16, color: Colors.black54)),
      ])));
    }
    return Scaffold(
      appBar: AppBar(title: Text(_isRegistration ? '实名认证 - 完成注册' : '实人认证')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
        const SizedBox(height: 40),
        Text(_isRegistration ? '最后一步：请完成实名认证' : '请填写真实身份信息',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('信息仅用于身份认证，加密存储', style: TextStyle(fontSize: 13, color: Colors.black45), textAlign: TextAlign.center),
        const SizedBox(height: 48),
        ChronoInputField(controller: _nameCtrl, focusNode: _nameFocus, hint: '真实姓名', focused: _nameFocus.hasFocus),
        const SizedBox(height: 24),
        ChronoInputField(controller: _idCtrl, focusNode: _idFocus, hint: '身份证号', focused: _idFocus.hasFocus),
        const SizedBox(height: 40),
        ElevatedButton(onPressed: _startVerify,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), minimumSize: const Size(double.infinity, 56)),
          child: const Text('开始认证', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
      ])),
    );
  }
}
