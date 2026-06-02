import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../model/schedule_model.dart';
import '../../service/schedule_service.dart';
import '../../service/auth_service.dart';
import '../../utils/message_utils.dart';
import 'confirm_schedule_page.dart';
import '../login_page.dart';
import '../home_page.dart';

/// 处理从 Android 分享过来的图片页面
class SharedImageHandler extends StatefulWidget {
  final String? initialImagePath;

  const SharedImageHandler({super.key, this.initialImagePath});

  @override
  State<SharedImageHandler> createState() => _SharedImageHandlerState();
}

class _SharedImageHandlerState extends State<SharedImageHandler> {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

  bool _isProcessing = false;
  String _statusMessage = '';
  double _progress = 0;

  StreamSubscription? _intentSubscription;
  String? _pendingImagePath;

  @override
  void initState() {
    super.initState();
    _setupIntentListener();
    if (widget.initialImagePath != null) {
      _pendingImagePath = widget.initialImagePath;
      _processImage(widget.initialImagePath!);
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
    if (files.isEmpty) return;

    // 只处理图片
    final imageFiles = files.where((f) => f.type == SharedMediaType.image).toList();
    if (imageFiles.isEmpty) return;

    final path = imageFiles.first.path;
    if (_pendingImagePath != path) {
      _pendingImagePath = path;
      _processImage(path);
    }
  }

  Future<void> _processImage(String path) async {
    // 检查是否已登录
    final user = AuthService.currentUser;
    if (user == null) {
      // 未登录，先跳转到登录页面
      _showLoginRequiredDialog();
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '正在识别文字...';
      _progress = 0.3;
    });

    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final ocrResult = recognizedText.text;

      if (ocrResult.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
          _progress = 0;
        });
        if (mounted) {
          MessageUtils.show(context, '未检测到文字，请换一张图片试试');
        }
        return;
      }

      setState(() {
        _statusMessage = '正在解析日程...';
        _progress = 0.7;
      });

      final results = await ScheduleService().parseNotification(ocrResult);

      setState(() {
        _isProcessing = false;
        _statusMessage = '';
        _progress = 0;
      });

      if (!mounted) return;

      if (results.isNotEmpty) {
        final schedules = results.map((r) {
          final dateStr = r['eventDate'] ?? '';
          final timeStr = r['eventTime'] ?? '';
          DateTime scheduleTime = DateTime.now();
          if (dateStr.isNotEmpty) {
            try {
              scheduleTime = DateTime.parse(dateStr);
            } catch (_) {}
          }
          if (timeStr.isNotEmpty) {
            try {
              final parts = timeStr.split(':');
              if (parts.length >= 2) {
                scheduleTime = DateTime(
                  scheduleTime.year,
                  scheduleTime.month,
                  scheduleTime.day,
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                );
              }
            } catch (_) {}
          }
          return Schedule.create(
            title: r['title'] ?? '未命名日程',
            description: r['remark'] ?? '',
            location: r['location'] ?? '',
            time: scheduleTime,
          );
        }).toList();

        // 直接 push，不等待结果，让 ConfirmSchedulePage 内部处理保存和返回
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmSchedulePage(
              parsedSchedules: schedules,
            ),
          ),
        ).then((_) {
          // ConfirmSchedulePage 保存完成后会 pop 回来，然后直接跳首页
          if (mounted) {
            final user = AuthService.currentUser;
            if (user != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => HomePage(loginResponse: user),
                ),
              );
            }
          }
        });
      } else {
        MessageUtils.show(context, '未解析到日程信息');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
        _progress = 0;
      });
      if (mounted) {
        MessageUtils.show(context, '解析失败: $e');
        Navigator.pop(context);
      }
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