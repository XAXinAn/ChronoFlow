import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';


class ImageGalleryPage extends StatefulWidget {
  /// 图片路径列表
  final List<String> imageUrls;

  /// 初始展示第几张（从 0 开始）
  final int initialIndex;

  const ImageGalleryPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: total > 1
            ? Text('${_currentIndex + 1} / $total',
                style: const TextStyle(fontSize: 16))
            : const Text(''),
        centerTitle: true,
      ),
      body: total == 0
          ? const Center(
              child: Text('暂无图片', style: TextStyle(color: Colors.white54, fontSize: 16)),
            )
          : PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return _buildImagePage(widget.imageUrls[index]);
              },
            ),
    );
  }

  /// 构建单张可缩放图片页面
  Widget _buildImagePage(String url) {
    final bool isNetwork = url.startsWith('http://') || url.startsWith('https://') || url.startsWith('/api/');

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: isNetwork
            ? Image.network(
                AppConstants.fullUrl(url),
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  final progress = loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  );
                },
                errorBuilder: (ctx, error, stack) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white38, size: 64),
                      SizedBox(height: 12),
                      Text('图片加载失败', style: TextStyle(color: Colors.white38, fontSize: 14)),
                    ],
                  ),
                ),
              )
            : Image.file(
                File(url),
                fit: BoxFit.contain,
                errorBuilder: (ctx, error, stack) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white38, size: 64),
                      SizedBox(height: 12),
                      Text('图片加载失败', style: TextStyle(color: Colors.white38, fontSize: 14)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}