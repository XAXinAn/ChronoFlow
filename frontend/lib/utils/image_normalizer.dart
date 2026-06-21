import 'dart:io';
import 'package:flutter/services.dart';

/// 图片归一化工具。
///
/// iOS 默认以 HEIC 保存图片，而 Google ML Kit 在 iOS 上通过 `CGImageSource`
/// 读取 HEIC 时会失败（日志：`could not find plugin for image source`），
/// 导致 `processImage` 永不返回、界面卡死。
///
/// 这里在 iOS 侧用原生 `UIImage`（iOS 11+ 原生支持 HEIC 解码）将图片重新
/// 编码为 JPEG，再交给 ML Kit。Android 的 ML Kit 本身可处理 HEIC，直接返回原路径。
class ImageNormalizer {
  static const _channel = MethodChannel('com.chronoflow/image_util');

  /// 将 [path] 指向的图片转换为 ML Kit 可识别的 8-bit JPEG，返回**可安全喂给
  /// ML Kit 的文件路径**；若无法识别该图片，返回 `null`。
  ///
  /// - Android：ML Kit 自带解码，直接返回原路径。
  /// - iOS：原生重编码为 8-bit JPEG（处理 10-bit HDR HEIC）。
  ///   一旦失败**返回 null**，调用方必须跳过此图——绝不能把原始 HEIC 路径喂给
  ///   ML Kit，否则原生 `filePathToVisionImage:` 读图得 nil 会抛 `MLKInvalidImage`
  ///   异常直接 crash 整个 App（Dart 的 try/catch 拦不住原生 NSException）。
  static Future<String?> toJpeg(String path) async {
    if (!Platform.isIOS) return path;
    try {
      final result = await _channel
          .invokeMethod<String>('toJpeg', {'path': path})
          .timeout(const Duration(seconds: 15));
      return (result != null && result.isNotEmpty) ? result : null;
    } catch (_) {
      // MissingPluginException / 超时 / 原生解码失败 —— 跳过此图，避免崩溃
      return null;
    }
  }
}
