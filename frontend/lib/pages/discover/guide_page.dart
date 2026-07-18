import 'package:flutter/material.dart';

/// 使用指导页 — 静态说明MindFlow各功能的使用方法和示例指令。
///
/// 从对话界面右上角帮助图标进入。
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用指导', style: TextStyle(fontWeight: FontWeight.w300)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MindFlow 使用指南',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI驱动的个性化学习助手，帮助你高效学习',
              style: TextStyle(fontSize: 14, color: Colors.black45),
            ),
            const SizedBox(height: 28),

            // 功能1：资源生成
            _buildGuideSection(
              icon: Icons.auto_awesome,
              color: const Color(0xFF6366F1),
              title: '学习资源生成',
              description: '输入知识点，AI自动生成五类学习资源：讲解文档、思维导图、练习题、拓展材料、代码案例。',
              examples: const [
                '帮我生成机器学习决策树的学习资料',
                '生成Python装饰器的练习题',
                '解释神经网络的原理',
              ],
            ),

            // 功能2：学情画像
            _buildGuideSection(
              icon: Icons.analytics_outlined,
              color: const Color(0xFFF59E0B),
              title: '学习画像测评',
              description: '通过多轮对话评估你的六维学习画像：知识基础、认知风格、薄弱点、学习节奏、兴趣方向、易错类型。',
              examples: const [
                '开始学情测评',
                '查看我的画像',
                '更新学习画像',
              ],
            ),

            // 功能3：智能答疑
            _buildGuideSection(
              icon: Icons.question_answer_outlined,
              color: const Color(0xFF059669),
              title: '智能答疑',
              description: '提出学习中的疑问，AI将分步讲解并提供图解。基于知识库检索确保回答准确。',
              examples: const [
                '什么是过拟合？如何防止？',
                'SVM和决策树有什么区别？',
                '解释梯度下降的原理',
              ],
            ),

            // 功能4：云盘管理
            _buildGuideSection(
              icon: Icons.cloud_outlined,
              color: const Color(0xFF3B82F6),
              title: '资源云盘',
              description: '生成的资源自动归档到云盘，按类型分文件夹管理。支持查看、浏览历史生成的所有学习资料。',
              examples: const [
                '通过"发现→我的云盘"进入',
                '5个文件夹：文档/导图/习题/材料/代码',
                '点击资源卡片查看完整内容',
              ],
            ),

            const SizedBox(height: 24),

            // 注意事项
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.amber),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '使用须知',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• 所有AI生成内容均标注"AI生成"标识\n'
                          '• 重要知识点建议核实后使用\n'
                          '• 每日资源生成次数有限制（默认30次/天）\n'
                          '• 连续对话会累积上下文，建议适时新建对话',
                          style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required List<String> examples,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 10),
          // 示例指令
          ...examples.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '→ $e',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          )),
        ],
      ),
    );
  }
}