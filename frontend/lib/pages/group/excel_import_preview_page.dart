import 'dart:io';
import 'package:flutter/material.dart';
import '../../model/excel_import_model.dart';
import '../../utils/message_utils.dart';
import 'excel_import_result_page.dart';

class ExcelImportPreviewPage extends StatefulWidget {
  final File file;
  const ExcelImportPreviewPage({super.key, required this.file});

  @override
  State<ExcelImportPreviewPage> createState() => _ExcelImportPreviewPageState();
}

class _ExcelImportPreviewPageState extends State<ExcelImportPreviewPage> {
  bool _loading = true;
  ExcelImportPreviewResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final result = await ExcelImportService().preview(widget.file);
      setState(() { _result = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _confirm() async {
    if (_result?.importToken == null) return;
    setState(() => _loading = true);
    try {
      final importResult = await ExcelImportService().confirm(_result!.importToken!);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ExcelImportResultPage(result: importResult)));
    } catch (e) {
      if (mounted) {
        MessageUtils.show(context, e.toString().replaceFirst('Exception: ', ''));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('预览导入结果')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final result = _result!;
    if (!result.valid) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('校验失败，共 ${result.errors.length} 个错误', style: const TextStyle(color: Colors.red, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: result.errors.length,
              itemBuilder: (_, i) {
                final e = result.errors[i];
                return ListTile(
                  title: Text('第${e.rowNumber}行 - ${e.field}'),
                  subtitle: Text(e.reason),
                  trailing: e.maskedPhone != null ? Text(e.maskedPhone!, style: const TextStyle(color: Colors.grey)) : null,
                );
              },
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('校验通过，共 ${result.totalCount} 个群组', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ...result.previewTree.map(_buildTreeNode),
              const SizedBox(height: 16),
              const Text('成员预览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...result.items.expand((item) => [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ...item.members.map(_buildMemberEntry),
                      ],
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
              child: const Text('确认导入'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreeNode(GroupTreeNode node) {
    return Padding(
      padding: EdgeInsets.only(left: node.depth * 16.0),
      child: Row(
        children: [
          Icon(node.children.isEmpty ? Icons.circle : Icons.folder, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          Text(node.name),
        ],
      ),
    );
  }

  Widget _buildMemberEntry(MemberPreviewEntry m) {
    final statusText = switch (m.registrationStatus) {
      'REGISTERED' => '已注册',
      'UNREGISTERED_DEGRADED' => '未注册（状态识别降级）',
      _ => '未注册',
    };
    final statusColor = m.registrationStatus == 'REGISTERED' ? Colors.green : Colors.orange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.person, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m.name.isEmpty ? "未填写姓名" : m.name}  ${m.phone}', style: const TextStyle(fontSize: 13)),
                Text(
                  '$statusText${m.matchedNickname != null ? "（${m.matchedNickname}）" : ""}'
                  '${m.email.isNotEmpty ? "  邮箱:$m.email" : ""}'
                  '${m.studentId.isNotEmpty ? "  学号:$m.studentId" : ""}',
                  style: TextStyle(fontSize: 12, color: statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
