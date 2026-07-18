import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'cloud_page.dart';

/// 发现页 — MindFlow「发现 Tab」的默认展示页。
///
/// 两个卡片入口：
/// - AI学习系统 → ChatPage（统一对话界面）
/// - 我的云盘   → CloudPage（资源管理）
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // AI学习系统卡片
            _buildEntryCard(
              context,
              icon: Icons.auto_awesome,
              iconColor: const Color(0xFF6366F1),
              gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              title: 'AI学习系统',
              subtitle: '智能对话 · 资源生成 · 学情画像',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatPage()),
                );
              },
            ),

            const SizedBox(height: 20),

            // 我的云盘卡片
            _buildEntryCard(
              context,
              icon: Icons.cloud_outlined,
              iconColor: const Color(0xFF059669),
              gradient: const [Color(0xFF059669), Color(0xFF34D399)],
              title: '我的云盘',
              subtitle: '学习资源管理 · 按类型分类浏览',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudPage()),
                );
              },
            ),

            const SizedBox(height: 24),

            // 底部提示
            Center(
              child: Text(
                '所有AI生成内容仅供学习参考，请核实后使用',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.25),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 构建功能入口卡片
  Widget _buildEntryCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required List<Color> gradient,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}