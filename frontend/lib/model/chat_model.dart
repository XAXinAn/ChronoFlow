/// 对话会话模型
class ChatSession {
  final String sessionId;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.sessionId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['sessionId'] ?? '',
      title: json['title'] ?? '新对话',
      status: json['status'] ?? 'ACTIVE',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// 对话消息模型
class ChatMessage {
  final int? id;
  final String role;        // user / assistant / system
  final String content;
  final String messageType; // TEXT / PROFILE_CARD / RESOURCE_CARD / DIAGRAM / ERROR
  final String? metadata;
  final DateTime createdAt;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.messageType = 'TEXT',
    this.metadata,
    required this.createdAt,
  });

  /// 创建用户消息
  factory ChatMessage.user(String content) {
    return ChatMessage(
      role: 'user',
      content: content,
      messageType: 'TEXT',
      createdAt: DateTime.now(),
    );
  }

  /// 创建AI回复消息
  factory ChatMessage.assistant(String content, {String messageType = 'TEXT'}) {
    return ChatMessage(
      role: 'assistant',
      content: content,
      messageType: messageType,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? 'TEXT',
      metadata: json['metadata'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// SSE事件模型 — 从ChatController流式响应解析
class SseEvent {
  final String type;
  final String? content;
  final String? stage;
  final double percent;
  final String? agent;
  final String? title;
  final String? summary;
  final bool retryable;
  final List<dynamic>? resources;
  final Map<String, dynamic>? extra;

  SseEvent({
    required this.type,
    this.content,
    this.stage,
    this.percent = 0.0,
    this.agent,
    this.title,
    this.summary,
    this.retryable = false,
    this.resources,
    this.extra,
  });

  factory SseEvent.fromJson(Map<String, dynamic> json) {
    return SseEvent(
      type: json['type'] ?? 'TEXT',
      content: json['content'],
      stage: json['stage'],
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      agent: json['agent'],
      title: json['title'],
      summary: json['summary'],
      retryable: json['retryable'] ?? false,
      resources: json['resources'],
      extra: json,
    );
  }
}