import 'package:flutter/material.dart';
import '../../service/message_service.dart';

class MessageDetailPage extends StatefulWidget {
  final int messageId;
  const MessageDetailPage({super.key, required this.messageId});

  @override
  State<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailPage> {
  final MessageService _service = MessageService();
  final TextEditingController _replyCtrl = TextEditingController();
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _detail = await _service.getDetail(widget.messageId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.reply(widget.messageId, text);
      _replyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('回复成功'), backgroundColor: Colors.black),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('回复失败: $e'), backgroundColor: Colors.red),
      );
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('消息详情')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_detail == null) {
      return Scaffold(appBar: AppBar(title: const Text('消息详情')), body: const Center(child: Text('消息不存在')));
    }

    final replies = List<Map<String, dynamic>>.from(_detail!['replies'] ?? []);
    final canReply = _detail!['canReply'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('消息详情')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_detail!['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_detail!['createdAt']?.toString().substring(0, 16) ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.black38)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_detail!['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.6)),
                  ),
                  if (replies.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('回复记录', style: TextStyle(fontSize: 14, color: Colors.black45)),
                    const SizedBox(height: 8),
                    ...replies.map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(r['isAdmin'] == true ? '管理员' : '我',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                          color: r['isAdmin'] == true ? Colors.blue : Colors.black54)),
                                  const SizedBox(width: 8),
                                  Text(r['createdAt']?.toString().substring(0, 16) ?? '',
                                      style: const TextStyle(fontSize: 11, color: Colors.black38)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(r['content'] ?? '', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (canReply)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      decoration: InputDecoration(
                        hintText: '输入回复...',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _reply,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                      child: _sending
                          ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
