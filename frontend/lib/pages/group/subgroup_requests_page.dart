import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

class SubgroupRequestsPage extends StatefulWidget {
  final Group group;
  const SubgroupRequestsPage({super.key, required this.group});
  @override
  State<SubgroupRequestsPage> createState() => _SubgroupRequestsPageState();
}

class _SubgroupRequestsPageState extends State<SubgroupRequestsPage> {
  final GroupService _gs = GroupService();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _gs.getSubgroupRequests(widget.group.id);
      if (mounted) setState(() { _requests = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = MessageUtils.cleanError(e); });
    }
  }

  Future<void> _handle(int applicantId, bool approve) async {
    try {
      await _gs.approveSubgroupRequest(widget.group.id, applicantId, approve);
      if (mounted) {
        MessageUtils.show(context, approve ? '已通过' : '已拒绝');
        _load();
      }
    } catch (e) { if (mounted) MessageUtils.showError(context, e); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('子群组创建申请'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)), const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('重试')),
                ]))
              : _requests.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('暂无子群组创建申请', style: TextStyle(fontSize: 16, color: Colors.black54)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (ctx, i) {
                          final r = _requests[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))]),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                CircleAvatar(radius: 24, backgroundColor: Colors.blue.shade50,
                                  child: Text((r['applicantName'] as String?)?.isNotEmpty == true
                                      ? r['applicantName']![0].toUpperCase() : '?',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blue.shade400))),
                                const SizedBox(width: 16),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(r['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                  if ((r['description'] ?? '').isNotEmpty)
                                    Text(r['description'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black45)),
                                  const SizedBox(height: 2),
                                  Text('申请人: ${r['applicantName'] ?? ""}', style: const TextStyle(fontSize: 12, color: Colors.black38)),
                                ])),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(icon: const Icon(Icons.close), color: Colors.red, tooltip: '拒绝',
                                    onPressed: () => _handle(r['applicantId'] as int, false)),
                                  IconButton(icon: const Icon(Icons.check), color: Colors.green, tooltip: '通过',
                                    onPressed: () => _handle(r['applicantId'] as int, true)),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
