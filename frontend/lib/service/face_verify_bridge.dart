import 'package:flutter/services.dart';

/// Bridge to Alibaba Cloud Face Verification SDK (com.dtf.face v2.3.48).
/// Communicates with native Android/iOS SDK via Platform Channel.
///
/// Integration steps:
/// 1. Download Android AAR from Alibaba Cloud console → android/app/libs/
/// 2. Download iOS Framework → link in Xcode
/// 3. Implement the native side in FaceVerifyPlugin.kt / FaceVerifyPlugin.swift
class FaceVerifyBridge {
  static const _channel = MethodChannel('com.chronoflow/face_verify');

  /// Initialize the face verification SDK.
  static Future<void> init() async {
    await _channel.invokeMethod('init');
  }

  /// Get device environment MetaInfo. Required by InitFaceVerify API.
  static Future<String> getMetaInfo() async {
    final result = await _channel.invokeMethod<String>('getMetaInfo');
    return result ?? '';
  }

  /// Launch face verification with the given certifyId.
  /// Returns a Map with: { 'passed': bool, 'message': String }.
  static Future<Map<String, dynamic>> verify(String certifyId) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'verify',
      {'certifyId': certifyId},
    );
    if (result == null) {
      return {'passed': false, 'message': '人脸认证失败'};
    }
    return {
      'passed': result['passed'] ?? false,
      'message': result['message'] ?? '',
    };
  }
}
