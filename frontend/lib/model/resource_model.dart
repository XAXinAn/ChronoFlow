/// 学习资源模型
class LearningResource {
  final int id;
  final String resourceType;  // DOC / MINDMAP / QUIZ / READING / CODE
  final String title;
  final String content;
  final String? fileKey;      // MinIO object key
  final int? fileSize;        // 文件大小（字节）
  final String? downloadUrl;  // MinIO 公开访问 URL
  final String? metadata;
  final double confidenceScore;
  final bool reviewed;
  final DateTime createdAt;

  LearningResource({
    required this.id,
    required this.resourceType,
    required this.title,
    required this.content,
    this.fileKey,
    this.fileSize,
    this.downloadUrl,
    this.metadata,
    this.confidenceScore = 0.85,
    this.reviewed = false,
    required this.createdAt,
  });

  factory LearningResource.fromJson(Map<String, dynamic> json) {
    return LearningResource(
      id: json['id'] ?? 0,
      resourceType: json['resourceType'] ?? 'DOC',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      fileKey: json['fileKey'],
      fileSize: json['fileSize'],
      downloadUrl: json['downloadUrl'],
      metadata: json['metadata'],
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.85,
      reviewed: json['reviewed'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// 该资源是否可下载（fileKey 不为空则可从 MinIO 下载）
  bool get canDownload => fileKey != null && fileKey!.isNotEmpty;

  /// 资源类型的中文显示名称
  String get typeDisplayName {
    switch (resourceType) {
      case 'DOC': return '讲解文档';
      case 'MINDMAP': return '思维导图';
      case 'QUIZ': return '练习题';
      case 'READING': return '拓展材料';
      case 'CODE': return '代码案例';
      default: return resourceType;
    }
  }

  /// 资源类型的图标
  String get typeIcon {
    switch (resourceType) {
      case 'DOC': return '📄';
      case 'MINDMAP': return '🧠';
      case 'QUIZ': return '📝';
      case 'READING': return '📖';
      case 'CODE': return '💻';
      default: return '📁';
    }
  }
}

/// 云盘文件夹模型
class CloudFolder {
  final String type;
  final String name;
  final String icon;
  final int count;

  CloudFolder({
    required this.type,
    required this.name,
    required this.icon,
    required this.count,
  });

  factory CloudFolder.fromJson(Map<String, dynamic> json) {
    return CloudFolder(
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      count: json['count'] ?? 0,
    );
  }

  /// 文件夹图标emoji
  String get iconEmoji {
    switch (type) {
      case 'DOC': return '📄';
      case 'MINDMAP': return '🧠';
      case 'QUIZ': return '📝';
      case 'READING': return '📖';
      case 'CODE': return '💻';
      default: return '📁';
    }
  }
}