import 'package:flutter/material.dart';
import '../../model/group_model.dart';
import '../../service/auth_service.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';
import 'change_group_nickname_page.dart';
import 'group_join_requests_page.dart';

class GroupSettingsPage extends StatefulWidget {
  final Group group;

  const GroupSettingsPage({super.key, required this.group});

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  final GroupService _groupService = GroupService();
  bool _requireApproval = false;
  bool _isLoading = false;
  bool _isCreator = false;
  bool _isAdmin = false;
  bool _isChecking = true;
  bool _isFirstBuild = true;
  String _myNickname = '';

  @override
  void initState() {
    super.initState();
    _requireApproval = widget.group.requireApproval;
    _checkPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFirstBuild) {
      _checkPermissions();
    }
    _isFirstBuild = false;
  }

  Future<void> _checkPermissions() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    _isCreator = currentUser.userId == widget.group.creatorId;
    if (_isCreator) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    // 检查是否是管理员，并获取自己的昵称
    try {
      final members = await _groupService.getGroupMembers(widget.group.id);
      final myMember = members.where((m) => m.userId == currentUser.userId).toList();
      if (myMember.isNotEmpty && mounted) {
        setState(() {
          _isAdmin = myMember.first.isAdmin;
          _myNickname = myMember.first.nickname;
          _isChecking = false;
        });
      } else if (mounted) {
        setState(() => _isChecking = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  bool get _canManageSettings => _isCreator || _isAdmin;

  Future<void> _updateRequireApproval(bool value) async {
    try {
      await _groupService.updateGroupSettings(
        widget.group.id,
        requireApproval: value,
      );
      if (mounted) {
        setState(() {
          _requireApproval = value;
        });
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.showError(context, e);
      }
    }
  }

  Future<void> _showJoinRequests() async {
    try {
      final requests = await _groupService.getJoinRequests(widget.group.id);
      if (!mounted) return;
      if (requests.isEmpty) {
        MessageUtils.show(context, '暂无加群申请');
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => GroupJoinRequestsPage(group: widget.group)));
    } catch (e) {
      if (mounted) MessageUtils.showError(context, e);
    }
  }

  Future<void> _showSubgroupRequests() async {
    final gs = GroupService();
    try {
      final requests = await gs.getSubgroupRequests(widget.group.id);
      if (!mounted) return;
      if (requests.isEmpty) {
        MessageUtils.show(context, '暂无子群组创建申请');
        return;
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('子群组创建申请', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ...requests.map((r) => ListTile(
                title: Text(r['name'] ?? ''),
                subtitle: Text('${r['applicantName'] ?? ''}  ${r['description'] ?? ''}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () { Navigator.pop(ctx); gs.approveSubgroupRequest(widget.group.id, r['applicantId'] as int, false); }),
                  IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () { Navigator.pop(ctx); gs.approveSubgroupRequest(widget.group.id, r['applicantId'] as int, true); MessageUtils.show(context, '子群组创建成功'); }),
                ]),
              )),
            ]),
          ),
        ),
      );
    } catch (e) {
      if (mounted) MessageUtils.showError(context, e);
    }
  }

  Future<void> _dissolveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('确认解散'),
          ],
        ),
        content: const Text(
          '确定要解散该群组吗？\n\n解散后群组所有数据将被删除，此操作不可恢复。',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认解散'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _groupService.deleteGroup(widget.group.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.showError(context, e);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('群组设置'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('群组设置'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 修改群昵称
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChangeGroupNicknamePage(
                          groupId: widget.group.id,
                          currentNickname: _myNickname,
                        ),
                      ),
                    );
                    if (result != null && mounted) {
                      setState(() => _myNickname = result);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            size: 22,
                            color: Colors.purple.shade400,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '修改群昵称',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _myNickname.isNotEmpty ? '当前：$_myNickname' : '设置你在群里的显示昵称',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 设置区域标题
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                '权限设置',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ),

            // 入群验证开关
            if (_canManageSettings)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  title: const Text(
                    '入群验证',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _requireApproval ? '已开启' : '已关闭',
                      style: TextStyle(
                        fontSize: 13,
                        color: _requireApproval ? Colors.green : Colors.black38,
                      ),
                    ),
                  ),
                  secondary: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _requireApproval
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.verified_user_outlined,
                      size: 22,
                      color: _requireApproval
                          ? Colors.green.shade400
                          : Colors.black54,
                    ),
                  ),
                  value: _requireApproval,
                  onChanged: _updateRequireApproval,
                  activeTrackColor: Colors.green,
                ),
              ),

            if (_canManageSettings) ...[
              const SizedBox(height: 16),
              // 审核子群组创建申请
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showSubgroupRequests(),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.account_tree_outlined, size: 22, color: Colors.teal.shade400)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('审核子群组申请', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('查看和处理子群组创建申请', style: TextStyle(fontSize: 13, color: Colors.black54)),
                        ])),
                        Icon(Icons.chevron_right, size: 20, color: Colors.black26),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
            if (_canManageSettings) ...[
              const SizedBox(height: 16),
              // 审核加群申请按钮
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showJoinRequests(),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.badge_outlined, size: 22, color: Colors.blue.shade400)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('审核加群申请', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('查看和处理成员的加群申请', style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            if (_isCreator) const SizedBox(height: 32),

            // 危险区域标题
            if (_isCreator)
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  '危险操作',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              ),

            // 解散群组按钮
            if (_isCreator)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isLoading ? null : _dissolveGroup,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.dangerous_outlined,
                              size: 22,
                              color: Colors.red.shade400,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '解散群组',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '群组所有数据将被永久删除',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isLoading)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          else
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.black26,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
