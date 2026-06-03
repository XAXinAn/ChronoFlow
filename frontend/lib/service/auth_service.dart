import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../model/auth_model.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

class AuthService {
  static const String _authPath = '/auth';
  static final SecureStorageService _storage = SecureStorageService();

  // 委托给 ApiClient 管理用户状态，消除重复 (C-07)
  static LoginResponse? get currentUser => ApiClient.currentUser;

  static Future<String?> getAccessToken() async {
    return await _storage.getAccessToken();
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.getRefreshToken();
  }

  static Future<void> loadStoredAuth() async {
    await ApiClient.loadStoredAuth();
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _storage.saveTokens(accessToken, refreshToken);
  }

  Future<void> _saveUser(LoginResponse user) async {
    await _storage.saveUser(user);
  }

  // 发送短信验证码
  Future<void> sendSms(String phone) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/send-sms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception(data['message'] ?? '发送失败');
      }
    } else {
      throw Exception('发送失败');
    }
  }

  // 短信验证码登录
  Future<LoginResponse?> smsLogin(String phone, String code) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/sms-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data == null) return null;
      final loginResponse = LoginResponse.fromJson(data);
      await _saveTokens(loginResponse.accessToken, loginResponse.refreshToken);
      await _saveUser(loginResponse);
      ApiClient.setUser(loginResponse);
      return loginResponse;
    } else {
      throw Exception('验证码错误');
    }
  }

  // 发送邮箱验证码
  Future<void> sendEmail(String email) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/send-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception(data['message'] ?? '发送失败');
      }
    } else {
      throw Exception('发送失败');
    }
  }

  // 邮箱验证码登录
  Future<LoginResponse?> emailLogin(String email, String code) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/email-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data == null) return null;
      final loginResponse = LoginResponse.fromJson(data);
      await _saveTokens(loginResponse.accessToken, loginResponse.refreshToken);
      await _saveUser(loginResponse);
      ApiClient.setUser(loginResponse);
      return loginResponse;
    } else {
      throw Exception('验证码错误');
    }
  }

  Future<LoginResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final loginResponse = LoginResponse.fromJson(data);
      if (loginResponse.isRiskRequired) return loginResponse;
      await _saveTokens(loginResponse.accessToken, loginResponse.refreshToken);
      await _saveUser(loginResponse);
      ApiClient.setUser(loginResponse);
      return loginResponse;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? '登录失败');
    }
  }

  // 风控验证登录
  Future<LoginResponse> riskVerify(String riskToken, String code) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/risk-verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'riskToken': riskToken, 'code': code}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final loginResponse = LoginResponse.fromJson(data);
      await _saveTokens(loginResponse.accessToken, loginResponse.refreshToken);
      await _saveUser(loginResponse);
      ApiClient.setUser(loginResponse);
      return loginResponse;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? '验证失败');
    }
  }

  Future<String> registerInit({required String username, required String phone,
      required String code, required String password, required String metaInfo,
      required String realName, required String idCardNumber}) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'phone': phone, 'code': code,
        'password': password, 'metaInfo': metaInfo, 'realName': realName, 'idCardNumber': idCardNumber}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['code'] == 200) {
      return data['data']['certifyId'] as String;
    }
    throw Exception(data['message'] ?? '注册初始化失败');
  }

  Future<RegisterResponse> registerConfirm(String certifyId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/register/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'certifyId': certifyId}),
    );
    if (response.statusCode == 200) return RegisterResponse.fromJson(jsonDecode(response.body));
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? '注册确认失败');
  }

  Future<RegisterResponse> register(String username, String phone, String code, String password) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'phone': phone,
        'code': code,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return RegisterResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      if (error['message'] != null) { throw Exception(error['message']); }
      else if (error['errors'] != null) {
        final errors = error['errors'] as Map<String, dynamic>;
        if (errors.isNotEmpty) throw Exception(errors.values.first);
      }
      throw Exception('注册失败');
    }
  }

  Future<LoginResponse> refresh(String refreshToken) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$_authPath/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final loginResponse = LoginResponse.fromJson(data);
      await _saveTokens(loginResponse.accessToken, loginResponse.refreshToken);
      await _saveUser(loginResponse);
      ApiClient.setUser(loginResponse);
      return loginResponse;
    } else {
      throw Exception('Token refresh failed');
    }
  }

  // 绑定邮箱 (C-06: 通过 ApiClient 发送，自动处理 401 刷新)
  Future<LoginResponse> bindEmail(String email, String code) async {
    await ApiClient.post('/user/bind-email', body: {'email': email, 'code': code});
    final result = await refreshUserInfo();
    if (result != null) return result;
    throw Exception('刷新用户信息失败');
  }

  // 修改昵称
  Future<LoginResponse> updateNickname(String nickname) async {
    await ApiClient.post('/user/update-nickname', body: {'nickname': nickname});
    final result = await refreshUserInfo();
    if (result != null) return result;
    throw Exception('刷新用户信息失败');
  }

  // 绑定手机号
  Future<LoginResponse> bindPhone(String phone, String code) async {
    await ApiClient.post('/user/bind-phone', body: {'phone': phone, 'code': code});
    final result = await refreshUserInfo();
    if (result != null) return result;
    throw Exception('刷新用户信息失败');
  }

  // 刷新用户信息 (tokens preserved from storage, user data updated from API)
  Future<LoginResponse?> refreshUserInfo() async {
    final response = await ApiClient.get('/user/info');
    final data = jsonDecode(response);
    // Preserve existing tokens - don't overwrite with potentially stale values
    final accessToken = await getAccessToken() ?? '';
    final refreshToken = await getRefreshToken() ?? '';
    // Preserve existing token data if storage has it, fall back to data from response
    final loginResponse = LoginResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: 'Bearer',
      userId: (data['id'] as num?)?.toInt() ?? 0,
      username: data['username'] ?? '',
      nickname: data['nickname'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
    );
    await _storage.saveUser(loginResponse);
    ApiClient.setUser(loginResponse);
    return loginResponse;
  }

  // 修改密码
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await ApiClient.post('/user/change-password', body: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  // 登出
  Future<void> logout(String accessToken, String refreshToken) async {
    try {
      await ApiClient.post('/auth/logout', body: {'refreshToken': refreshToken});
    } catch (e) {
      // 网络错误时仍清理本地状态
    } finally {
      await ApiClient.clearAuth();
    }
  }

  // 注销账号
  Future<void> deleteAccount(String accessToken, String refreshToken) async {
    try {
      await ApiClient.post('/auth/delete-account', body: {'refreshToken': refreshToken});
    } catch (e) {
      // 网络错误时仍清理本地状态
    } finally {
      await ApiClient.clearAuth();
    }
  }
}
