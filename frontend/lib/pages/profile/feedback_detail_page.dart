import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../model/feedback_model.dart';
import '../../service/api_client.dart';
import '../../widgets/image_gallery_widget.dart';

/// 反馈详情页
class FeedbackDetailPage extends StatefulWidget {
  final dynamic feedback;

  const FeedbackDetailPage({super.key, required this.feedback});

  @override
  State<FeedbackDetailPage> createState() => _FeedbackDetailPageState();
}

class _FeedbackDetailPageState extends State<FeedbackDetailPage> {
  late FeedbackModel _feedback;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _feedback = _parseArgument();
    // 从 API 刷新获取最新数据（可能有新的管理员回复）
    _refreshFromApi();
  }

  /// 解析路由参数
  FeedbackModel _parseArgument() {
    final arg = widget.feedback;
    if (arg is FeedbackModel) return arg;
    if (arg is Map<String, dynamic>) return FeedbackModel.fromJson(arg);
    throw ArgumentError('Invalid feedback argument: $arg');
  }

  Future<void> _refreshFromApi() async {
    if (_feedback.id == 0) return;

    setState(() => _isRefreshing = true);
    try {
      final response = await ApiClient.get('/feedback/${_feedback.id}');
      final decoded = convert.json.decode(response) as Map<String, dynamic>;
      final data = (decoded['data'] as Map<String, dynamic>?) ?? decoded;

      if (!mounted) return;
      setState(() {
        _feedback = FeedbackModel.fromJson(data);
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      // 静默失败，使用传入的旧数据
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('反馈详情', style: TextStyle(fontWeight: FontWeight.w300)),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black45),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 状态 + 类型 ----
            _buildHeader(),
            const SizedBox(height: 24),

            // ---- 反馈内容 ----
            _buildSectionLabel('反馈内容'),
            const SizedBox(height: 12),
            _buildContentCard(),
            const SizedBox(height: 24),

            // ---- 图片 ----
            if (_feedback.imageUrls.isNotEmpty) ...[
              _buildSectionLabel('截图附件'),
              const SizedBox(height: 12),
              _buildImageGallery(),
              const SizedBox(height: 24),
            ],

            // ---- 管理员回复 ----
            _buildSectionLabel('管理员回复'),
            const SizedBox(height: 12),
            _buildReplyCard(),
          ],
        ),
      ),
    );
  }

  // ==================== 头部：状态 + 类型 + 时间 ====================

  Widget _buildHeader() {
    return Row(
      children: [
        Flexible(flex: 3, child: _buildStatusBadge()),
        const SizedBox(width: 8),
        Flexible(flex: 2, child: _buildTypeBadge()),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: Text(
            _formatTime(_feedback.createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.black38),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final color = _statusColor(_feedback.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _feedback.statusLabel,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _feedback.typeLabel,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  // ==================== 反馈内容卡片 ====================

  Widget _buildContentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        _feedback.content,
        style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
      ),
    );
  }

  // ==================== 图片横向滚动 ====================

  Widget _buildImageGallery() {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _feedback.imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index < _feedback.imageUrls.length - 1 ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageGalleryPage(
                      imageUrls: _feedback.imageUrls,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        AppConstants.fullUrl(_feedback.imageUrls[index]),
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (ctx, e, s) => Container(
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.broken_image, color: Colors.black26, size: 32),
                        ),
                      ),
                    ),
                  ),
                  // 多图时显示角标序号
                  if (_feedback.imageUrls.length > 1)
                    Positioned(
                      right: 3,
                      bottom: 3,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== 管理员回复卡片 ====================

  Widget _buildReplyCard() {
    final reply = _feedback.adminReply;

    // 无回复
    if (reply == null || reply.trim().isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Icon(Icons.mark_email_unread_outlined, size: 36, color: Colors.black.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            const Text('暂无回复', style: TextStyle(fontSize: 14, color: Colors.black38)),
            const SizedBox(height: 4),
            const Text('管理员回复后会在此显示', style: TextStyle(fontSize: 12, color: Colors.black26)),
          ],
        ),
      );
    }

    // 有回复
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent, size: 18, color: Colors.black54),
              const SizedBox(width: 8),
              const Text(
                '管理员回复',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
              const Spacer(),
              if (_feedback.updatedAt != null)
                Text(
                  _formatTime(_feedback.updatedAt),
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reply,
            style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ==================== 辅助方法 ====================

  Widget _buildSectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFE65100);
      case 'processing':
        return const Color(0xFF1565C0);
      case 'resolved':
      case 'replied':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF757575);
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }
}