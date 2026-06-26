import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../model/auth_model.dart';
import '../constants/app_constants.dart';
import '../main.dart';
import 'secure_storage_service.dart';

class ApiClient {
  static String get baseUrl => AppConstants.baseUrl;
  static final SecureStorageService _storage = SecureStorageService();
  static const Duration _timeout = Duration(seconds: 15);

  static LoginResponse? _currentUser;
  static Future<bool>? _refreshInProgress;

  static void setUser(LoginResponse user) {
    _currentUser = user;
  }

  static LoginResponse? get currentUser => _currentUser;

  static Future<String?> getAccessToken() async {
    return await _storage.getAccessToken();
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.getRefreshToken();
  }

  static Future<void> loadStoredAuth() async {
    final user = await _storage.getUser();
    if (user != null) {
      _currentUser = user;
    }
  }

  static Future<void> clearAuth() async {
    await _storage.clearAll();
    _currentUser = null;
  }

  /// 显示登录过期弹窗，点击确定跳转登录，点击取消退出APP
  static Future<void> showSessionExpiredDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.access_time, size: 28, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              const Text(
                '登录已过期',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              const SizedBox(height: 8),
              const Text(
                '您的登录状态已过期，请重新登录',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                      ),
                      child: const Text('退出', style: TextStyle(color: Color(0xFF666666), fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // 退出到登录页
                        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                      ),
                      child: const Text('取消', style: TextStyle(color: Color(0xFF666666), fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // 重新登录
                        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('重新登录', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _buildUrl(String path, {Map<String, String>? params}) {
    String url = '$baseUrl$path';
    if (params != null && params.isNotEmpty) {
      final uri = Uri.parse(url).replace(queryParameters: params);
      url = uri.toString();
    }
    return url;
  }

  /// 检查响应状态码，非 2xx 抛出异常
  static void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = '请求失败 (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          message = data['message'];
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  /// 统一的 401 刷新 + 重试逻辑（带互斥锁）
  static Future<http.Response> _requestWithRefresh(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    var response = await request(await _getAuthHeaders());

    if (response.statusCode == 401) {
      final refreshed = await _refreshTokenWithMutex();
      if (refreshed) {
        response = await request(await _getAuthHeaders());
        // If still 401 after refresh, force re-login
        if (response.statusCode == 401) {
          await clearAuth();
          await showSessionExpiredDialog();
          throw Exception('登录已过期，请重新登录');
        }
      } else {
        await clearAuth();
        await showSessionExpiredDialog();
        throw Exception('登录已过期，请重新登录');
      }
    }

    _checkResponse(response);
    return response;
  }

  /// 带互斥锁的 Token 刷新
  static Future<bool> _refreshTokenWithMutex() {
    if (_refreshInProgress != null) return _refreshInProgress!;
    _refreshInProgress = _doRefresh().whenComplete(() => _refreshInProgress = null);
    return _refreshInProgress!;
  }

  static Future<bool> _doRefresh() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(data);
        if (loginResponse.accessToken.isNotEmpty && loginResponse.refreshToken.isNotEmpty) {
          await _storage.saveTokens(loginResponse.accessToken, loginResponse.refreshToken);
        }
        // Only overwrite user data if the refresh response contains valid user fields
        if (loginResponse.userId != 0) {
          await _storage.saveUser(loginResponse);
          setUser(loginResponse);
        } else if (_currentUser != null) {
          // Preserve existing user data, only update tokens
          final merged = LoginResponse(
            accessToken: loginResponse.accessToken.isNotEmpty ? loginResponse.accessToken : _currentUser!.accessToken,
            refreshToken: loginResponse.refreshToken.isNotEmpty ? loginResponse.refreshToken : _currentUser!.refreshToken,
            tokenType: 'Bearer',
            userId: _currentUser!.userId,
            username: _currentUser!.username,
            nickname: _currentUser!.nickname,
            email: _currentUser!.email,
            phone: _currentUser!.phone,
            realNameVerified: _currentUser!.realNameVerified,
            realName: _currentUser!.realName,
          );
          await _storage.saveUser(merged);
          setUser(merged);
        }
        return true;
      }
      return false;
    } on SocketException catch (e) {
      // Network unreachable — preserve existing tokens, throw for caller to retry
      throw Exception('网络连接失败，请检查网络后重试');
    } on TimeoutException catch (e) {
      throw Exception('请求超时，请稍后重试');
    } catch (e) {
      // Other errors — clear auth state
      await clearAuth();
      await showSessionExpiredDialog();
      return false;
    }
  }

  /// 无需认证的 POST 请求（用于登录、注册等公开端点）
  static Future<http.Response> postPublic(String path, {Map<String, dynamic>? body}) async {
    final url = '$baseUrl$path';
    return await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? json.encode(body) : null,
    ).timeout(_timeout);
  }

  /// 通用 GET 请求
  static Future<String> get(String path, {Map<String, String>? params}) async {
    final url = _buildUrl(path, params: params);
    final response = await _requestWithRefresh(
      (headers) => http.get(Uri.parse(url), headers: headers).timeout(_timeout),
    );
    return response.body;
  }

  /// 通用 POST 请求
  static Future<String> post(String path, {Map<String, dynamic>? body}) async {
    final url = _buildUrl(path);
    final response = await _requestWithRefresh(
      (headers) => http.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(_timeout),
    );
    return response.body;
  }

  /// 通用 PUT 请求
  static Future<String> put(String path, {Map<String, dynamic>? body}) async {
    final url = _buildUrl(path);
    final response = await _requestWithRefresh(
      (headers) => http.put(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(_timeout),
    );
    return response.body;
  }

  /// 通用 DELETE 请求
  static Future<String> delete(String path) async {
    final url = _buildUrl(path);
    final response = await _requestWithRefresh(
      (headers) => http.delete(Uri.parse(url), headers: headers).timeout(_timeout),
    );
    return response.body;
  }
}
