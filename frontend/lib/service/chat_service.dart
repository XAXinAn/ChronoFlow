import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../model/chat_model.dart';
import 'api_client.dart';

/// 对话服务 — 管理会话创建、消息发送、SSE流式连接。
///
/// 核心职责：
/// - 会话CRUD（创建、列表、消息历史）
/// - SSE流式消息接收与事件解析
/// - 流状态管理（StreamController + 自动重连）
class ChatService {
  static String get _basePath => '/v1/chat';

  /// 获取会话列表
  Future<List<ChatSession>> getSessions() async {
    final body = await ApiClient.get('$_basePath/sessions');
    final data = jsonDecode(body);
    if (data['code'] == 200 && data['data'] != null) {
      return (data['data'] as List)
          .map((e) => ChatSession.fromJson(e))
          .toList();
    }
    return [];
  }

  /// 创建新会话
  Future<ChatSession> createSession() async {
    final body = await ApiClient.post('$_basePath/session');
    final data = jsonDecode(body);
    return ChatSession.fromJson(data['data']);
  }

  /// 获取会话消息历史
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final body = await ApiClient.get('$_basePath/session/$sessionId/messages');
    final data = jsonDecode(body);
    if (data['code'] == 200 && data['data'] != null) {
      return (data['data'] as List)
          .map((e) => ChatMessage.fromJson(e))
          .toList();
    }
    return [];
  }

  /// 发送消息（SSE流式）— 核心方法。
  ///
  /// 返回一个 Stream<SseEvent>，调用方通过 StreamBuilder 订阅并逐事件渲染。
  /// 发送新消息时自动cancel当前SSE连接（通过 StreamController 管理）。
  StreamController<SseEvent>? _currentController;

  /// 取消当前SSE连接
  void cancelCurrentStream() {
    _currentController?.close();
    _currentController = null;
  }

  /// 发送消息并返回SSE事件流。
  /// [sessionId] 为空时自动创建新会话。
  /// [onSessionCreated] 会话创建后的回调，用于更新ChatPage状态。
  Stream<SseEvent> sendMessage({
    required String message,
    String? sessionId,
    void Function(String sessionId)? onSessionCreated,
  }) {
    // 取消旧连接
    cancelCurrentStream();

    final controller = StreamController<SseEvent>();
    _currentController = controller;

    _doSendMessage(
      message: message,
      sessionId: sessionId,
      controller: controller,
      onSessionCreated: onSessionCreated,
    );

    return controller.stream;
  }

  Future<void> _doSendMessage({
    required String message,
    String? sessionId,
    required StreamController<SseEvent> controller,
    void Function(String sessionId)? onSessionCreated,
  }) async {
    http.Client? client;
    bool receivedData = false;
    try {
      final token = await ApiClient.getAccessToken();
      final url = Uri.parse('${AppConstants.baseUrl}$_basePath/message');

      final request = http.Request('POST', url);
      request.headers.addAll({
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      request.body = jsonEncode({
        'message': message,
        if (sessionId != null) 'sessionId': sessionId,
      });

      client = http.Client();
      final response = await client.send(request);

      if (response.statusCode == 401) {
        // Token过期，尝试刷新
        controller.add(SseEvent(
          type: 'ERROR',
          content: '登录已过期，请重新登录',
          retryable: false,
        ));
        controller.close();
        return;
      }

      if (response.statusCode != 200) {
        controller.add(SseEvent(
          type: 'ERROR',
          content: '请求失败 (${response.statusCode})',
          retryable: true,
        ));
        controller.close();
        return;
      }

      // 解析SSE流（逐行即时解析，不依赖空行分隔符）
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (data.isEmpty) continue;

          receivedData = true;
          try {
            final json = jsonDecode(data);
            final event = SseEvent.fromJson(json);

            // 检查是否是新会话创建
            if (event.extra?['sessionId'] != null && onSessionCreated != null) {
              onSessionCreated(event.extra!['sessionId']);
            }

            if (!controller.isClosed) {
              controller.add(event);
            }
          } catch (_) {
            // 解析失败时作为纯文本处理
            if (!controller.isClosed) {
              controller.add(SseEvent(type: 'TEXT', content: data));
            }
          }
        }
      }

      client.close();
      if (!controller.isClosed) {
        controller.close();
      }
    } catch (e) {
      // 连接关闭是SSE流正常结束的标志，只有没收到任何数据时才报错
      if (receivedData && e.toString().contains('Connection closed')) {
        client?.close();
        if (!controller.isClosed) controller.close();
      } else if (!controller.isClosed) {
        controller.add(SseEvent(
          type: 'ERROR',
          content: '连接失败: $e',
          retryable: true,
        ));
        controller.close();
      }
    }
  }
}