import 'package:flutter/material.dart';
import '../../model/schedule_model.dart';
import '../../service/calendar_service.dart';
import '../../service/schedule_service.dart';
import 'edit_parsed_schedule_page.dart';

class ConfirmSchedulePage extends StatefulWidget {
  final List<Schedule> parsedSchedules;

  const ConfirmSchedulePage({
    super.key,
    required this.parsedSchedules,
  });

  @override
  State<ConfirmSchedulePage> createState() => _ConfirmSchedulePageState();
}

class _ConfirmSchedulePageState extends State<ConfirmSchedulePage> {
  late List<Schedule> _schedules;
  final Set<int> _syncIndices = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _schedules = List.from(widget.parsedSchedules);
  }

  void _removeSchedule(int index) {
    setState(() {
      _schedules.removeAt(index);
    });
  }

  Future<void> _confirmSchedules() async {
    setState(() => _isSaving = true);

    try {
      final scheduleService = ScheduleService();
      // 1. 先保存到后端
      for (int i = 0; i < _schedules.length; i++) {
        final s = _schedules[i];
        await scheduleService.createScheduleFromSchedule(s);
      }

      // 2. 逐条同步到系统日历（根据用户勾选）
      final calendarService = CalendarService();
      for (int i = 0; i < _schedules.length; i++) {
        if (_syncIndices.contains(i)) {
          await calendarService.exportSchedule(_schedules[i]);
        }
      }

      if (mounted) Navigator.pop(context, _schedules);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
        // 保存失败时 pop null，不误传未保存的数据 (C-12)
        Navigator.pop(context, null);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editSchedule(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditParsedSchedulePage(
          schedule: _schedules[index],
        ),
      ),
    );
    if (result != null && result is Schedule) {
      setState(() {
        _schedules[index] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('确认日程'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          TextButton(
            onPressed: _schedules.isEmpty || _isSaving
                ? null
                : () => _confirmSchedules(),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : Text(
                    '确认添加(${_schedules.length})',
                    style: TextStyle(
                      color: _schedules.isEmpty ? Colors.grey : Colors.black,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _schedules.isEmpty
                ? const Center(
                    child: Text(
                      '已删除所有日程',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _schedules[index];
                      return _buildScheduleCard(index, schedule);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(int index, Schedule schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editSchedule(index),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: schedule.isGroupSchedule ? Colors.blue : Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 50,
                      decoration: BoxDecoration(
                        color: schedule.isGroupSchedule ? Colors.blue : Colors.black,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(schedule.time),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeSchedule(index),
                    ),
                  ],
                ),
                if (schedule.isGroupSchedule && schedule.groupName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      schedule.groupName!,
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
                if (schedule.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    schedule.description,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (schedule.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        schedule.location,
                        style: const TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
                ],
                // 逐条勾选同步到系统日历
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_syncIndices.contains(index)) {
                          _syncIndices.remove(index);
                        } else {
                          _syncIndices.add(index);
                        }
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(
                          _syncIndices.contains(index)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: _syncIndices.contains(index) ? Colors.black : Colors.black38,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '同步到系统日历',
                          style: TextStyle(
                            fontSize: 13,
                            color: _syncIndices.contains(index) ? Colors.black : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}年${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}