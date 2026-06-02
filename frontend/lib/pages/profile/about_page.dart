import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于', style: TextStyle(fontWeight: FontWeight.w300)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: const DecorationImage(
                        image: AssetImage('assets/AppIcons/android/mipmap-xhdpi/ic_launcher.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '时纪流',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '版本 1.0.0',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            _buildSection('产品介绍', '时纪流是一款简洁高效的个人日程管理应用，支持日历视图、群组共享、智能识别等功能。'),
            const SizedBox(height: 24),
            _buildSection('主要功能', '• 日历视图，直观展示日程\n• 拍照识别，自动解析日程\n• 群组共享，协同安排\n• 多端同步，数据安全'),
            const SizedBox(height: 24),
            _buildSection('联系我们', '邮箱：3278904650@qq.com\n电话：18006569106'),
            const SizedBox(height: 48),
            const Center(
              child: Text(
                '© 2026 时纪流 All Rights Reserved',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
        ),
      ],
    );
  }
}
