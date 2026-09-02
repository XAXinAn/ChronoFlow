import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../model/excel_import_model.dart';
import '../../utils/message_utils.dart';
import 'excel_import_preview_page.dart';

class ExcelImportPage extends StatefulWidget {
  const ExcelImportPage({super.key});

  @override
  State<ExcelImportPage> createState() => _ExcelImportPageState();
}

class _ExcelImportPageState extends State<ExcelImportPage> {
  bool _downloading = false;

  Future<void> _downloadTemplate() async {
    setState(() => _downloading = true);
    try {
      final bytes = await ExcelImportService().downloadTemplate();
      if (!mounted) return;
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '保存群组导入模板',
        fileName: 'group_import_template.xlsx',
        bytes: bytes,
      );
      if (mounted) {
        MessageUtils.show(context, path != null ? '模板已保存，可在文件管理中查看' : '已取消保存');
      }
    } catch (e) {
      if (mounted) MessageUtils.show(context, '下载模板失败');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExcelImportPreviewPage(file: file)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入Excel建群')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('使用说明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('1. 下载群组导入模板'),
            const Text('2. 按模板填写群组信息（名称、描述、父群组、成员手机号）'),
            const Text('3. 上传填写完成的Excel文件'),
            const Text('4. 预览校验结果并确认导入'),
            const SizedBox(height: 8),
            const Text('字段说明：', style: TextStyle(fontWeight: FontWeight.w500)),
            const Text('• 群组名称：必填，1-100字符'),
            const Text('• 群组描述：选填'),
            const Text('• 父群组名称：选填，空表示顶级群组'),
            const Text('• 成员手机号：选填，多个用英文逗号分隔'),
            const Text('• 加群是否需要审批：选填，是/否，默认否'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _downloadTemplate,
                icon: _downloading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
                label: Text(_downloading ? '下载中...' : '下载模板'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('上传Excel文件'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}