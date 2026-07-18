import 'dart:async';
import 'package:flutter/material.dart';
import '../../model/chat_model.dart';
import '../../service/chat_service.dart';
import '../../utils/message_utils.dart';
import 'guide_page.dart';

/// 对话页面 — MindFlow 的统一对话界面。
///
/// 核心功能：
/// - SSE流式渲染AI回复（逐字追加）
/// - 多消息类型内联展示（文本/画像卡片/资源卡片/进度/错误）
/// - 输入框 + 发送按钮
/// - 会话管理（新建对话）
/// - 使用指导入口（右上角图标）
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _sessionId;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _currentAiText = '';
  String? _progressText;
  double _progressPercent = 0;

  @override
  void dispose() {
    _chatService.cancelCurrentStream();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 发送消息
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // 添加用户消息到列表
    setState(() {
      _messages.insert(0, ChatMessage.user(text));
      _isLoading = true;
      _currentAiText = '';
      _progressText = null;
      _progressPercent = 0;
    });
    _inputController.clear();
    _scrollToTop();

    // 订阅SSE流
    _chatService.sendMessage(
      message: text,
      sessionId: _sessionId,
      onSessionCreated: (sid) {
        setState(() => _sessionId = sid);
      },
    ).listen(
      (event) {
        _handleSseEvent(event);
      },
      onError: (e) {
        setState(() {
          _isLoading = false;
          _currentAiText = '';
        });
        if (mounted) {
          MessageUtils.show(context, '连接失败: $e');
        }
      },
      onDone: () {
        // 将累积的AI文本保存为消息
        if (_currentAiText.isNotEmpty) {
          setState(() {
            _messages.insert(0, ChatMessage.assistant(_currentAiText));
            _currentAiText = '';
          });
        }
        setState(() => _isLoading = false);
      },
    );
  }

  /// 处理SSE事件
  void _handleSseEvent(SseEvent event) {
    setState(() {
      switch (event.type) {
        case 'TEXT':
          _currentAiText += event.content ?? '';
          _progressText = null;
          break;
        case 'PROGRESS':
          _progressText = event.content ?? event.stage;
          _progressPercent = event.percent;
          break;
        case 'RESOURCE_CARD':
          // 资源卡片作为特殊消息插入
          final cardContent = '📦 **${event.title ?? event.agent ?? "资源"}**\n\n${event.content ?? ""}';
          _messages.insert(0, ChatMessage.assistant(cardContent, messageType: 'RESOURCE_CARD'));
          break;
        case 'PROFILE_CARD':
          // 画像卡片作为特殊消息插入
          _messages.insert(0, ChatMessage.assistant(
            event.content ?? '画像数据',
            messageType: 'PROFILE_CARD',
          ));
          break;
        case 'ERROR':
          _messages.insert(0, ChatMessage.assistant(
            '❌ ${event.content ?? "发生错误"}',
            messageType: 'ERROR',
          ));
          break;
        case 'COMPLETE':
          _progressText = null;
          _progressPercent = 0;
          break;
      }
    });
    _scrollToTop();
  }

  /// 新建对话
  void _newChat() {
    _chatService.cancelCurrentStream();
    setState(() {
      _sessionId = null;
      _messages.clear();
      _currentAiText = '';
      _progressText = null;
      _isLoading = false;
    });
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI学习系统', style: TextStyle(fontWeight: FontWeight.w300)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, size: 22),
            tooltip: '使用指导',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GuidePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            tooltip: '新建对话',
            onPressed: _newChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // 进度条
          if (_progressText != null)
            Container(
              width: double.infinity,
              color: const Color(0xFF6366F1).withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _progressText!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6366F1)),
                    ),
                  ),
                  if (_progressPercent > 0)
                    Text(
                      '${(_progressPercent * 100).toInt()}%',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1)),
                    ),
                ],
              ),
            ),

          // 消息列表（倒序，最新在上）
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 48, color: Colors.black.withOpacity(0.15)),
                        const SizedBox(height: 16),
                        Text(
                          '开始你的学习之旅',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black.withOpacity(0.35),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '试试输入：帮我生成决策树的学习资料',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.25),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && _isLoading) {
                        return _buildLoadingBubble();
                      }
                      final msg = _messages[index - (_isLoading ? 1 : 0)];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          // 底部输入栏
          _buildInputBar(),
        ],
      ),
    );
  }

  /// 加载中的气泡（显示实时AI文本）
  Widget _buildLoadingBubble() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI头像
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentAiText.isNotEmpty)
                    Text(
                      _currentAiText,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    )
                  else
                    const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('思考中...', style: TextStyle(fontSize: 13, color: Colors.black38)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 消息气泡
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? Colors.black : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI生成标注（非用户消息）
                  if (!isUser)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'AI生成',
                        style: TextStyle(fontSize: 10, color: Color(0xFF6366F1)),
                      ),
                    ),
                  // 消息内容
                  Text(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 10),
          if (isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, size: 16, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  /// 底部输入栏
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '输入学习需求，如"生成决策树学习资料"...',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.black26),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isLoading ? Colors.black26 : Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_upward,
                  size: 20,
                  color: _isLoading ? Colors.white54 : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}