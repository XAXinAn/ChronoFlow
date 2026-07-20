import 'package:flutter/material.dart';
import '../../model/schedule_model.dart';
import '../../model/group_model.dart';
import 'select_publish_target_page.dart';

class EditParsedSchedulePage extends StatefulWidget {
  final Schedule schedule;

  const EditParsedSchedulePage({super.key, required this.schedule});

  @override
  State<EditParsedSchedulePage> createState() => _EditParsedSchedulePageState();
}

class _EditParsedSchedulePageState extends State<EditParsedSchedulePage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  Group? _selectedGroup;
  bool _isPersonal = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.schedule.title);
    _descController = TextEditingController(text: widget.schedule.description);
    _locationController = TextEditingController(text: widget.schedule.location);
    _selectedDate = widget.schedule.time;
    _selectedTime = TimeOfDay.fromDateTime(widget.schedule.time);

    // 如果日程是群组日程
    if (widget.schedule.isGroupSchedule) {
      _isPersonal = false;
      if (widget.schedule.groupId != null && widget.schedule.groupName != null) {
        _selectedGroup = Group(
          id: widget.schedule.groupId!,
          name: widget.schedule.groupName!,
          description: '',
          inviteCode: '',
          memberCount: 0,
          creatorId: 0,
          createdAt: DateTime.now(),
          requireApproval: false,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectPublishTarget() async {
    final result = await Navigator.push<Group?>(
      context,
      MaterialPageRoute(builder: (context) => const SelectPublishTargetPage()),
    );
    setState(() {
      if (result == null) {
        // 选择个人日程
        _selectedGroup = null;
        _isPersonal = true;
      } else {
        // 选择群组日程
        _selectedGroup = result;
        _isPersonal = false;
      }
    });
  }

  Schedule _buildSchedule() {
    final time = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    return Schedule.create(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      location: _locationController.text.trim(),
      time: time,
      groupId: _isPersonal ? null : _selectedGroup?.id,
      groupName: _isPersonal ? null : _selectedGroup?.name,
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.utc(2020, 1, 1),
      lastDate: DateTime.utc(2030, 12, 31),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑日程'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _buildSchedule());
            },
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 发布到选择
            const Text(
              '发布到',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectPublishTarget,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: _isPersonal ? Colors.grey : Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isPersonal ? Icons.person : Icons.group,
                      color: _isPersonal ? Colors.black : Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isPersonal ? '个人日程' : (_selectedGroup?.name ?? '选择群组'),
                        style: TextStyle(
                          color: _isPersonal ? Colors.black : Colors.blue,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '描述',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '地点',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '日期',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_formatDate(_selectedDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '时间',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_formatTime(_selectedTime)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}