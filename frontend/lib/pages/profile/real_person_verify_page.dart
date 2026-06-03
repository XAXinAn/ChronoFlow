import 'package:flutter/material.dart';
import '../../service/auth_service.dart';
import '../../service/real_person_service.dart';
import '../../service/face_verify_bridge.dart';
import '../../utils/message_utils.dart';

/// Real-name verification page in profile. Name+ID form → face SDK → backend confirm.
class RealPersonVerifyPage extends StatefulWidget {
  const RealPersonVerifyPage({super.key});
  @override
  State<RealPersonVerifyPage> createState() => _RealPersonVerifyPageState();
}

class _RealPersonVerifyPageState extends State<RealPersonVerifyPage> {
  final _nameCtrl = TextEditingController(), _idCtrl = TextEditingController();
  final _nameFocus = FocusNode(), _idFocus = FocusNode();
  bool _nameFocused = false, _idFocused = false, _loading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() => _nameFocused = _nameFocus.hasFocus));
    _idFocus.addListener(() => setState(() => _idFocused = _idFocus.hasFocus));
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
      // 1. Get MetaInfo
      String metaInfo = '';
      try { await FaceVerifyBridge.init(); metaInfo = await FaceVerifyBridge.getMetaInfo(); } catch (_) {}

      // 2. Backend init
      setState(() => _status = '正在初始化认证...');
      final certifyId = await RealPersonService().initVerification(metaInfo, name, idCard);

      // 3. Face SDK
      setState(() => _status = '正在进行人脸识别，请按提示操作...');
      final faceResult = await FaceVerifyBridge.verify(certifyId);
      if (faceResult['passed'] != true) {
        setState(() { _loading = false; _status = ''; });
        MessageUtils.show(context, '人脸识别未通过: ${faceResult['message'] ?? ''}');
        return;
      }

      // 4. Backend confirm
      setState(() => _status = '正在完成认证...');
      final result = await RealPersonService().getResult(certifyId);
      if (result['verified'] == true) {
        // Refresh user info
        await AuthService().refreshUserInfo();
        MessageUtils.show(context, '实名认证通过');
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() { _loading = false; _status = ''; });
        MessageUtils.show(context, result['message'] ?? '认证失败');
      }
    } catch (e) {
      setState(() { _loading = false; _status = ''; });
      if (mounted) MessageUtils.showError(context, e);
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
      appBar: AppBar(title: const Text('实人认证')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 40),
        const Text('请填写您的真实身份信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('信息仅用于身份认证，加密存储', style: TextStyle(fontSize: 13, color: Colors.black45), textAlign: TextAlign.center),
        const SizedBox(height: 48),
        TextField(controller: _nameCtrl, focusNode: _nameFocus, decoration: const InputDecoration(labelText: '真实姓名', border: OutlineInputBorder())),
        const SizedBox(height: 20),
        TextField(controller: _idCtrl, focusNode: _idFocus, keyboardType: TextInputType.number, maxLength: 18,
          decoration: const InputDecoration(labelText: '身份证号', border: OutlineInputBorder())),
        const SizedBox(height: 40),
        ElevatedButton(onPressed: _startVerify, child: const Text('开始认证'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16))),
      ])),
    );
  }
}
