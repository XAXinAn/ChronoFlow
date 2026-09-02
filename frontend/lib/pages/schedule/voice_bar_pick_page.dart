import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../service/voice_service.dart';
import '../schedule/confirm_schedule_page.dart';
import '../../utils/message_utils.dart';

class VoiceBarPickPage extends StatefulWidget {
  const VoiceBarPickPage({super.key});

  @override
  State<VoiceBarPickPage> createState() => _VoiceBarPickPageState();
}

class _VoiceBarPickPageState extends State<VoiceBarPickPage> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _pickAndRecognize();
  }

  Future<void> _pickAndRecognize() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final schedules = await VoiceService().recognize(File(result.files.single.path!));
      if (!mounted) return;
      if (schedules.isEmpty) {
        MessageUtils.show(context, '未识别到有效语音内容');
        setState(() => _isProcessing = false);
        return;
      }
      final confirmed = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConfirmSchedulePage(parsedSchedules: schedules)),
      );
      if (mounted && confirmed != null) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) MessageUtils.show(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('语音条识别')),
      body: Center(
        child: _isProcessing
            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在识别...'),
              ])
            : const SizedBox.shrink(),
      ),
    );
  }
}
