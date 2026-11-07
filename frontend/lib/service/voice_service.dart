import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../model/schedule_model.dart';

class VoiceService {
  static const _baseUrl = '/voice/recognize';
  static const _storage = FlutterSecureStorage();

  Future<List<Schedule>> recognize(File audioFile) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('未登录，请先登录');

    final uri = Uri.parse('${AppConstants.baseUrl}$_baseUrl');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('语音识别超时，请稍后重试'),
    );
    final response = await http.Response.fromStream(streamedResponse);
    final data = json.decode(response.body);

    if (data['code'] == 200) {
      final List<dynamic> list = data['data'] ?? [];
      return list.map((r) => _parseToSchedule(r as Map<String, dynamic>)).toList();
    }
    throw Exception(data['message'] ?? '语音识别失败');
  }

  Schedule _parseToSchedule(Map<String, dynamic> r) {
    String eventDate = r['eventDate'] ?? '';
    String eventTime = r['eventTime'] ?? '';
    DateTime scheduleTime = DateTime.now();
    if (eventDate.isNotEmpty && eventTime.isNotEmpty) {
      scheduleTime = DateTime.tryParse('$eventDate $eventTime:00') ?? DateTime.now();
    } else if (eventDate.isNotEmpty) {
      scheduleTime = DateTime.tryParse(eventDate) ?? DateTime.now();
    }
    return Schedule.create(
      title: r['title'] ?? '未命名日程',
      description: r['remark'] ?? '',
      location: r['location'] ?? '',
      time: scheduleTime,
    );
  }
}