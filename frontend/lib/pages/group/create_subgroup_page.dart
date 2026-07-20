import '../../constants/app_constants.dart';
import 'package:flutter/material.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';

class CreateSubgroupPage extends StatefulWidget {
  final String parentGroupId;
  final String parentGroupName;
  const CreateSubgroupPage({super.key, required this.parentGroupId, required this.parentGroupName});
  @override
  State<CreateSubgroupPage> createState() => _CreateSubgroupPageState();
}

class _CreateSubgroupPageState extends State<CreateSubgroupPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _descFocus = FocusNode();
  bool _nameFocused = false, _descFocused = false, _loading = false;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() => _nameFocused = _nameFocus.hasFocus));
    _descFocus.addListener(() => setState(() => _descFocused = _descFocus.hasFocus));
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _nameFocus.dispose(); _descFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { MessageUtils.show(context, '请输入子群组名称'); return; }
    setState(() => _loading = true);
    try {
      await GroupService().createSubgroupRequest(widget.parentGroupId, name, _descCtrl.text.trim());
      if (!mounted) return;
      MessageUtils.show(context, '申请已提交，请等待审核');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) MessageUtils.showError(context, e);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0, scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: AppConstants.primaryColor), onPressed: () => Navigator.pop(context)),
        title: const Text('申请创建子群组', style: TextStyle(color: AppConstants.primaryColor, fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5))
                : const Text('提交', style: TextStyle(color: AppConstants.primaryColor, fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 24), children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.account_tree, size: 16, color: Colors.blue.shade400),
            const SizedBox(width: 8),
            Expanded(child: Text('在 "${widget.parentGroupName}" 下创建子群组', style: TextStyle(fontSize: 13, color: Colors.blue.shade700))),
          ]),
        ),
        const SizedBox(height: 40),
        _buildField(_nameCtrl, _nameFocus, '子群组名称', _nameFocused),
        const SizedBox(height: 32),
        _buildField(_descCtrl, _descFocus, '描述（选填）', _descFocused, maxLines: 3),
      ]),
    );
  }

  Widget _buildField(TextEditingController ctrl, FocusNode focus, String hint, bool focused, {int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: ctrl, focusNode: focus, maxLines: maxLines,
        style: TextStyle(color: AppConstants.primaryColor, fontSize: 18, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: AppConstants.mediumGray, fontSize: 18, fontWeight: FontWeight.w500),
          border: InputBorder.none, enabledBorder: InputBorder.none,
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.primaryColor, width: 1)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
      Container(height: 0.5, color: AppConstants.lightGray),
    ]);
  }
}
