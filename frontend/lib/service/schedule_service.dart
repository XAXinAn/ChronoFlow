import 'dart:convert';
import '../model/schedule_model.dart';
import 'api_client.dart';

class ScheduleService {
  final String baseUrl = '/schedules';

  Future<List<Schedule>> getSchedules({DateTime? date, String? search}) async {
    Map<String, String>? params;
    if (date != null) {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      params = {'date': dateStr};
    }
    if (search != null && search.isNotEmpty) {
      params ??= {};
      params['search'] = search;
    }

    final response = await ApiClient.get(baseUrl, params: params);

    final decoded = json.decode(response);
    // Handle both wrapped {code, data: [...]} and raw [...] response formats
    List<dynamic> jsonList;
    if (decoded is Map && decoded.containsKey('data')) {
      jsonList = decoded['data'] as List<dynamic>? ?? [];
    } else if (decoded is List) {
      jsonList = decoded;
    } else {
      jsonList = [];
    }
    return jsonList.map((json) => Schedule.fromJson(json)).toList();
  }

  Future<Schedule> createSchedule({
    required String title,
    required String description,
    required String location,
    required DateTime time,
  }) async {
    return createScheduleFromSchedule(Schedule.create(
      title: title,
      description: description,
      location: location,
      time: time,
    ));
  }

  Future<Schedule> createScheduleFromSchedule(Schedule schedule) async {
    final body = {
      'title': schedule.title,
      'description': schedule.description,
      'location': schedule.location,
      'time': schedule.time.toIso8601String(),
    };
    final response = await ApiClient.post(baseUrl, body: body);

    return Schedule.fromJson(json.decode(response));
  }

  Future<Schedule> updateSchedule({
    required int id,
    required String title,
    required String description,
    required String location,
    required DateTime time,
    String? groupId,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
      'time': time.toIso8601String(),
    };
    if (groupId != null) {
      body['groupId'] = groupId;
    }

    final response = await ApiClient.put('$baseUrl/$id', body: body);
    return Schedule.fromJson(json.decode(response));
  }

  Future<Schedule> createGroupSchedule({
    required String groupId,
    required String title,
    required String description,
    required String location,
    required DateTime time,
    List<String>? publishTargetGroupIds,
  }) async {
    final body = {
      'title': title,
      'description': description,
      'location': location,
      'time': time.toIso8601String(),
      'publishTargetGroupIds': publishTargetGroupIds ?? [],
    };
    final response = await ApiClient.post('$baseUrl/group?groupId=$groupId', body: body);

    return Schedule.fromJson(json.decode(response));
  }

  Future<void> deleteSchedule(int id) async {
    await ApiClient.delete('$baseUrl/$id');
  }

  /// 解析通知截图中的日程信息（仅解析，不自动保存）
  Future<List<Map<String, dynamic>>> parseNotification(String ocrText) async {
    final response = await ApiClient.post('/notification/parse-only', body: {'ocrText': ocrText});
    final data = json.decode(response);
    if (data['code'] == 200 || data['status'] == 'success') {
      List<dynamic> list = data['data'] ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception(data['message'] ?? '解析失败');
  }
}