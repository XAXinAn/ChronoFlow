class FeedbackModel {
  final int id;
  final int userId;
  final String type;     
  final String content;
  final List<String> imageUrls;
  final String status;   
  final String? adminReply;
  final String? createdAt;
  final String? updatedAt;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.content,
    required this.imageUrls,
    required this.status,
    this.adminReply,
    this.createdAt,
    this.updatedAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      content: json['content'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'pending',
      adminReply: json['adminReply'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  /// 类型中文标签
  String get typeLabel {
    switch (type) {
      case 'bug':
        return '问题反馈';
      case 'suggestion':
        return '功能建议';
      case 'other':
        return '其他';
      default:
        return type;
    }
  }

  /// 状态中文标签
  String get statusLabel {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'processing':
        return '处理中';
      case 'resolved':
        return '已解决';
      case 'closed':
        return '已关闭';
      case 'replied':
        return '已回复';
      default:
        return status;
    }
  }
}