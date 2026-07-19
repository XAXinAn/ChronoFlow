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

  /// 鏄剧ず鐧诲綍杩囨湡寮圭獥锛岀偣鍑荤‘瀹氳烦杞櫥褰曪紝鐐瑰嚮鍙栨秷閫€鍑篈PP
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
                '鐧诲綍宸茶繃鏈?,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              const SizedBox(height: 8),
              const Text(
                '鎮ㄧ殑鐧诲綍鐘舵€佸凡杩囨湡锛岃閲嶆柊鐧诲綍',
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
                      child: const Text('閫€鍑?, style: TextStyle(color: Color(0xFF666666), fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // 閫€鍑哄埌鐧诲綍椤?
                        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                      ),
                      child: const Text('鍙栨秷', style: TextStyle(color: Color(0xFF666666), fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // 閲嶆柊鐧诲綍
                        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('閲嶆柊鐧诲綍', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
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

  /// 妫€鏌ュ搷搴旂姸鎬佺爜锛岄潪 2xx 鎶涘嚭寮傚父
  static void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = '璇锋眰澶辫触 (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          message = data['message'];
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  /// 缁熶竴鐨?401 鍒锋柊 + 閲嶈瘯閫昏緫锛堝甫浜掓枼閿侊級
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
          throw Exception('鐧诲綍宸茶繃鏈燂紝璇烽噸鏂扮櫥褰?);
        }
      } else {
        await clearAuth();
        await showSessionExpiredDialog();
        throw Exception('鐧诲綍宸茶繃鏈燂紝璇烽噸鏂扮櫥褰?);
      }
    }

    _checkResponse(response);
    return response;
  }

  /// 甯︿簰鏂ラ攣鐨?Token 鍒锋柊
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
            role: _currentUser!.role,
          );
          await _storage.saveUser(merged);
          setUser(merged);
        }
        return true;
      }
      return false;
    } on SocketException catch (e) {
      // Network unreachable 鈥?preserve existing tokens, throw for caller to retry
      throw Exception('缃戠粶杩炴帴澶辫触锛岃妫€鏌ョ綉缁滃悗閲嶈瘯');
    } catch (e) {
      // Other errors 鈥?clear auth state
      await clearAuth();
      await showSessionExpiredDialog();
      return false;
    }
  }

  /// 鏃犻渶璁よ瘉鐨?POST 璇锋眰锛堢敤浜庣櫥褰曘€佹敞鍐岀瓑鍏紑绔偣锛?
  static Future<http.Response> postPublic(String path, {Map<String, dynamic>? body}) async {
    final url = '$baseUrl$path';
    return await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? json.encode(body) : null,
    ).timeout(_timeout);
  }

  /// 閫氱敤 GET 璇锋眰
  static Future<String> get(String path, {Map<String, String>? params}) async {
    final url = _buildUrl(path, params: params);
    final response = await _requestWithRefresh(
      (headers) => http.get(Uri.parse(url), headers: headers).timeout(_timeout),
    );
    return response.body;
  }

  /// 閫氱敤 POST 璇锋眰
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

  /// 閫氱敤 PUT 璇锋眰
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

  /// 閫氱敤 DELETE 璇锋眰
  static Future<String> delete(String path) async {
    final url = _buildUrl(path);
    final response = await _requestWithRefresh(
      (headers) => http.delete(Uri.parse(url), headers: headers).timeout(_timeout),
    );
    return response.body;
  }
}
