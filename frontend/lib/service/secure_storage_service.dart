import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../model/auth_model.dart';

/// 统一的敏感存储服务
class SecureStorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user';

  static final SecureStorageService _instance = SecureStorageService._();
  factory SecureStorageService() => _instance;
  SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  // H-02: 保存所有用户字段；H-19: 不再存储 token 到 user blob
  Future<void> saveUser(LoginResponse user) async {
    await _storage.write(key: _userKey, value: jsonEncode({
      'tokenType': user.tokenType,
      'userId': user.userId,
      'username': user.username,
      'nickname': user.nickname,
      'email': user.email,
      'phone': user.phone,
    }));
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<LoginResponse?> getUser() async {
    final userData = await _storage.read(key: _userKey);
    if (userData != null) {
      final json = jsonDecode(userData) as Map<String, dynamic>;
      // 从独立 key 读取 token，不从 user blob 读取 (H-19)
      final accessToken = await getAccessToken() ?? '';
      final refreshToken = await getRefreshToken() ?? '';
      json['accessToken'] = accessToken;
      json['refreshToken'] = refreshToken;
      return LoginResponse.fromJson(json);
    }
    return null;
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}
