import 'dart:convert';
import 'api_client.dart';

class MessageService {
  /// Get user's message list
  Future<List<Map<String, dynamic>>> getMessages() async {
    final resp = await ApiClient.get('/messages');
    final data = json.decode(resp);
    return List<Map<String, dynamic>>.from(data['data'] ?? []);
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    final resp = await ApiClient.get('/messages/unread-count');
    final data = json.decode(resp);
    return data['data'] ?? 0;
  }

  /// Get message detail with replies
  Future<Map<String, dynamic>> getDetail(int id) async {
    final resp = await ApiClient.get('/messages/$id');
    final data = json.decode(resp);
    return data['data'] ?? {};
  }

  /// Reply to a message
  Future<void> reply(int messageId, String content) async {
    await ApiClient.post('/messages/$messageId/reply', body: {'content': content});
  }
}
