import 'dart:convert';
import '../model/resource_model.dart';
import 'api_client.dart';

/// 云盘服务 — 云盘目录浏览和文件夹内容查询。
class CloudService {
  static String get _basePath => '/v1/cloud';

  /// 获取云盘目录（5个文件夹 + 各资源计数）
  Future<List<CloudFolder>> getDirectory() async {
    final body = await ApiClient.get('$_basePath/directory');
    final data = jsonDecode(body);
    if (data['code'] == 200 && data['data'] != null) {
      final folders = data['data']['folders'] as List?;
      if (folders != null) {
        return folders.map((e) => CloudFolder.fromJson(e)).toList();
      }
    }
    return [];
  }

  /// 获取文件夹内资源列表
  Future<List<LearningResource>> getFolderContent(String type) async {
    final body = await ApiClient.get('$_basePath/folder/$type');
    final data = jsonDecode(body);
    if (data['code'] == 200 && data['data'] != null) {
      return (data['data'] as List)
          .map((e) => LearningResource.fromJson(e))
          .toList();
    }
    return [];
  }

  /// 获取资源详情
  Future<LearningResource> getResourceDetail(int resourceId) async {
    final body = await ApiClient.get('/v1/resources/$resourceId');
    final data = jsonDecode(body);
    return LearningResource.fromJson(data['data']);
  }

  /// 获取单个资源的下载链接
  Future<String?> getResourceDownloadUrl(int resourceId) async {
    try {
      final body = await ApiClient.get('/v1/resources/$resourceId/download');
      final data = jsonDecode(body);
      if (data['code'] == 200 && data['data'] != null) {
        return data['data']['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// 批量导出指定类型的所有资源（返回 ZIP 直接下载 URL）
  String getFolderExportUrl(String type) {
    return '${ApiClient.baseUrl}/v1/cloud/folder/${type.toLowerCase()}/export';
  }
}