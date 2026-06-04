import '../../constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/schedule_model.dart';
import '../../model/group_model.dart';
import '../../service/schedule_service.dart';
import '../../service/calendar_service.dart';
import '../../utils/message_utils.dart';
import 'select_publish_target_page.dart';

/// 新建日程页面 - 黑白极简风格
/// 无彩色、无阴影、大面积留白、极简设计
class AddSchedulePage extends StatefulWidget {
  final Schedule? schedule;
  final Function(Schedule)? onScheduleAdded;
  final Function(Schedule)? onScheduleUpdated;
  final DateTime? initialDate;
  final bool canEdit;

  const AddSchedulePage({
    super.key,
    this.schedule,
    this.onScheduleAdded,
    this.onScheduleUpdated,
    this.initialDate,
    this.canEdit = true,
  });

  @override
  State<AddSchedulePage> createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;
  Group? _selectedGroup;
  bool _isPersonal = true;
  bool _syncToCalendar = false;

  bool get isEdit => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.schedule?.title ?? '';
    _descController.text = widget.schedule?.description ?? '';
    _locationController.text = widget.schedule?.location ?? '';

    if (widget.schedule != null) {
      _selectedDate = widget.schedule!.time;
      _selectedTime = TimeOfDay(hour: widget.schedule!.time.hour, minute: widget.schedule!.time.minute);
      if (widget.schedule!.isGroupSchedule) {
        _isPersonal = false;
        _selectedGroup = Group(
          id: widget.schedule!.groupId!,
          name: widget.schedule!.groupName!,
          description: '',
          inviteCode: '',
          memberCount: 0,
          creatorId: 0,
          createdAt: DateTime.now(),
          requireApproval: false,
        );
      }
    } else {
      final now = DateTime.now();
      _selectedDate = widget.initialDate ?? now;
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _selectPublishTarget() async {
    final result = await Navigator.push<Group?>(
      context,
      MaterialPageRoute(builder: (context) => const SelectPublishTargetPage()),
    );
    setState(() {
      if (result == null) {
        _selectedGroup = null;
        _isPersonal = true;
      } else {
        _selectedGroup = result;
        _isPersonal = false;
      }
    });
  }

  Future<void> _save() async {
    // 校验标题不为空
    if (_titleController.text.trim().isEmpty) {
      MessageUtils.show(context, '请输入标题');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_selectedTime == null) {
        if (mounted) MessageUtils.show(context, '请选择时间');
        return;
      }
      final dateTime = _combineDateAndTime(_selectedDate, _selectedTime!);
      Schedule? savedSchedule;

      if (isEdit) {
        savedSchedule = await ScheduleService().updateSchedule(
          id: widget.schedule!.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          location: _locationController.text.trim(),
          time: dateTime,
          groupId: _isPersonal ? null : _selectedGroup?.id,
        );
        widget.onScheduleUpdated?.call(savedSchedule);
      } else {
        if (_isPersonal) {
          savedSchedule = await ScheduleService().createSchedule(
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            location: _locationController.text.trim(),
            time: dateTime,
          );
          widget.onScheduleAdded?.call(savedSchedule);
        } else {
          savedSchedule = await ScheduleService().createGroupSchedule(
            groupId: _selectedGroup!.id,
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            location: _locationController.text.trim(),
            time: dateTime,
          );
          widget.onScheduleAdded?.call(savedSchedule);
        }
      }

      // 如果需要同步到系统日历
      if (_syncToCalendar) {
        final calendarService = CalendarService();
        await calendarService.exportSchedule(savedSchedule);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        MessageUtils.show(context, '保存失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportSchedule() async {
    if (widget.schedule == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 48, color: Colors.black54),
              const SizedBox(height: 16),
              const Text(
                '导出到系统日历',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                '确定要将 "${widget.schedule!.title}" 导出到手机系统日历吗？',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.black12),
                        ),
                      ),
                      child: const Text('取消', style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('确定', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final calendarService = CalendarService();
    final success = await calendarService.exportSchedule(widget.schedule!);

    if (mounted) {
      final overlay = Overlay.of(context);
      final entry = OverlayEntry(
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              success ? '已导出到系统日历' : '导出失败，请检查日历权限',
              style: const TextStyle(color: Colors.white, fontSize: 14, decoration: TextDecoration.none, decorationColor: Colors.transparent),
            ),
          ),
        ),
      );
      overlay.insert(entry);
      Future.delayed(const Duration(seconds: 2), () => entry.remove());
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppConstants.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? '编辑日程' : '新建日程',
          style: const TextStyle(
            color: AppConstants.primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.ios_share, color: AppConstants.primaryColor),
              onPressed: _exportSchedule,
            ),
          if (widget.canEdit)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Text(
                      '保存',
                      style: TextStyle(
                        color: AppConstants.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 40),

            // 发布到选择
            _buildPublishTargetSelector(),

            const SizedBox(height: 32),

            // 日程标题 - 仅底部1px线，无背景
            _buildTextField(
              controller: _titleController,
              hintText: '日程标题',
              hintColor: AppConstants.mediumGray,
              textColor: AppConstants.primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),

            const SizedBox(height: 32),

            // 描述 - 多行，仅底部1px线，无背景
            _buildTextField(
              controller: _descController,
              hintText: '添加描述（选填）',
              hintColor: AppConstants.mediumGray,
              textColor: AppConstants.darkGray,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // 日期选择 - 左侧黑字，右侧深灰值+黑色箭头，底部1px线
            _buildSelectItem(
              label: '日期',
              value: _formatDate(_selectedDate),
              onTap: _selectDate,
            ),

            const SizedBox(height: 24),

            // 时间选择 - 左侧黑字，右侧深灰值+黑色箭头，底部1px线
            _buildSelectItem(
              label: '时间',
              value: _selectedTime != null ? _formatTime(_selectedTime!) : '选择时间',
              onTap: _selectTime,
            ),

            const SizedBox(height: 24),

            // 地点 - 左侧黑白图标，仅底部1px线
            _buildTextField(
              controller: _locationController,
              hintText: '地点（选填）',
              hintColor: AppConstants.mediumGray,
              textColor: AppConstants.darkGray,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppConstants.primaryColor, size: 20),
            ),

            const SizedBox(height: 24),

            // 同步到系统日历开关（仅新建时显示，编辑时不显示）
            if (!isEdit) _buildCalendarSyncToggle(),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  /// 文本输入框 - 透明背景，仅底部1px细线
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Color hintColor,
    required Color textColor,
    required double fontSize,
    required FontWeight fontWeight,
    int maxLines = 1,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: !widget.canEdit,
          style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: fontWeight),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor, fontSize: fontSize, fontWeight: fontWeight),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppConstants.primaryColor, width: 1),
            ),
            prefixIcon: prefixIcon,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        // 底部1px细线
        Container(height: 0.5, color: AppConstants.lightGray),
      ],
    );
  }

  /// 选择项 - 左侧标签黑字，右侧值深灰+箭头，底部1px线
  Widget _buildSelectItem({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final bool isPlaceholder = value == '选择时间';
    return GestureDetector(
      onTap: widget.canEdit ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppConstants.primaryColor, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: isPlaceholder ? AppConstants.mediumGray : AppConstants.darkGray,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppConstants.primaryColor, size: 20),
              ],
            ),
          ),
          // 底部1px细线
          Container(height: 0.5, color: AppConstants.lightGray),
        ],
      ),
    );
  }

  Widget _buildPublishTargetSelector() {
    final isGroup = _selectedGroup != null;
    return GestureDetector(
      onTap: _selectPublishTarget,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '发布到',
                  style: TextStyle(color: AppConstants.primaryColor, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '点击可将日程发布到群组',
                style: TextStyle(color: AppConstants.mediumGray, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: isGroup ? AppConstants.blue : AppConstants.lightGray),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isGroup ? Icons.group : Icons.person,
                  color: isGroup ? AppConstants.blue : AppConstants.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isGroup ? _selectedGroup!.name : '个人日程',
                    style: TextStyle(
                      color: isGroup ? AppConstants.blue : AppConstants.primaryColor,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppConstants.primaryColor, size: 20),
              ],
            ),
          ),
          Container(height: 0.5, color: AppConstants.lightGray, margin: const EdgeInsets.only(top: 12)),
        ],
      ),
    );
  }

  /// 日历同步复选框
  Widget _buildCalendarSyncToggle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppConstants.primaryColor, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '同步到系统日历',
                    style: TextStyle(color: AppConstants.primaryColor, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                Checkbox(
                  value: _syncToCalendar,
                  onChanged: widget.canEdit ? (v) => setState(() => _syncToCalendar = v ?? false) : null,
                  activeColor: Colors.black,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: AppConstants.lightGray),
        ],
      ),
    );
  }
}