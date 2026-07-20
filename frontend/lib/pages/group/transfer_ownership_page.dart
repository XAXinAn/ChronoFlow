import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

class TransferOwnershipPage extends StatefulWidget {
  final Group group;
  const TransferOwnershipPage({super.key, required this.group});

  @override
  State<TransferOwnershipPage> createState() => _TransferOwnershipPageState();
}

class _TransferOwnershipPageState extends State<TransferOwnershipPage> {
  final GroupService _groupService = GroupService();
  List<GroupMember> _members = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final members = await _groupService.getGroupMembers(widget.group.id);
      if (mounted) {
        setState(() {
          _members = members.where((m) => m.userId != widget.group.creatorId).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = MessageUtils.cleanError(e); });
    }
  }

  Future<void> _confirmTransfer(GroupMember target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('确认转让群主'),
        content: Text('确定将群主转让给「${_displayName(target)}」吗？\n\n转让后你将失去群主权限，成为普通成员。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('确认转让'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _groupService.transferOwnership(widget.group.id, target.userId);
      if (mounted) {
        MessageUtils.show(context, '群主已转让给${_displayName(target)}');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) MessageUtils.showError(context, e);
    }
  }

  String _displayName(GroupMember m) {
    if (m.nickname.isNotEmpty) return m.nickname;
    if (m.accountNickname.isNotEmpty) return m.accountNickname;
    return m.username;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('转让群主', style: TextStyle(fontWeight: FontWeight.w300)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('重试')),
                ]))
              : _members.isEmpty
                  ? const Center(child: Text('没有可转让的成员', style: TextStyle(color: Colors.black38, fontSize: 15)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _confirmTransfer(member),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.orange.shade50,
                                    child: Text(
                                      _displayName(member).isNotEmpty ? _displayName(member)[0].toUpperCase() : '?',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.orange.shade400),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Text(_displayName(member), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                        if (member.isAdmin) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('管理员', style: TextStyle(fontSize: 11, color: Colors.orange)),
                                          ),
                                        ],
                                      ]),
                                      if (member.username != _displayName(member))
                                        Text(member.username, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                    ]),
                                  ),
                                  const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
