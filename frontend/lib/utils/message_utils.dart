import 'package:flutter/material.dart';

class MessageUtils {
  /// 显示通用提示（居中黑色半透明 toast，和注册成功保持一致）。
  static void show(BuildContext context, String msg) {
    try {
      final overlay = Overlay.of(context);
      final entry = OverlayEntry(
        builder: (_) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(msg,
                style: const TextStyle(color: Colors.white, fontSize: 14,
                    decoration: TextDecoration.none, decorationColor: Colors.transparent)),
          ),
        ),
      );
      overlay.insert(entry);
      Future.delayed(const Duration(seconds: 2), () => entry.remove());
    } catch (e) {
      debugPrint('MessageUtils.show failed: $e - message: $msg');
    }
  }

  /// 显示错误提示，自动去掉 "Exception: " 前缀。
  static void showError(BuildContext context, Object e) {
    String msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring(11);
    }
    show(context, msg);
  }

  /// 显示成功提示。
  static void showSuccess(BuildContext context, String msg) {
    show(context, msg);
  }

  /// 清理异常消息，去掉 "Exception: " 前缀，返回纯文本。
  static String cleanError(Object e) {
    String msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring(11);
    }
    return msg;
  }

  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black)),
              const SizedBox(height: 16),
              Text(content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.black12),
                        ),
                      ),
                      child: Text(cancelText,
                          style: const TextStyle(color: Colors.black54, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: isDangerous ? Colors.red : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(confirmText,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
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
}
