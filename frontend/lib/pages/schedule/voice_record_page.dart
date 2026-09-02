import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../service/voice_service.dart';
import '../schedule/confirm_schedule_page.dart';
import '../../model/schedule_model.dart';
import '../../utils/message_utils.dart';

class VoiceRecordPage extends StatefulWidget {
  const VoiceRecordPage({super.key});

  @override
  State<VoiceRecordPage> createState() => _VoiceRecordPageState();
}

class _VoiceRecordPageState extends State<VoiceRecordPage> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  Duration _recordDuration = Duration.zero;
  String? _audioPath;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      MessageUtils.show(context, '需要麦克风权限');
      return;
    }

    final dir = await getTemporaryDirectory();
    _audioPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _recorder.start(RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ), path: _audioPath!);
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
      _startTimer();
    } catch (e) {
      MessageUtils.show(context, '录音启动失败');
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
        if (_recordDuration.inSeconds > 60) {
          MessageUtils.show(context, '建议录制不超过60秒');
        }
        _startTimer();
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      setState(() => _isRecording = false);
    } catch (e) {
      setState(() => _isRecording = false);
      MessageUtils.show(context, '录音停止失败');
    }
  }

  Future<void> _recognize() async {
    if (_audioPath == null) return;
    setState(() => _isProcessing = true);
    try {
      final schedules = await VoiceService().recognize(File(_audioPath!));
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
    final durationStr = '${_recordDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_recordDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('录音识别')),
      body: Center(
        child: _isProcessing
            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在识别...'),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(durationStr, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red : Colors.black87,
                      ),
                      child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_isRecording ? '点击停止' : '点击录音', style: const TextStyle(color: Colors.black54)),
                  if (!_isRecording && _audioPath != null) ...[
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _recognize,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                      child: const Text('识别日程'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}