import 'package:flutter/material.dart';
import '../../service/message_service.dart';
import 'message_detail_page.dart';

class MessageListPage extends StatefulWidget {
  const MessageListPage({super.key});

  @override
  State<MessageListPage> createState() => _MessageListPageState();
}

class _MessageListPageState extends State<MessageListPage> {
  final MessageService _service = MessageService();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _messages = await _service.getMessages();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'admin_message':
        return '管理员消息';
      case 'feedback_notify':
        return '反馈回复';
      default:
        return '系统通知';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'admin_message':
        return Icons.campaign_outlined;
      case 'feedback_notify':
        return Icons.feedback_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息中心')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? const Center(child: Text('暂无消息', style: TextStyle(color: Colors.black38)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final m = _messages[i];
                      final unread = m['isRead'] == false;
                      return Material(
                        color: unread ? Colors.white : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MessageDetailPage(messageId: m['id']),
                              ),
                            );
                            _load();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: unread ? Colors.black12 : const Color(0xFFEEEEEE)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: unread ? Colors.black : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_typeIcon(m['type'] ?? ''),
                                      size: 20, color: unread ? Colors.white : Colors.black54),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(_typeLabel(m['type'] ?? ''),
                                                style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                          ),
                                          const SizedBox(width: 8),
                                          if (unread)
                                            Container(width: 6, height: 6,
                                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(m['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text(m['content'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black45),
                                          maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(m['createdAt']?.toString().substring(0, 16) ?? '',
                                              style: const TextStyle(fontSize: 11, color: Colors.black38)),
                                          const Spacer(),
                                          if (m['replyCount'] > 0)
                                            Text('${m['replyCount']} 条回复',
                                                style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
