import 'package:flutter/material.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

/// 扫码加入群组确认页面
class JoinGroupConfirmPage extends StatefulWidget {
  final String inviteCode;

  const JoinGroupConfirmPage({super.key, required this.inviteCode});

  @override
  State<JoinGroupConfirmPage> createState() => _JoinGroupConfirmPageState();
}

class _JoinGroupConfirmPageState extends State<JoinGroupConfirmPage> {
  bool _isLoading = true;
  bool _requireApproval = false;
  String? _error;
  String? _groupName;

  @override
  void initState() {
    super.initState();
    _checkGroupInfo();
  }

  Future<void> _checkGroupInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 调用后端API检查群组信息
      final groupInfo = await GroupService().getGroupInfoByInviteCode(widget.inviteCode);
      setState(() {
        _isLoading = false;
        _requireApproval = groupInfo.requireApproval;
        _groupName = groupInfo.name;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = MessageUtils.cleanError(e);
      });
    }
  }

  Future<void> _joinGroup() async {
    setState(() => _isLoading = true);

    try {
      final group = await GroupService().joinGroup(widget.inviteCode);
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (group.pendingApproval == true) {
        MessageUtils.show(context, '已提交加群申请，请等待群主/管理员确认');
        Navigator.pop(context, true);
      } else {
        MessageUtils.show(context, '加入成功');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      String msg = e.toString();
      if (msg.contains('正在等待处理') || msg.contains('需要群主/管理员确认')) {
        MessageUtils.show(context, '您已提交过加群申请，请等待审批');
        Navigator.pop(context, true);
      } else if (msg.contains('已经加入该群组')) {
        MessageUtils.show(context, '您已加入该群组');
        Navigator.pop(context, true);
      } else {
        MessageUtils.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('加入群组'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 群组图标
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.group,
                          size: 40,
                          color: Colors.blue.shade400,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 群组名称
                      if (_groupName != null) ...[
                        Text(
                          _groupName!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // 邀请码
                      const Text(
                        '邀请码',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.inviteCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 根据是否需要审核显示不同提示
                      if (_requireApproval) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange.shade700),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '该群组需要群主/管理员审批后才能加入',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _joinGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '确认申请加入',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '该群组无需审批，可直接加入',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _joinGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '确认加入',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ),
    );
  }
}