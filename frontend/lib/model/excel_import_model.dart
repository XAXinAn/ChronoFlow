import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class MemberInfo {
  final String name;
  final String studentId;
  final String email;
  final String phone;

  MemberInfo({required this.name, required this.studentId, required this.email, required this.phone});

  factory MemberInfo.fromJson(Map<String, dynamic> json) => MemberInfo(
    name: json['name'] ?? '',
    studentId: json['studentId'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'] ?? '',
  );
}

class MemberPreviewEntry {
  final int rowNumber;
  final String name;
  final String studentId;
  final String email;
  final String phone;
  final String registrationStatus;
  final String? matchedNickname;

  MemberPreviewEntry({
    required this.rowNumber,
    required this.name,
    required this.studentId,
    required this.email,
    required this.phone,
    required this.registrationStatus,
    this.matchedNickname,
  });

  factory MemberPreviewEntry.fromJson(Map<String, dynamic> json) => MemberPreviewEntry(
    rowNumber: json['rowNumber'] ?? 0,
    name: json['name'] ?? '',
    studentId: json['studentId'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'] ?? '',
    registrationStatus: json['registrationStatus'] ?? 'UNREGISTERED',
    matchedNickname: json['matchedNickname'],
  );
}

class MemberInviteCodeEntry {
  final String inviteCode;
  final String maskedName;
  final String maskedStudentId;
  final String maskedEmail;
  final String maskedPhone;

  MemberInviteCodeEntry({
    required this.inviteCode,
    required this.maskedName,
    required this.maskedStudentId,
    required this.maskedEmail,
    required this.maskedPhone,
  });

  factory MemberInviteCodeEntry.fromJson(Map<String, dynamic> json) => MemberInviteCodeEntry(
    inviteCode: json['inviteCode'] ?? '',
    maskedName: json['maskedName'] ?? '',
    maskedStudentId: json['maskedStudentId'] ?? '',
    maskedEmail: json['maskedEmail'] ?? '',
    maskedPhone: json['maskedPhone'] ?? '',
  );
}

class GroupImportItem {
  final int rowNumber;
  final String name;
  final String description;
  final String parentName;
  final List<String> memberPhones;
  final bool requireApproval;
  final List<MemberPreviewEntry> members;

  GroupImportItem({
    required this.rowNumber,
    required this.name,
    required this.description,
    required this.parentName,
    required this.memberPhones,
    required this.requireApproval,
    this.members = const [],
  });

  factory GroupImportItem.fromJson(Map<String, dynamic> json) => GroupImportItem(
    rowNumber: json['rowNumber'] ?? 0,
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    parentName: json['parentName'] ?? '',
    memberPhones: (json['memberPhones'] as List<dynamic>?)?.cast<String>() ?? [],
    requireApproval: json['requireApproval'] ?? false,
    members: (json['members'] as List<dynamic>?)?.map((e) => MemberPreviewEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

class GroupImportError {
  final int rowNumber;
  final String field;
  final String reason;
  final String? maskedPhone;

  GroupImportError({required this.rowNumber, required this.field, required this.reason, this.maskedPhone});

  factory GroupImportError.fromJson(Map<String, dynamic> json) => GroupImportError(
    rowNumber: json['rowNumber'] ?? 0,
    field: json['field'] ?? '',
    reason: json['reason'] ?? '',
    maskedPhone: json['maskedPhone'],
  );
}

class GroupTreeNode {
  final String name;
  final int depth;
  final List<GroupTreeNode> children;

  GroupTreeNode({required this.name, required this.depth, required this.children});

  factory GroupTreeNode.fromJson(Map<String, dynamic> json) => GroupTreeNode(
    name: json['name'] ?? '',
    depth: json['depth'] ?? 0,
    children: (json['children'] as List<dynamic>?)?.map((c) => GroupTreeNode.fromJson(c as Map<String, dynamic>)).toList() ?? [],
  );
}

class ExcelImportPreviewResult {
  final bool valid;
  final int totalCount;
  final List<GroupImportItem> items;
  final List<GroupImportError> errors;
  final List<GroupTreeNode> previewTree;
  final String? importToken;

  ExcelImportPreviewResult({
    required this.valid,
    required this.totalCount,
    required this.items,
    required this.errors,
    required this.previewTree,
    this.importToken,
  });

  factory ExcelImportPreviewResult.fromJson(Map<String, dynamic> json) => ExcelImportPreviewResult(
    valid: json['valid'] ?? false,
    totalCount: json['totalCount'] ?? 0,
    items: (json['items'] as List<dynamic>?)?.map((e) => GroupImportItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    errors: (json['errors'] as List<dynamic>?)?.map((e) => GroupImportError.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    previewTree: (json['previewTree'] as List<dynamic>?)?.map((e) => GroupTreeNode.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    importToken: json['importToken'],
  );
}

class GroupInviteCodeEntry {
  final String groupName;
  final String inviteCode;
  final int depth;

  GroupInviteCodeEntry({required this.groupName, required this.inviteCode, required this.depth});

  factory GroupInviteCodeEntry.fromJson(Map<String, dynamic> json) => GroupInviteCodeEntry(
    groupName: json['groupName'] ?? '',
    inviteCode: json['inviteCode'] ?? '',
    depth: json['depth'] ?? 0,
  );
}

class MemberAssociationResult {
  final String groupName;
  final int associatedCount;
  final List<String> unassociatedPhones;
  final List<MemberInviteCodeEntry> unregisteredInviteCodes;

  MemberAssociationResult({
    required this.groupName,
    required this.associatedCount,
    required this.unassociatedPhones,
    this.unregisteredInviteCodes = const [],
  });

  factory MemberAssociationResult.fromJson(Map<String, dynamic> json) => MemberAssociationResult(
    groupName: json['groupName'] ?? '',
    associatedCount: json['associatedCount'] ?? 0,
    unassociatedPhones: (json['unassociatedPhones'] as List<dynamic>?)?.cast<String>() ?? [],
    unregisteredInviteCodes: (json['unregisteredInviteCodes'] as List<dynamic>?)?.map((e) => MemberInviteCodeEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

class ExcelImportResult {
  final int successCount;
  final int failCount;
  final List<GroupImportError> failures;
  final List<GroupInviteCodeEntry> groupInviteCodes;
  final List<GroupTreeNode> hierarchyTree;
  final List<MemberAssociationResult> memberAssociationResults;

  ExcelImportResult({
    required this.successCount,
    required this.failCount,
    required this.failures,
    required this.groupInviteCodes,
    required this.hierarchyTree,
    required this.memberAssociationResults,
  });

  factory ExcelImportResult.fromJson(Map<String, dynamic> json) => ExcelImportResult(
    successCount: json['successCount'] ?? 0,
    failCount: json['failCount'] ?? 0,
    failures: (json['failures'] as List<dynamic>?)?.map((e) => GroupImportError.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    groupInviteCodes: (json['groupInviteCodes'] as List<dynamic>?)?.map((e) => GroupInviteCodeEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    hierarchyTree: (json['hierarchyTree'] as List<dynamic>?)?.map((e) => GroupTreeNode.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    memberAssociationResults: (json['memberAssociationResults'] as List<dynamic>?)?.map((e) => MemberAssociationResult.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

class ExcelImportService {
  static const _baseUrl = '/group/import';
  static const _storage = FlutterSecureStorage();

  Future<Uint8List> downloadTemplate() async {
    final token = await _storage.read(key: 'access_token');
    final uri = Uri.parse('${AppConstants.baseUrl}$_baseUrl/template');
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('下载模板失败');
  }

  Future<ExcelImportPreviewResult> preview(File file) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('未登录，请先登录');

    final uri = Uri.parse('${AppConstants.baseUrl}$_baseUrl/preview');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = json.decode(response.body);

    if (data['code'] == 200) {
      return ExcelImportPreviewResult.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? '预览失败');
  }

  Future<ExcelImportResult> confirm(String importToken) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('未登录，请先登录');

    final uri = Uri.parse('${AppConstants.baseUrl}$_baseUrl/confirm');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'importToken': importToken}),
    );
    final data = json.decode(response.body);

    if (data['code'] == 200) {
      return ExcelImportResult.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? '导入失败');
  }
}
