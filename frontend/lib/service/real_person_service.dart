import 'dart:convert';
import 'api_client.dart';

class RealPersonService {
  /// Init verification, returns certifyId.
  Future<String> initVerification(String metaInfo, String realName, String idCardNumber) async {
    final response = await ApiClient.post('/user/real-person-verify', body: {
      'metaInfo': metaInfo, 'realName': realName, 'idCardNumber': idCardNumber,
    });
    final data = json.decode(response);
    if (data['code'] == 200) return data['data']['certifyId'] as String;
    throw Exception(data['message'] ?? '初始化失败');
  }

  /// Query verification result.
  Future<Map<String, dynamic>> getResult(String certifyId) async {
    final response = await ApiClient.get('/user/real-person-verify/result', params: {'certifyId': certifyId});
    return json.decode(response);
  }
}
