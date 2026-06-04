import '../../constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/schedule_model.dart';
import '../../model/group_model.dart';
import '../../service/schedule_service.dart';
import '../../service/calendar_service.dart';
import '../../utils/message_utils.dart';
import 'select_publish_target_page.dart';
import 'select_publish_targets_page.dart';

/// 创建日程页面（支持个人/群组）
class AddGroupSchedulePage extends StatefulWidget {
  final Function(Schedule)? onScheduleAdded;
  final DateTime? initialDate;

  const AddGroupSchedulePage({
    super.key,
    this.onScheduleAdded,
    this.initialDate,
  });

  @override
  State<AddGroupSchedulePage> createState() => _AddGroupSchedulePageState();
}

class _AddGroupSchedulePageState extends State<AddGroupSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;
  Group? _selectedGroup;
  bool _syncToCalendar = false;
  List<String> _publishTargetIds = [];


  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedTime = TimeOfDay.now();
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
      _selectedGroup = result; // null = personal, Group object = group
    });
  }

  Future<void> _save() async {
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

      Schedule schedule;

      if (_selectedGroup == null) {
        // 个人日程
        schedule = await ScheduleService().createSchedule(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          location: _locationController.text.trim(),
          time: dateTime,
        );
      } else {
        // 群组日程
        schedule = await ScheduleService().createGroupSchedule(
          groupId: _selectedGroup!.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          location: _locationController.text.trim(),
          time: dateTime,
          publishTargetGroupIds: _publishTargetIds.isEmpty ? null : _publishTargetIds,
        );
      }

      widget.onScheduleAdded?.call(schedule);

      // 如果需要同步到系统日历
      if (_syncToCalendar) {
        final calendarService = CalendarService();
        await calendarService.exportSchedule(schedule);
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
        title: const Text(
          '创建日程',
          style: TextStyle(
            color: AppConstants.primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
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
                      color: AppConstants.blue,
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
                  // 下发范围
                  _buildPublishTargetsSection(),

                  const SizedBox(height: 32),

                      // 日程标题
                      _buildTextField(
                        controller: _titleController,
                        hintText: '日程标题',
                        hintColor: AppConstants.mediumGray,
                        textColor: AppConstants.primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),

                      const SizedBox(height: 32),

                      // 描述
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

                      // 日期选择
                      _buildSelectItem(
                        label: '日期',
                        value: _formatDate(_selectedDate),
                        onTap: _selectDate,
                      ),

                      const SizedBox(height: 24),

                      // 时间选择
                      _buildSelectItem(
                        label: '时间',
                        value: _selectedTime != null ? _formatTime(_selectedTime!) : '选择时间',
                        onTap: _selectTime,
                      ),

                      const SizedBox(height: 24),

                      // 地点
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

                      // 同步到系统日历开关
                      _buildCalendarSyncToggle(),

                      const SizedBox(height: 60),
                    ],
                  ),
                ),
    );
  }

  Future<void> _selectPublishTargets() async {
    if (_selectedGroup == null) return;
    final result = await Navigator.push<List<String>>(context,
      MaterialPageRoute(builder: (_) => SelectPublishTargetsPage(
        rootGroupId: _selectedGroup!.id, rootGroupName: _selectedGroup!.name)));
    if (result != null && mounted) setState(() => _publishTargetIds = result);
  }

  Widget _buildPublishTargetsSection() {
    if (_selectedGroup == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 0.5, color: AppConstants.lightGray, margin: const EdgeInsets.only(bottom: 12)),
      GestureDetector(
        onTap: _selectPublishTargets,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(border: Border.all(color: AppConstants.lightGray), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.share, size: 20, color: AppConstants.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(
              _publishTargetIds.isEmpty ? '下发范围：仅本群' : '下发范围：本群 + ${_publishTargetIds.length} 个子群',
              style: TextStyle(color: AppConstants.primaryColor, fontSize: 15))),
            const Icon(Icons.chevron_right, color: AppConstants.primaryColor, size: 20),
          ]),
        ),
      ),
      Container(height: 0.5, color: AppConstants.lightGray, margin: const EdgeInsets.only(top: 12)),
    ]);
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
              border: Border.all(color: isGroup ? Colors.blue : AppConstants.lightGray),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isGroup ? Icons.group : Icons.person,
                  color: isGroup ? Colors.blue : AppConstants.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isGroup ? _selectedGroup!.name : '个人日程',
                    style: TextStyle(
                      color: isGroup ? Colors.blue : AppConstants.primaryColor,
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
          style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: fontWeight),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: hintColor, fontSize: fontSize, fontWeight: fontWeight),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppConstants.blue, width: 1),
            ),
            prefixIcon: prefixIcon,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        Container(height: 0.5, color: AppConstants.lightGray),
      ],
    );
  }

  Widget _buildSelectItem({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final bool isPlaceholder = value == '选择时间';
    return GestureDetector(
      onTap: onTap,
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
          Container(height: 0.5, color: AppConstants.lightGray),
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
                  onChanged: (v) => setState(() => _syncToCalendar = v ?? false),
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