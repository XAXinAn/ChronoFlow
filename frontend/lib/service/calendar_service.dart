import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:timezone/timezone.dart' as tz;
import '../model/schedule_model.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._();
  factory CalendarService() => _instance;
  CalendarService._();

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  List<Calendar> _calendars = [];
  bool _hasPermission = false;

  Future<bool> requestPermission() async {
    var permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
    _hasPermission = permissionsGranted.isSuccess && permissionsGranted.data == true;
    if (_hasPermission) {
      await _loadCalendars();
    }
    return _hasPermission;
  }

  Future<void> _loadCalendars() async {
    if (!_hasPermission) return;
    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (calendarsResult.isSuccess && calendarsResult.data != null) {
      _calendars = calendarsResult.data!;
    }
  }

  List<Calendar> get calendars => _calendars;

  Calendar? get defaultCalendar {
    if (_calendars.isEmpty) return null;
    final primary = _calendars.where((c) => c.isDefault == true).toList();
    if (primary.isNotEmpty) return primary.first;
    return _calendars.first;
  }

  Future<bool> exportSchedule(Schedule schedule, {String? calendarId}) async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return false;
    }

    try {
      final calendar = calendarId != null
          ? _calendars.where((c) => c.id == calendarId).firstOrNull
          : defaultCalendar;

      if (calendar == null || calendar.id == null) {
        return false;
      }

      final event = Event(
        calendar.id,
        title: schedule.title,
        description: schedule.description.isNotEmpty ? schedule.description : null,
        location: schedule.location.isNotEmpty ? schedule.location : null,
        start: tz.TZDateTime.from(schedule.time, tz.local),
        end: tz.TZDateTime.from(schedule.time.add(const Duration(hours: 1)), tz.local),
      );

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('导出日程到系统日历失败: $e');
      return false;
    }
  }
}