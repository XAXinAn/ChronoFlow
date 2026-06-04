import 'package:flutter/material.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

class ChangeGroupNamePage extends StatefulWidget {
  final String groupId;
  final String currentName;

  const ChangeGroupNamePage({
    super.key,
    required this.groupId,
    required this.currentName,
  });

  @override
  State<ChangeGroupNamePage> createState() => _ChangeGroupNamePageState();
}

class _ChangeGroupNamePageState extends State<ChangeGroupNamePage> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentName;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      MessageUtils.show(context, '请输入群名称');
      return;
    }
    if (name.length > 100) {
      MessageUtils.show(context, '群名称不能超过100个字符');
      return;
    }
    if (name == widget.currentName) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    try {
      await GroupService().updateGroupName(widget.groupId, name);
      if (!mounted) return;
      MessageUtils.show(context, '修改成功');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, name);
    } catch (e) {
      if (mounted) MessageUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改群名称', style: TextStyle(fontWeight: FontWeight.w300)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              const Text(
                '修改群名称',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w200),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '当前名称：${widget.currentName}',
                style: const TextStyle(fontSize: 12, color: Colors.black38),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _controller,
                maxLength: 20,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: '群名称',
                  hintStyle: const TextStyle(color: Colors.black26),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 64),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('保存'),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}
