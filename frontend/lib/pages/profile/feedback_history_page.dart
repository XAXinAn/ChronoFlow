import 'dart:convert';
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../model/feedback_model.dart';
import '../../service/api_client.dart';
import '../../utils/message_utils.dart';
import '../../widgets/image_gallery_widget.dart';

/// 历史反馈列表页
class FeedbackHistoryPage extends StatefulWidget {
  const FeedbackHistoryPage({super.key});

  @override
  State<FeedbackHistoryPage> createState() => _FeedbackHistoryPageState();
}

class _FeedbackHistoryPageState extends State<FeedbackHistoryPage> {
  List<FeedbackModel>? _feedbacks;
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final response = await ApiClient.get('/feedback/my');
      final decoded = json.decode(response);

      List<dynamic> jsonList;
      if (decoded is List) {
        jsonList = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        jsonList = decoded['data'] as List<dynamic>? ?? [];
      } else {
        jsonList = [];
      }

      final list = jsonList
          .map((j) => FeedbackModel.fromJson(j as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _feedbacks = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = MessageUtils.cleanError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('反馈历史', style: TextStyle(fontWeight: FontWeight.w300)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_errorMsg != null) {
      return _buildErrorView();
    }

    if (_feedbacks == null || _feedbacks!.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _loadFeedbacks,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: _feedbacks!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildFeedbackCard(_feedbacks![index]),
      ),
    );
  }

  // ==================== 错误视图 ====================

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.black26),
          const SizedBox(height: 16),
          Text(_errorMsg!, style: const TextStyle(color: Colors.black38, fontSize: 14)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _loadFeedbacks,
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  // ==================== 空状态 ====================

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.feedback_outlined, size: 64, color: Colors.black.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          const Text('暂无反馈记录', style: TextStyle(fontSize: 16, color: Colors.black38)),
          const SizedBox(height: 8),
          const Text('您的反馈将帮助我们做得更好', style: TextStyle(fontSize: 13, color: Colors.black26)),
        ],
      ),
    );
  }

  // ==================== 反馈卡片 ====================

  Widget _buildFeedbackCard(FeedbackModel fb) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/feedback-detail', arguments: fb),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：类型标签 + 状态标签
            Row(
              children: [
                Flexible(child: _buildTypeChip(fb.type, fb.typeLabel)),
                const SizedBox(width: 10),
                Flexible(child: _buildStatusChip(fb.status, fb.statusLabel)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),

            // 第二行：内容摘要 + 图片缩略图
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    fb.content.length > 50 ? '${fb.content.substring(0, 50)}…' : fb.content,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fb.imageUrls.isNotEmpty) const SizedBox(width: 12),
                if (fb.imageUrls.isNotEmpty) _buildThumbnail(fb.imageUrls),
              ],
            ),
            const SizedBox(height: 12),

            // 第三行：提交时间
            Text(
              fb.createdAt ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.black26),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 类型标签 ----
  Widget _buildTypeChip(String type, String label) {
    final Color bgColor;
    final Color textColor;
    switch (type) {
      case 'bug':
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFC62828);
        break;
      case 'suggestion':
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        break;
      default:
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF616161);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis),
    );
  }

  // ---- 状态标签 ----
  Widget _buildStatusChip(String status, String label) {
    final Color bgColor;
    final Color textColor;
    switch (status) {
      case 'pending':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        break;
      case 'processing':
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        break;
      case 'resolved':
      case 'replied':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      default:
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF616161);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis),
    );
  }

  // ---- 缩略图 + 数量角标 ----
  Widget _buildThumbnail(List<String> imageUrls) {
    final firstUrl = imageUrls.first;
    final isNetwork = firstUrl.startsWith('http://') || firstUrl.startsWith('https://') || firstUrl.startsWith('/api/');
    final extraCount = imageUrls.length - 1;

    return GestureDetector(
      onTap: () {
        // 点击图片打开大图浏览
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageGalleryPage(imageUrls: imageUrls, initialIndex: 0),
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
              child: isNetwork
                  ? Image.network(
                      AppConstants.fullUrl(firstUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, s) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.broken_image, color: Colors.black26, size: 32),
                      ),
                    )
                  : Image.asset(
                      'assets/AppIcons/android/mipmap-xhdpi/ic_launcher.png',
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, s) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image, color: Colors.black26, size: 32),
                      ),
                    ),
            ),
          ),
          // 图片数量角标（红底白字圆形）
          if (extraCount > 0)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}