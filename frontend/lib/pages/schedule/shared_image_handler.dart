import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../model/schedule_model.dart';
import '../../service/schedule_service.dart';
import '../../service/auth_service.dart';
import '../../utils/message_utils.dart';
import '../../utils/image_normalizer.dart';
import 'confirm_schedule_page.dart';
import '../login_page.dart';
import '../home_page.dart';

/// 处理从 Android 分享过来的图片页面
class SharedImageHandler extends StatefulWidget {
  final List<String>? initialImagePaths;

  const SharedImageHandler({super.key, this.initialImagePaths});

  @override
  State<SharedImageHandler> createState() => _SharedImageHandlerState();
}

class _SharedImageHandlerState extends State<SharedImageHandler> {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

  bool _isProcessing = false;
  String _statusMessage = '';
  double _progress = 0;

  StreamSubscription? _intentSubscription;

  @override
  void initState() {
    super.initState();
    _setupIntentListener();
    if (widget.initialImagePaths != null && widget.initialImagePaths!.isNotEmpty) {
      _processMultipleImages(widget.initialImagePaths!);
    }
  }

  void _setupIntentListener() {
    // 处理热启动（App已经在运行时）
    _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        _handleSharedFiles(value);
      },
      onError: (err) {
        debugPrint('Sharing intent error: $err');
      },
    );

    // 处理 App 冷启动时收到的分享
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
          _handleSharedFiles(value);
          ReceiveSharingIntent.instance.reset();
        });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty || _isProcessing) return;
    final imageFiles = files.where((f) => f.type == SharedMediaType.image).toList();
    if (imageFiles.isEmpty) return;
    _processMultipleImages(imageFiles.map((f) => f.path).toList());
  }

  Future<void> _processMultipleImages(List<String> paths) async {
    final user = AuthService.currentUser;
    if (user == null) { _showLoginRequiredDialog(); return; }
    _isProcessing = true;
    setState(() { _statusMessage = '正在识别...'; _progress = 0; });

    final allSchedules = <Schedule>[];
    for (int i = 0; i < paths.length; i++) {
      setState(() { _statusMessage = '识别中 (${i + 1}/${paths.length})'; _progress = (i + 0.5) / paths.length; });
      try {
        final jpegPath = await ImageNormalizer.toJpeg(paths[i]);
        if (jpegPath == null) continue; // 无法识别的图片，跳过（避免原生崩溃）
        final ocr = await _textRecognizer
            .processImage(InputImage.fromFilePath(jpegPath))
            .timeout(const Duration(seconds: 20));
        if (ocr.text.isEmpty) continue;
        final results = await ScheduleService().parseNotification(ocr.text);
        for (final r in results) {
          DateTime t = DateTime.now();
          final d = r['eventDate'] ?? ''; if (d.isNotEmpty) { try { t = DateTime.parse(d); } catch (_) {} }
          final tm = r['eventTime'] ?? ''; if (tm.isNotEmpty) {
            try { final p = tm.split(':'); if (p.length >= 2) t = DateTime(t.year, t.month, t.day, int.parse(p[0]), int.parse(p[1])); } catch (_) {}
          }
          allSchedules.add(Schedule.create(title: r['title'] ?? '未命名日程', description: r['remark'] ?? '', location: r['location'] ?? '', time: t));
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() { _isProcessing = false; _statusMessage = ''; _progress = 0; });

    if (allSchedules.isEmpty) {
      MessageUtils.show(context, '未检测到日程');
      Navigator.pop(context);
      return;
    }

    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => ConfirmSchedulePage(parsedSchedules: allSchedules)));
    if (!mounted) return;
    if (result != null && result is List && result.isNotEmpty) {
      final user = AuthService.currentUser;
      if (user != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(loginResponse: user)));
      }
    } else {
      MessageUtils.show(context, '保存失败，请重试');
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('需要登录'),
        content: const Text('请先登录后再处理图片识别日程'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    ReceiveSharingIntent.instance.reset();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '图片识别',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
            ] else ...[
              const Icon(Icons.image_outlined, size: 64, color: Colors.black26),
              const SizedBox(height: 16),
              const Text(
                '等待接收图片...',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}