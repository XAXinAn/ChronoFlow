class Schedule {
  final int id;
  final int userId;
  final String? groupId;
  final String? groupName;
  final String title;
  final String description;
  final String location;
  final DateTime time;
  final bool canEditOrDelete;

  Schedule({
    required this.id,
    required this.userId,
    this.groupId,
    this.groupName,
    required this.title,
    required this.description,
    required this.location,
    required this.time,
    this.canEditOrDelete = true,
  });

  bool get isGroupSchedule => groupId != null;

  Schedule.create({
    required this.title,
    required this.description,
    required this.location,
    required this.time,
    this.groupId,
    this.groupName,
  }) : id = 0, userId = 0, canEditOrDelete = true;

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      groupId: json['groupId'],
      groupName: json['groupName'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      canEditOrDelete: json['canEditOrDelete'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'groupId': groupId,
      'groupName': groupName,
      'title': title,
      'description': description,
      'location': location,
      'time': time.toIso8601String(),
      'canEditOrDelete': canEditOrDelete,
    };
  }
}