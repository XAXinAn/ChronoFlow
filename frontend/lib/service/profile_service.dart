import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../model/chat_model.dart';
import 'api_client.dart';

/// 画像服务 — 管理六维学习画像的查看和构建。
class ProfileService {
  static String get _basePath => '/v1/profile';

  /// 获取当前用户画像
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final body = await ApiClient.get(_basePath);
      final data = jsonDecode(body);
      if (data['code'] == 200 && data['data'] != null) {
        return data['data'];
      }
    } catch (_) {}
    return null;
  }

  /// 开始画像构建对话（SSE流式）
  Stream<SseEvent> buildProfile({
    required String message,
    String? sessionId,
  }) {
    return _profileStream('$_basePath/build', message, sessionId);
  }

  /// 更新画像（SSE流式）
  Stream<SseEvent> updateProfile({
    required String message,
    String? sessionId,
  }) {
    return _profileStream('$_basePath/update', message, sessionId);
  }

  /// 通用的画像相关SSE流请求
  Stream<SseEvent> _profileStream(
    String path,
    String message,
    String? sessionId,
  ) async* {
    try {
      final token = await ApiClient.getAccessToken();
      final url = Uri.parse('${AppConstants.baseUrl}$path');

      final request = http.Request('POST', url);
      request.headers.addAll({
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      request.body = jsonEncode({
        'message': message,
        if (sessionId != null) 'sessionId': sessionId,
      });

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final stream = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in stream) {
          if (line.startsWith('data:')) {
            final data = line.substring(5).trim();
            if (data.isEmpty) continue;

            try {
              final json = jsonDecode(data);
              yield SseEvent.fromJson(json);
            } catch (_) {
              yield SseEvent(type: 'TEXT', content: data);
            }
          }
        }
      } else {
        yield SseEvent(
          type: 'ERROR',
          content: '请求失败 (${response.statusCode})',
          retryable: true,
        );
      }
      client.close();
    } catch (e) {
      yield SseEvent(
        type: 'ERROR',
        content: '连接失败: $e',
        retryable: true,
      );
    }
  }
}