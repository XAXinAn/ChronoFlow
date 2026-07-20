import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/resource_model.dart';

/// 资源详情页 — 展示学习资源的完整Markdown内容。
///
/// 功能：
/// - 标题 + 资源类型标签
/// - 全文Markdown渲染（当前使用Text展示，后续可集成flutter_markdown）
/// - AI生成标识
/// - 置信度显示
class ResourceDetailPage extends StatelessWidget {
  final LearningResource resource;

  const ResourceDetailPage({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(resource.title, style: const TextStyle(fontWeight: FontWeight.w300)),
        actions: [
          if (resource.canDownload)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: '下载 Markdown 文件',
              onPressed: () => _downloadResource(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 资源类型标签 + AI生成标识
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTypeColor(resource.resourceType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${resource.typeIcon} ${resource.typeDisplayName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getTypeColor(resource.resourceType),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AI生成',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6366F1)),
                        ),
                      ),
                      const Spacer(),
                      // 置信度
                      if (resource.confidenceScore < 0.8)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '置信度 ${(resource.confidenceScore * 100).toInt()}%',
                            style: const TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 标题
                  Text(
                    resource.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 生成时间
                  Text(
                    '生成于 ${_formatDate(resource.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 资源内容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.content,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 底部提示
            Center(
              child: Text(
                '此内容由AI生成，仅供学习参考',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'DOC': return const Color(0xFF6366F1);
      case 'MINDMAP': return const Color(0xFFF59E0B);
      case 'QUIZ': return const Color(0xFFEF4444);
      case 'READING': return const Color(0xFF059669);
      case 'CODE': return const Color(0xFF3B82F6);
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadResource(BuildContext context) async {
    if (resource.downloadUrl == null) return;
    final uri = Uri.parse(resource.downloadUrl!);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开下载链接')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }
}