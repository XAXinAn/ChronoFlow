import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/group_service.dart';
import 'group_join_requests_page.dart';
import 'subgroup_requests_page.dart';

/// 消息通知页面 — 展示加群申请和子群组创建申请的处理结果
/// 点击通知可进入对应群组的审核页面
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final GroupService _groupService = GroupService();
  bool _isLoading = true;
  List<_NotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = <_NotificationItem>[];

    try {
      final joinRequests = await _groupService.getMyJoinRequests();
      for (final r in joinRequests) {
        items.add(_NotificationItem(
          type: 'join',
          groupId: r.groupId,
          groupName: r.groupName ?? '未知群组',
          detail: '申请加入「${r.groupName ?? "未知群组"}」',
          status: r.status,
          time: r.createdAt,
        ));
      }
    } catch (_) {}

    try {
      final subgroupRequests = await _groupService.getMySubgroupRequests();
      for (final r in subgroupRequests) {
        final name = r['name'] as String? ?? '';
        final parentGroupId = r['parentGroupId'] as String? ?? '';
        final parentName = r['parentGroupName'] as String? ?? '未知群组';
        final status = r['status'] as String? ?? 'pending';
        final createdAt = r['createdAt'] as String? ?? '';
        items.add(_NotificationItem(
          type: 'subgroup',
          groupId: parentGroupId,
          groupName: parentName,
          detail: '申请在「$parentName」下创建子群组「$name」',
          status: status,
          time: DateTime.tryParse(createdAt) ?? DateTime.now(),
        ));
      }
    } catch (_) {}

    // 最新在前
    items.sort((a, b) => b.time.compareTo(a.time));

    if (mounted) setState(() { _items = items; _isLoading = false; });
  }

  /// 点击通知进入对应群组审核页面
  void _onTap(_NotificationItem item) {
    final group = Group(
      id: item.groupId,
      name: item.groupName,
      description: '',
      inviteCode: '',
      memberCount: 0,
      creatorId: 0,
      createdAt: DateTime.now(),
      requireApproval: false,
    );

    if (item.type == 'join') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupJoinRequestsPage(group: group)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubgroupRequestsPage(group: group)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息通知'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text('暂无通知', style: TextStyle(color: Colors.black38, fontSize: 15)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _buildCard(_items[index]),
                  ),
                ),
    );
  }

  Widget _buildCard(_NotificationItem item) {
    final bool isPending = item.status == 'pending';
    final bool isApproved = item.status == 'approved';

    return GestureDetector(
      onTap: () => _onTap(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPending ? Colors.white : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPending ? Colors.black12 : const Color(0xFFEEEEEE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 未处理红点（左上角）
                    if (isPending)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      item.type == 'join' ? '加群申请' : '子群组申请',
                      style: TextStyle(
                        fontSize: 13,
                        color: isPending ? Colors.red : Colors.black38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(item.time),
                      style: const TextStyle(fontSize: 12, color: Colors.black38),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.detail,
                  style: TextStyle(
                    fontSize: 14,
                    color: isPending ? Colors.black87 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _statusLabel(item.status),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isPending
                            ? Colors.orange
                            : isApproved
                                ? Colors.green
                                : Colors.red.shade400,
                      ),
                    ),
                    const Spacer(),
                    if (isPending)
                      const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已拒绝';
      default:
        return status;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _NotificationItem {
  final String type;        // 'join' or 'subgroup'
  final String groupId;
  final String groupName;
  final String detail;
  final String status;
  final DateTime time;

  _NotificationItem({
    required this.type,
    required this.groupId,
    required this.groupName,
    required this.detail,
    required this.status,
    required this.time,
  });
}
