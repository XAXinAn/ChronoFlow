import 'dart:io' show Platform;
import 'package:flutter/material.dart';

/// 应用常量配置
class AppConstants {
  // API 配置 - 通过 --dart-define=BASE_URL=... 在构建时切换
  // 模拟器：自动使用 10.0.2.2 访问宿主机
  // 真机调试：--dart-define=BASE_URL=http://192.168.x.x:8080/api
  static String get baseUrl {
    const configured = String.fromEnvironment('BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (Platform.isAndroid) return 'http://10.0.2.2:8080/api';
    return 'http://localhost:8080/api';
  }

  // 主题色 - 黑白极简风格
  static const Color primaryColor = Color(0xFF000000);         // 黑色
  static const Color onPrimaryColor = Color(0xFFFFFFFF);      // 白色
  static const Color surfaceColor = Color(0xFFFFFFFF);        // 白色
  static const Color onSurfaceColor = Color(0xFF000000);       // 黑色
  static const Color backgroundColor = Color(0xFFFFFFFF);      // 白色
  static const Color appBarBackgroundColor = Color(0xFFFFFFFF); // 白色

  // 灰色系
  static const Color darkGray = Color(0xFF333333);
  static const Color mediumGray = Color(0xFF999999);
  static const Color lightGray = Color(0xFFCCCCCC);
  static const Color borderGray = Color(0xFFDDDDDD);
  static const Color dividerGray = Color(0xFFEEEEEE);
  static const Color placeholderGray = Color(0xFF666666);

  // 蓝 色（用于群组/特殊状态）
  static const Color blue = Color(0xFF2196F3);

  // 错误/危险色
  static const Color errorColor = Color(0xFFF44336);
  static const Color dangerColor = Color(0xFFFF5252);

  // 间距
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 12.0;
  static const double paddingL = 16.0;
  static const double paddingXL = 24.0;
  static const double paddingXXL = 32.0;

  // 圆角
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;

  // 字体大小
  static const double fontSizeXS = 12.0;
  static const double fontSizeS = 14.0;
  static const double fontSizeM = 15.0;
  static const double fontSizeL = 16.0;
  static const double fontSizeXL = 18.0;
  static const double fontSizeXXL = 20.0;

  // 边框高度
  static const double borderWidth = 0.5;
}