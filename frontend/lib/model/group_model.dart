class Group {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final int memberCount;
  final int creatorId;
  final DateTime createdAt;
  final bool requireApproval;
  final bool pendingApproval;
  final bool isAdminOrCreator;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.memberCount,
    required this.creatorId,
    required this.createdAt,
    required this.requireApproval,
    this.pendingApproval = false,
    this.isAdminOrCreator = false,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      inviteCode: json['inviteCode'] ?? '',
      memberCount: json['memberCount'] ?? 0,
      creatorId: json['creatorId'] ?? 0,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      requireApproval: json['requireApproval'] ?? false,
      pendingApproval: json['pendingApproval'] ?? false,
      isAdminOrCreator: json['isAdminOrCreator'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'memberCount': memberCount,
      'creatorId': creatorId,
      'createdAt': createdAt.toIso8601String(),
      'requireApproval': requireApproval,
      'pendingApproval': pendingApproval,
      'isAdminOrCreator': isAdminOrCreator,
    };
  }
}

class GroupMember {
  final int userId;
  final String username;   // 用户名
  final String nickname;   // 群昵称
  final String email;
  final bool isCreator;
  final bool isAdmin;

  GroupMember({
    required this.userId,
    required this.username,
    required this.nickname,
    required this.email,
    required this.isCreator,
    required this.isAdmin,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      email: json['email'] ?? '',
      isCreator: json['isCreator'] ?? false,
      isAdmin: json['isAdmin'] ?? false,
    );
  }
}

class JoinRequest {
  final int userId;
  final String username;
  final String email;
  final DateTime createdAt;
  final String groupId;
  final String groupName;
  final String status;

  JoinRequest({
    required this.userId,
    required this.username,
    required this.email,
    required this.createdAt,
    this.groupId = '',
    this.groupName = '',
    this.status = 'pending',
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      userId: json['userId'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      groupId: json['groupId'] ?? '',
      groupName: json['groupName'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }
}
