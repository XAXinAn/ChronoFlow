import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../service/auth_service.dart';
import '../login_page.dart';
import '../home_page.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/user_agreement_page.dart';
import '../schedule/shared_image_handler.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _isLoading = true;
  static const String _privacyAcceptedKey = 'privacy_accepted';
  String? _sharedImagePath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await AuthService.loadStoredAuth();
    if (!mounted) return;

    // Check for shared image on cold start
    final sharedFiles = await ReceiveSharingIntent.instance.getInitialMedia();
    if (sharedFiles.isNotEmpty) {
      final imageFiles = sharedFiles.where((f) => f.type == SharedMediaType.image).toList();
      if (imageFiles.isNotEmpty) {
        _sharedImagePath = imageFiles.first.path;
      }
    }

    final accepted = await _checkPrivacyAccepted();
    if (!accepted) {
      _showPrivacyDialog();
    } else {
      _continueToApp();
    }
  }

  Future<bool> _checkPrivacyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_privacyAcceptedKey) ?? false;
  }

  Future<void> _savePrivacyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyAcceptedKey, true);
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/AppIcons/android/mipmap-xhdpi/ic_launcher.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.schedule,
                          size: 36,
                          color: Colors.white,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '隐私政策与用户协议',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
                    children: [
                      const TextSpan(text: '欢迎您使用时纪流！\n\n在您使用我们的服务之前，请阅读并同意以下内容：'),
                      TextSpan(
                        text: '《隐私政策》',
                        style: const TextStyle(fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = () => _showFullPolicy('privacy'),
                      ),
                      const TextSpan(text: '说明我们如何收集、使用和保护您的个人信息，'),
                      TextSpan(
                        text: '《用户协议》',
                        style: const TextStyle(fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = () => _showFullPolicy('agreement'),
                      ),
                      const TextSpan(text: '说明您使用本应用的服务条款和规则。\n\n如您同意，请点击"同意"按钮继续使用。'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _savePrivacyAccepted();
                      Navigator.pop(context);
                      _continueToApp();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '同意',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('提示'),
                        content: const Text('您需要同意隐私政策和用户协议才能使用本应用。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('返回'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              SystemNavigator.pop();
                            },
                            child: const Text('退出'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    '不同意',
                    style: TextStyle(
                      color: Colors.black38,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullPolicy(String type) {
    Navigator.pop(context);
    if (type == 'privacy') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
      ).then((_) {
        if (mounted) {
          _showPrivacyDialog();
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserAgreementPage()),
      ).then((_) {
        if (mounted) {
          _showPrivacyDialog();
        }
      });
    }
  }

  void _continueToApp() {
    if (!mounted) return;

    setState(() => _isLoading = false);

    // If there's a shared image, go to SharedImageHandler
    if (_sharedImagePath != null) {
      ReceiveSharingIntent.instance.reset();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SharedImageHandler(initialImagePath: _sharedImagePath),
        ),
      );
      return;
    }

    final user = AuthService.currentUser;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => user != null
            ? HomePage(loginResponse: user)
            : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212221),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/AppIcons/android/mipmap-xhdpi/ic_launcher.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        size: 50,
                        color: Color(0xFF212221),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}