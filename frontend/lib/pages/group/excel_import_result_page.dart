import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../model/excel_import_model.dart';
import '../../utils/message_utils.dart';

class ExcelImportResultPage extends StatefulWidget {
  final ExcelImportResult result;
  const ExcelImportResultPage({super.key, required this.result});

  @override
  State<ExcelImportResultPage> createState() => _ExcelImportResultPageState();
}

class _ExcelImportResultPageState extends State<ExcelImportResultPage> {
  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Scaffold(
      appBar: AppBar(title: const Text('导入结果')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(r.failCount == 0 ? Icons.check_circle : Icons.error, color: r.failCount == 0 ? Colors.green : Colors.red),
                  const SizedBox(width: 12),
                  Text('成功 ${r.successCount} 个，失败 ${r.failCount} 个', style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('邀请码列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...r.groupInviteCodes.map((e) => Card(
            child: ListTile(
              title: Text(e.groupName),
              subtitle: Text('邀请码: ${e.inviteCode}  (层级: ${e.depth})'),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: e.inviteCode));
                  if (mounted) MessageUtils.show(context, '已复制');
                },
              ),
            ),
          )),
          const SizedBox(height: 16),
          const Text('成员关联', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...r.memberAssociationResults.map((e) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.groupName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('已关联 ${e.associatedCount} 人'),
                  if (e.unregisteredInviteCodes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('未注册成员邀请码:', style: TextStyle(fontSize: 13, color: Colors.orange)),
                    const SizedBox(height: 4),
                    ...e.unregisteredInviteCodes.map((c) => _buildInviteCodeEntry(c)),
                  ] else if (e.unassociatedPhones.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('未关联: ${e.unassociatedPhones.join(', ')}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ),
                ],
              ),
            ),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
              child: const Text('完成'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeEntry(MemberInviteCodeEntry c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('邀请码: ${c.inviteCode}', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${c.maskedName.isEmpty ? "" : "姓名:${c.maskedName}  "}'
                  '${c.maskedPhone.isEmpty ? "" : "手机:${c.maskedPhone}  "}'
                  '${c.maskedEmail.isEmpty ? "" : "邮箱:${c.maskedEmail}  "}'
                  '${c.maskedStudentId.isEmpty ? "" : "学号:${c.maskedStudentId}"}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: c.inviteCode));
              if (mounted) MessageUtils.show(context, '已复制');
            },
          ),
        ],
      ),
    );
  }
}
