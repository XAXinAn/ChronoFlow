import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/resource_model.dart';
import '../../service/cloud_service.dart';
import 'resource_detail_page.dart';

/// 云盘页面 — 展示5个文件夹，点击进入文件夹内资源列表。
///
/// 五个文件夹：讲解文档/思维导图/练习题/拓展材料/代码案例
class CloudPage extends StatefulWidget {
  const CloudPage({super.key});

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  final CloudService _cloudService = CloudService();
  List<CloudFolder> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    try {
      final folders = await _cloudService.getDirectory();
      if (mounted) {
        setState(() {
          _folders = folders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的云盘', style: TextStyle(fontWeight: FontWeight.w300)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDirectory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _folders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_outlined, size: 48,
                            color: Colors.black.withOpacity(0.15)),
                        const SizedBox(height: 16),
                        Text('暂无学习资源', style: TextStyle(
                            fontSize: 16, color: Colors.black.withOpacity(0.35))),
                        const SizedBox(height: 8),
                        Text('在AI学习系统中生成资源后会自动展示在此处',
                            style: TextStyle(
                                fontSize: 13, color: Colors.black.withOpacity(0.25))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _folders.length + 1, // +1 for header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            '学习资源',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      final folder = _folders[index - 1];
                      return _buildFolderCard(folder);
                    },
                  ),
      ),
    );
  }

  Widget _buildFolderCard(CloudFolder folder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _FolderContentPage(
                  folderType: folder.type,
                  folderName: folder.name,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // 文件夹图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getFolderColor(folder.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(folder.iconEmoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),
                // 文件夹名 + 数量
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${folder.count} 个资源',
                        style: const TextStyle(fontSize: 13, color: Colors.black38),
                      ),
                    ],
                  ),
                ),
                // 进入箭头
                Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getFolderColor(String type) {
    switch (type) {
      case 'DOC': return const Color(0xFF6366F1);
      case 'MINDMAP': return const Color(0xFFF59E0B);
      case 'QUIZ': return const Color(0xFFEF4444);
      case 'READING': return const Color(0xFF059669);
      case 'CODE': return const Color(0xFF3B82F6);
      default: return Colors.grey;
    }
  }
}

/// 文件夹内容页 — 展示某一类型文件夹内的资源列表。
class _FolderContentPage extends StatefulWidget {
  final String folderType;
  final String folderName;

  const _FolderContentPage({
    required this.folderType,
    required this.folderName,
  });

  @override
  State<_FolderContentPage> createState() => _FolderContentPageState();
}

class _FolderContentPageState extends State<_FolderContentPage> {
  final CloudService _cloudService = CloudService();
  List<LearningResource> _resources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final resources = await _cloudService.getFolderContent(widget.folderType);
      if (mounted) {
        setState(() {
          _resources = resources;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName, style: const TextStyle(fontWeight: FontWeight.w300)),
        actions: [
          if (_resources.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.archive),
              tooltip: '导出全部为 ZIP',
              onPressed: () => _exportAll(context),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resources.isEmpty
              ? Center(
                  child: Text('暂无资源', style: TextStyle(
                      fontSize: 15, color: Colors.black.withOpacity(0.35))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _resources.length,
                  itemBuilder: (context, index) {
                    final resource = _resources[index];
                    return _buildResourceCard(resource);
                  },
                ),
    );
  }

  Widget _buildResourceCard(LearningResource resource) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResourceDetailPage(resource: resource),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(resource.typeIcon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(resource.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.black38),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportAll(BuildContext context) async {
    final zipUrl = _cloudService.getFolderExportUrl(widget.folderType);
    final uri = Uri.parse(zipUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开导出链接')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }
}