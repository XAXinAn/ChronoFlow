import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../constants/app_constants.dart';
import '../../service/api_client.dart';
import '../../service/secure_storage_service.dart';
import '../../utils/message_utils.dart';
import '../../widgets/image_gallery_widget.dart';

/// 意见反馈表单页
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  // ---- 表单状态 ----
  String? _selectedType;
  final _contentController = TextEditingController();
  final List<XFile> _images = [];
  bool _isSubmitting = false;

  // ---- 常量 ----
  static const _feedbackTypes = [
    {'value': 'bug', 'label': '问题反馈', 'icon': Icons.bug_report_outlined},
    {'value': 'suggestion', 'label': '功能建议', 'icon': Icons.lightbulb_outline},
    {'value': 'other', 'label': '其他', 'icon': Icons.more_horiz},
  ];
  static const int _minLength = 10;
  static const int _maxLength = 500;
  static const int _maxImages = 5;

  final ImagePicker _picker = ImagePicker();
  final SecureStorageService _storage = SecureStorageService();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // ==================== 图片选择 ====================

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      MessageUtils.show(context, '最多上传$_maxImages张图片');
      return;
    }

    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        limit: remaining,
      );
      if (picked.isNotEmpty) {
        setState(() => _images.addAll(picked));
      }
    } catch (e) {
      MessageUtils.showError(context, '图片选择失败: ${MessageUtils.cleanError(e)}');
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _viewImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageGalleryPage(
          imageUrls: _images.map((f) => f.path).toList(),
          initialIndex: index,
        ),
      ),
    );
  }

  // ==================== 表单校验 ====================

  bool get _canSubmit =>
      _selectedType != null && _contentController.text.trim().length >= _minLength && !_isSubmitting;

  // ==================== 上传图片 ====================

  Future<List<String>> _uploadImages() async {
    if (_images.isEmpty) return [];

    final token = await _storage.getAccessToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/feedback/upload');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    for (final img in _images) {
      request.files.add(await http.MultipartFile.fromPath('files', img.path));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final urls = (data['urls'] as List).cast<String>();
      return urls;
    } else {
      String msg = '图片上传失败';
      try {
        final body = jsonDecode(response.body);
        msg = body['message'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  // ==================== 提交反馈 ====================

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. 先批量上传图片获取 URL 数组
      List<String> imageUrls;
      try {
        imageUrls = await _uploadImages();
      } catch (e) {
        if (!mounted) return;
        MessageUtils.showError(context, e);
        setState(() => _isSubmitting = false);
        return;
      }

      // 2. 提交反馈表单
      final body = {
        'type': _selectedType,
        'content': _contentController.text.trim(),
        'imageUrls': imageUrls,
      };
      await ApiClient.post('/feedback', body: body);

      if (!mounted) return;
      // 3. 成功提示并回退
      MessageUtils.showSuccess(context, '感谢您的反馈！');

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (!mounted) return;
      MessageUtils.showError(context, e);
      setState(() => _isSubmitting = false);
    }
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('意见反馈', style: TextStyle(fontWeight: FontWeight.w300)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/feedback-history'),
            child: const Text('历史', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- 反馈类型 ----
                  _buildSectionLabel('反馈类型'),
                  const SizedBox(height: 12),
                  _buildTypeSelector(),
                  const SizedBox(height: 28),

                  // ---- 反馈内容 ----
                  _buildSectionLabel('详细描述'),
                  const SizedBox(height: 12),
                  _buildContentInput(),
                  const SizedBox(height: 28),

                  // ---- 截图上传 ----
                  _buildSectionLabel('上传截图（选填）'),
                  const SizedBox(height: 12),
                  _buildImageArea(),
                ],
              ),
            ),
          ),

          // ---- 提交按钮 ----
          _buildBottomButton(),
        ],
      ),
    );
  }

  // ---- 区块标题 ----
  Widget _buildSectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54));
  }

  // ---- 反馈类型选择（三等分按钮组） ----
  Widget _buildTypeSelector() {
    return Row(
      children: _feedbackTypes.map((t) {
        final selected = _selectedType == t['value'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: t == _feedbackTypes.first ? 0 : 6,
              right: t == _feedbackTypes.last ? 0 : 6,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = t['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? Colors.black : Colors.black12,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 22,
                      color: selected ? Colors.white : Colors.black54,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---- 反馈内容输入框 ----
  Widget _buildContentInput() {
    final length = _contentController.text.length;
    final bool showWarning = length > 0 && length < _minLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _contentController,
            maxLines: 6,
            maxLength: _maxLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '请详细描述您遇到的问题或建议…',
              hintStyle: TextStyle(color: Colors.black26, fontSize: 15),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (showWarning)
              const Text('至少输入$_minLength字', style: TextStyle(color: Colors.red, fontSize: 12)),
            const Spacer(),
            Text(
              '$length/$_maxLength',
              style: TextStyle(
                fontSize: 12,
                color: length > _maxLength * 0.9 ? Colors.red : Colors.black38,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- 图片上传区域 ----
  Widget _buildImageArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图片横向滚动列表
        if (_images.isNotEmpty)
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, index) => _buildImageThumb(index),
            ),
          ),

        const SizedBox(height: 12),

        // 添加按钮 / 上限提示
        if (_images.length < _maxImages)
          _buildAddButton()
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            width: double.infinity,
            child: const Text('最多上传$_maxImages张图片', style: TextStyle(color: Colors.black38, fontSize: 13)),
          ),
      ],
    );
  }

  // ---- 单张图片缩略图 ----
  Widget _buildImageThumb(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _viewImage(index),
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
                child: Image.file(
                  File(_images[index].path),
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, s) => Container(
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image, color: Colors.black26, size: 32),
                  ),
                ),
              ),
            ),
            // 删除按钮
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 添加图片按钮（虚线边框） ----
  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black26, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '点击添加截图（最多$_maxImages张）',
                style: const TextStyle(color: Colors.black54, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 底部提交按钮 ----
  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            disabledBackgroundColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('提交反馈', style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ),
    );
  }
}