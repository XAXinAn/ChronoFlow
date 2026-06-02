import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import '../../model/schedule_model.dart';
import '../../service/schedule_service.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';
import '../schedule/confirm_schedule_page.dart';
import 'join_group_confirm_page.dart';

/// 二维码扫描页面
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final ms.MobileScannerController _controller = ms.MobileScannerController(
    detectionSpeed: ms.DetectionSpeed.normal,
    facing: ms.CameraFacing.back,
    torchEnabled: false,
  );
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isProcessing = true);
      await _scanImageFile(image.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        MessageUtils.show(context, '扫描失败: $e');
      }
    }
  }

  Future<void> _scanImageFile(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final barcodeScanner = BarcodeScanner();
      final barcodes = await barcodeScanner.processImage(inputImage);
      await barcodeScanner.close();

      if (!mounted) return;

      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
        await _parseQrContent(barcodes.first.rawValue!);
      } else {
        setState(() => _isProcessing = false);
        MessageUtils.show(context, '未检测到二维码');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        MessageUtils.show(context, '扫描失败: $e');
      }
    }
  }

  Future<void> _onDetect(ms.BarcodeCapture capture) async {
    if (_isProcessing || _hasScanned) return;

    final List<ms.Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });

    // 停止扫描
    _controller.stop();

    // 尝试解析二维码内容为日程
    await _parseQrContent(code);
  }

  Future<void> _parseQrContent(String content) async {
    // 检查是否是群组邀请码（6位数字）
    final isGroupInviteCode = RegExp(r'^\d{6}$').hasMatch(content);

    if (isGroupInviteCode) {
      await _handleGroupInviteCode(content);
      return;
    }

    // 否则按日程解析
    await _parseAsSchedule(content);
  }

  Future<void> _handleGroupInviteCode(String inviteCode) async {
    // 停止扫描
    _controller.stop();

    // 跳转到确认页面
    final confirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JoinGroupConfirmPage(inviteCode: inviteCode),
      ),
    );

    if (confirmed == true) {
      Navigator.pop(context, true);
    } else {
      _resumeScanning();
    }
  }

  Future<void> _joinGroup(String inviteCode) async {
    try {
      if (mounted) {
        MessageUtils.show(context, '正在加入群组...');
      }

      final group = await GroupService().joinGroup(inviteCode);

      if (mounted) {
        if (group.pendingApproval == true) {
          MessageUtils.show(context, '已提交加群申请，请等待群主/管理员确认');
        } else {
          MessageUtils.show(context, '加入成功');
        }
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('正在等待处理')) {
          MessageUtils.show(context, '您已提交过加群申请，请等待审批');
        } else if (msg.contains('已经加入该群组')) {
          MessageUtils.show(context, '您已加入该群组');
        } else {
          MessageUtils.showError(context, e);
        }
        _resumeScanning();
      }
    }
  }

  Future<void> _parseAsSchedule(String content) async {
    try {
      // 显示解析中的提示
      if (mounted) {
        MessageUtils.show(context, '正在解析内容...');
      }

      // 调用后端API解析二维码内容
      final results = await ScheduleService().parseNotification(content);

      if (!mounted) return;

      if (results.isNotEmpty) {
        // 转换为Schedule列表并跳转到确认页面
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
          return {
            'title': r['title'] ?? '未命名日程',
            'description': r['remark'] ?? '',
            'location': r['location'] ?? '',
            'time': scheduleTime,
          };
        }).toList();

        final confirmed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmSchedulePage(
              parsedSchedules: schedules.map((s) => Schedule.create(
                title: s['title'],
                description: s['description'],
                location: s['location'],
                time: s['time'],
              )).toList(),
            ),
          ),
        );

        if (confirmed != null) {
          Navigator.pop(context, confirmed);
        } else {
          _resumeScanning();
        }
      } else {
        MessageUtils.show(context, '未解析到日程信息');
        _resumeScanning();
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.show(context, '解析失败: $e');
        _resumeScanning();
      }
    }
  }

  void _resumeScanning() {
    setState(() {
      _isProcessing = false;
      _hasScanned = false;
    });
    _controller.start();
  }

  void _toggleTorch() {
    _controller.toggleTorch();
  }

  void _switchCamera() {
    _controller.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          '扫一扫',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == ms.TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                );
              },
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: _switchCamera,
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _pickImageFromGallery,
          ),
        ],
      ),
      body: Stack(
        children: [
          ms.MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // 扫描框装饰
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: const SizedBox.expand(),
          ),
          // 提示文字
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              '将二维码放入框内扫描',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 扫描框装饰Painter
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2;

    // 绘制四个角的装饰线
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const cornerLength = 30.0;

    // 左上角
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop),
      Offset(scanAreaLeft + cornerLength, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop),
      Offset(scanAreaLeft, scanAreaTop + cornerLength),
      cornerPaint,
    );

    // 右上角
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerLength),
      cornerPaint,
    );

    // 左下角
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerLength),
      cornerPaint,
    );

    // 右下角
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
