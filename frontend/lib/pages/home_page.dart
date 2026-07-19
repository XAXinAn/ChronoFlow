import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../model/schedule_model.dart';
import '../model/auth_model.dart';
import '../service/auth_service.dart';
import '../service/schedule_service.dart';
import '../utils/message_utils.dart';
import '../utils/image_normalizer.dart';
import 'schedule/add_schedule_page.dart';
import 'schedule/add_group_schedule_page.dart';
import 'schedule/select_group_page.dart';
import 'schedule/confirm_schedule_page.dart';
import 'schedule/search_page.dart';
import 'group/qr_scanner_page.dart';
import 'group/group_page.dart';
import 'group/notification_page.dart';
import '../service/group_service.dart';
import 'discover/discover_page.dart';

class HomePage extends StatefulWidget {
  final LoginResponse loginResponse;

  const HomePage({super.key, required this.loginResponse});

  String get username => loginResponse.username;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final TextEditingController _searchController = TextEditingController();

  List<Schedule> _schedules = [];
  Timer? _debounce;
  bool _isParsing = false;
  String _parsingStep = '';
  double _parsingProgress = 0;
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  int _pendingNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSchedules();
    _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final gs = GroupService();
      final joins = await gs.getMyJoinRequests();
      final subs = await gs.getMySubgroupRequests();
      final count = joins.where((j) => j.status == 'pending').length +
          subs.where((s) => s['status'] == 'pending').length;
      if (mounted) setState(() => _pendingNotificationCount = count);
    } catch (_) {}
    } catch (e) {
      debugPrint('_loadNotificationCount failed: $e');
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _searchController.dispose();
    _pageController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _performSearch(_searchController.text);
    });
  }

  Future<void> _loadSchedules() async {
    try {
      final schedules = await ScheduleService().getSchedules();
      setState(() => _schedules = schedules);
    } catch (e) {
      if (mounted) {
        setState(() => _schedules = []);
        MessageUtils.show(context, '鍔犺浇鏃ョ▼澶辫触');
      }
    }
  }

  Future<void> _performSearch(String query) async {
    try {
      final schedules = await ScheduleService().getSchedules(
        search: query.isEmpty ? null : query,
      );
      setState(() => _schedules = schedules);
    } catch (e) {
      if (mounted) {
MessageUtils.show(context, '鎼滅储澶辫触: $e');
      }
    }
  }

  List<Schedule> get _schedulesForSelectedDay {
    return _schedules.where((s) {
      return s.time.year == _selectedDay.year &&
          s.time.month == _selectedDay.month &&
          s.time.day == _selectedDay.day;
    }).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _loadSchedules();
  }

  void _showCameraOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.black),
              title: const Text('鎷嶇収', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.black),
              title: const Text('浠庣浉鍐岄€夋嫨', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectGroupForCamera() async {
    final group = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectGroupPage()),
    );
    if (group != null && mounted) {
      _openCamera(isGroup: true, groupId: group.id, groupName: group.name);
    }
  }

  Future<void> _openCamera({bool isGroup = false, String? groupId, String? groupName}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        _processImage(image, isGroup: isGroup, groupId: groupId, groupName: groupName);
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.show(context, '鎵撳紑鐩告満澶辫触: $e');
      }
    }
  }

  Future<void> _pickImageFromGallery({bool isGroup = false, String? groupId, String? groupName}) async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1920, maxHeight: 1920);
      if (images.isEmpty) return;
      if (!mounted) return;
      setState(() { _isParsing = true; _parsingStep = '姝ｅ湪璇嗗埆...'; _parsingProgress = 0; });
      final allSchedules = <Schedule>[];
      for (int i = 0; i < images.length; i++) {
        if (!mounted) return;
        setState(() { _parsingStep = '璇嗗埆涓?(${i + 1}/${images.length})'; _parsingProgress = (i + 0.5) / images.length; });
        try {
          final ocr = await _textRecognizer.processImage(InputImage.fromFilePath(images[i].path));
          final jpegPath = await ImageNormalizer.toJpeg(images[i].path);
          if (jpegPath == null) continue; // 鏃犳硶璇嗗埆鐨勫浘鐗囷紝璺宠繃锛堥伩鍏嶅師鐢熷穿婧冿級
          final ocr = await _textRecognizer
              .processImage(InputImage.fromFilePath(jpegPath))
              .timeout(const Duration(seconds: 20));
          if (ocr.text.isEmpty) continue;
          final results = await ScheduleService().parseNotification(ocr.text);
          for (final r in results) {
            DateTime t = DateTime.now();
            final d = r['eventDate'] ?? ''; if (d.isNotEmpty) { try { t = DateTime.parse(d); } catch (_) {} }
            final tm = r['eventTime'] ?? ''; if (tm.isNotEmpty) {
              try { final p = tm.split(':'); if (p.length >= 2) t = DateTime(t.year, t.month, t.day, int.parse(p[0]), int.parse(p[1])); } catch (_) {}
            }
            allSchedules.add(Schedule.create(title: r['title'] ?? '鏈懡鍚嶆棩绋?, description: r['remark'] ?? '', location: r['location'] ?? '', time: t));
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() { _isParsing = false; _parsingStep = ''; _parsingProgress = 0; });
      if (allSchedules.isEmpty) { MessageUtils.show(context, '鏈娴嬪埌鏃ョ▼'); return; }
      final confirmed = await Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmSchedulePage(parsedSchedules: allSchedules)));
      if (confirmed != null && mounted) _loadSchedules();
    } catch (e) {
      if (mounted) MessageUtils.show(context, '鎵撳紑鐩稿唽澶辫触: $e');
      if (mounted) {
        setState(() { _isParsing = false; _parsingStep = ''; _parsingProgress = 0; });
        MessageUtils.show(context, '鎵撳紑鐩稿唽澶辫触: $e');
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) return;

      _processImage(image);
    } catch (e) {
      if (mounted) {
        MessageUtils.show(context, '閫夋嫨鍥剧墖澶辫触: $e');
      }
    }
  }

  Future<void> _processImage(XFile image, {bool isGroup = false, String? groupId, String? groupName}) async {
    if (!mounted) return;
    try {
      setState(() {
        _isParsing = true;
        _parsingStep = '姝ｅ湪璇嗗埆鏂囧瓧...';
        _parsingProgress = 0.3;
      });

      final jpegPath = await ImageNormalizer.toJpeg(image.path);
      if (jpegPath == null) {
        if (!mounted) return;
        setState(() { _isParsing = false; _parsingStep = ''; _parsingProgress = 0; });
        MessageUtils.show(context, '鏃犳硶璇嗗埆璇ュ浘鐗囨牸寮忥紝璇锋崲涓€寮?);
        return;
      }
      final inputImage = InputImage.fromFilePath(jpegPath);
      final recognizedText = await _textRecognizer
          .processImage(inputImage)
          .timeout(const Duration(seconds: 20));
      final ocrResult = recognizedText.text;

      if (!mounted) return;

      if (ocrResult.isEmpty) {
        setState(() {
          _isParsing = false;
          _parsingStep = '';
          _parsingProgress = 0;
        });
        MessageUtils.show(context, '鏈娴嬪埌鏂囧瓧锛岃閲嶆柊鎷嶆憚');
        return;
      }

      if (!mounted) return;
      setState(() {
        _parsingStep = '姝ｅ湪瑙ｆ瀽鏃ョ▼...';
        _parsingProgress = 0.7;
      });

      final results = await ScheduleService().parseNotification(ocrResult);

      if (!mounted) return;
      setState(() {
        _isParsing = false;
        _parsingStep = '';
        _parsingProgress = 0;
      });

      if (results.isNotEmpty) {
        final schedules = results.map((r) {
          final dateStr = r['eventDate'] ?? '';
          final timeStr = r['eventTime'] ?? '';
          DateTime scheduleTime = DateTime.now();
          if (dateStr.isNotEmpty) {
            try {
              scheduleTime = DateTime.parse(dateStr);
            } catch (_) {}
          }
          if (timeStr.isNotEmpty) {
            try {
              final parts = timeStr.split(':');
              if (parts.length >= 2) {
                scheduleTime = DateTime(
                  scheduleTime.year,
                  scheduleTime.month,
                  scheduleTime.day,
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                );
              }
            } catch (_) {}
          }
          return Schedule.create(
            title: r['title'] ?? '鏈懡鍚嶆棩绋?,
            description: r['remark'] ?? '',
            location: r['location'] ?? '',
            time: scheduleTime,
          );
        }).toList();

        if (!mounted) return;
        final confirmed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmSchedulePage(
              parsedSchedules: schedules,
            ),
          ),
        );

        if (!mounted) return;
        if (confirmed is List && (confirmed as List).isNotEmpty) {
          _loadSchedules();
        } else if (confirmed == true) {
          _loadSchedules();
        }
      } else {
        MessageUtils.show(context, '鏈В鏋愬埌鏃ョ▼淇℃伅');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isParsing = false;
        _parsingStep = '';
        _parsingProgress = 0;
      });
      MessageUtils.show(context, '瑙ｆ瀽澶辫触: $e');
    }
  }

  Future<void> _addPersonalSchedule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSchedulePage(
          initialDate: _selectedDay,
          onScheduleAdded: (schedule) {
            setState(() {
              _schedules.add(schedule);
            });
          },
        ),
      ),
    );
    if (result == true) {
      _loadSchedules();
    }
  }

  Future<void> _addGroupSchedule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddGroupSchedulePage(
          onScheduleAdded: (schedule) {
            setState(() {
              _schedules.add(schedule);
            });
          },
        ),
      ),
    );
    if (result == true) {
      _loadSchedules();
    }
  }

  Future<void> _openQrScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SearchPage(),
                          ),
                        );
                        _loadSchedules();
                      },
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 12),
                            Icon(Icons.search, color: Colors.black54, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '鎼滅储',
                                style: TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
                              ),
                            ),
                            SizedBox(width: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationPage()),
                      );
                      _loadNotificationCount();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_outlined, size: 26, color: Colors.black),
                          if (_pendingNotificationCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _currentIndex == 1
              ? AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text(
                    '鍙戠幇',
                    style: TextStyle(fontWeight: FontWeight.w300),
                  ),
                )
              : _currentIndex == 2
                  ? AppBar(
                      automaticallyImplyLeading: false,
                      title: const Text(
                        '鍏变韩',
                        style: TextStyle(fontWeight: FontWeight.w300),
                      ),
                    )
                  : null,
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddGroupSchedulePage(
                      initialDate: _selectedDay,
                      onScheduleAdded: (schedule) {
                        setState(() {
                          _schedules.add(schedule);
                        });
                      },
                    ),
                  ),
                );
                if (result == true) {
                  _loadSchedules();
                }
              },
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add),
            )
          : null,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _loadNotificationCount();
            },
            children: [
              _buildHomeContent(),
              _buildDiscoverContent(),
              _buildGroupContent(),
              _buildProfileContent(),
            ],
          ),
          if (_isParsing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_parsingStep, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black38,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 14,
        unselectedFontSize: 14,
        items: const [
          BottomNavigationBarItem(label: '棣栭〉', icon: Icon(Icons.home_outlined)),
          BottomNavigationBarItem(label: '鍙戠幇', icon: Icon(Icons.explore_outlined)),
          BottomNavigationBarItem(label: '鍏变韩', icon: Icon(Icons.group_outlined)),
          BottomNavigationBarItem(label: '鎴戠殑', icon: Icon(Icons.person_outline)),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildCalendarCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildCameraEntryCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    _formatDate(_selectedDay),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    '${_schedulesForSelectedDay.length} 涓棩绋?,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          if (_schedulesForSelectedDay.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('鏆傛棤鏃ョ▼', style: TextStyle(color: Colors.black38)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildScheduleCard(_schedulesForSelectedDay[index]),
                  childCount: _schedulesForSelectedDay.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraEntryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: _buildCameraAction(
                icon: Icons.camera_alt_outlined,
                label: '鎷嶇収璇嗗埆',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            Container(width: 0.5, height: 32, color: const Color(0xFFEEEEEE)),
            Expanded(
              child: _buildCameraAction(
                icon: Icons.photo_library_outlined,
                label: '鐩稿唽涓婁紶',
                onTap: () => _pickImageFromGallery(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: _calendarFormat,
          locale: 'zh_CN',
          rowHeight: 48,
          startingDayOfWeek: StartingDayOfWeek.monday,
          onDaySelected: (selectedDay, focusedDay) {
            _onDaySelected(selectedDay, focusedDay);
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              final hasPersonal = _schedules.any((s) =>
                  s.time.year == date.year &&
                  s.time.month == date.month &&
                  s.time.day == date.day &&
                  !s.isGroupSchedule);
              final hasGroup = _schedules.any((s) =>
                  s.time.year == date.year &&
                  s.time.month == date.month &&
                  s.time.day == date.day &&
                  s.isGroupSchedule);
              if (hasPersonal || hasGroup) {
                return Positioned(
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasPersonal)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasGroup)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              }
              return null;
            },
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            selectedDecoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(color: Colors.white),
            defaultTextStyle: const TextStyle(color: Colors.black),
            weekendTextStyle: const TextStyle(color: Colors.black87),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: Colors.black54, fontSize: 12),
            weekendStyle: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverContent() {
    return const DiscoverPage();
    return const SafeArea(
      child: Center(
        child: Text('鏁鏈熷緟', style: TextStyle(color: Colors.black26, fontSize: 15)),
      ),
    );
  }

  Widget _buildGroupContent() {
    return const GroupPage();
  }

  Widget _buildProfileContent() {
    final email = AuthService.currentUser?.email;
    final hasEmail = email != null && email.isNotEmpty;
    final phone = AuthService.currentUser?.phone;
    final hasPhone = phone != null && phone.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, size: 40, color: Colors.black38),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            '/change-nickname',
                            arguments: AuthService.currentUser?.nickname ?? widget.username,
                          );
                          if (result is LoginResponse) {
                            setState(() {});
                          }
                        },
                        child: Row(
                          children: [
                            Text(
                              AuthService.currentUser?.nickname ?? widget.username,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '璐﹀彿: ${AuthService.currentUser?.username ?? widget.username}',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '瀹炲悕璁よ瘉锛?{AuthService.currentUser?.realNameVerified == true ? (AuthService.currentUser?.realName ?? '宸茶璇?) : '鏈璇?}',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            // 閭
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/bind-email',
                      arguments: widget.loginResponse.email,
                    );
                    if (result is LoginResponse) {
                      setState(() {});
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email_outlined, size: 22, color: Colors.black54),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            hasEmail ? email! : '鐐瑰嚮缁戝畾閭',
                            style: TextStyle(
                              fontSize: 15,
                              color: hasEmail ? Colors.black : Colors.black87,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 鎵嬫満鍙?
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/change-phone',
                      arguments: phone,
                    );
                    if (result is LoginResponse) {
                      setState(() {});
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 22, color: Colors.black54),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            hasPhone ? phone! : '鐐瑰嚮缁戝畾鎵嬫満鍙?,
                            style: TextStyle(
                              fontSize: 15,
                              color: hasPhone ? Colors.black : Colors.black38,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildProfileItem(Icons.lock_outline, '淇敼瀵嗙爜', onTap: () async {
              await Navigator.pushNamed(context, '/change-password');
              setState(() {});
            }),
            _buildProfileItem(Icons.qr_code_scanner, '鎵竴鎵?, onTap: _openQrScanner),
            _buildProfileItem(Icons.info_outline, '鍏充簬', onTap: () => Navigator.pushNamed(context, '/about')),
            _buildProfileItem(Icons.feedback_outlined, '鎰忚鍙嶉', onTap: () => Navigator.pushNamed(context, '/feedback')),
            const SizedBox(height: 24),
            _buildProfileItem(Icons.logout, '閫€鍑虹櫥褰?, onTap: () => _showLogoutDialog()),
            _buildProfileItem(Icons.delete_forever, '娉ㄩ攢璐﹀彿', onTap: () => _showDeleteAccountDialog()),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: Colors.black54),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    final isGroup = schedule.isGroupSchedule;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openSchedule(schedule),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isGroup ? Colors.blue : Colors.black12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isGroup ? Colors.blue : Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isGroup && schedule.groupName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            schedule.groupName!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        schedule.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (schedule.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          schedule.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      if (schedule.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                schedule.location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(schedule.time),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (schedule.canEditOrDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => _showDeleteDialog(schedule),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Schedule schedule) async {
    final confirmed = await MessageUtils.showConfirmDialog(
      context,
      title: '鍒犻櫎鏃ョ▼',
      content: '纭畾瑕佸垹闄?${schedule.title}"鍚楋紵',
      confirmText: '鍒犻櫎',
      isDangerous: true,
    );
    if (confirmed == true) {
      _deleteSchedule(schedule);
    }
  }

  String _formatDate(DateTime date) {
    final months = ['1鏈?, '2鏈?, '3鏈?, '4鏈?, '5鏈?, '6鏈?, '7鏈?, '8鏈?, '9鏈?, '10鏈?, '11鏈?, '12鏈?];
    final weekdays = ['鍛ㄤ竴', '鍛ㄤ簩', '鍛ㄤ笁', '鍛ㄥ洓', '鍛ㄤ簲', '鍛ㄥ叚', '鍛ㄦ棩'];
    return '${date.year}骞?{months[date.month - 1]}${date.day}鏃?${weekdays[date.weekday - 1]}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openSchedule(Schedule schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSchedulePage(
          schedule: schedule,
          canEdit: schedule.canEditOrDelete,
          onScheduleUpdated: (updated) {
            setState(() {
              final index = _schedules.indexWhere((s) => s.id == updated.id);
              if (index != -1) {
                _schedules[index] = updated;
              }
            });
          },
        ),
      ),
    );
    if (result == true) {
      _loadSchedules();
    }
  }

  Future<void> _deleteSchedule(Schedule schedule) async {
    try {
      await ScheduleService().deleteSchedule(schedule.id);
      setState(() {
        _schedules.removeWhere((s) => s.id == schedule.id);
      });
    } catch (e) {
      if (mounted) {
        MessageUtils.show(context, '鍒犻櫎澶辫触: $e');
      }
    }
  }

  void _showLogoutDialog() async {
    final confirmed = await MessageUtils.showConfirmDialog(
      context,
      title: '閫€鍑虹櫥褰?,
      content: '纭畾瑕侀€€鍑虹櫥褰曞悧锛?,
      confirmText: '閫€鍑?,
    );
    if (confirmed == true) {
      await _logout();
    }
  }

  void _showDeleteAccountDialog() async {
    final confirmed = await MessageUtils.showConfirmDialog(
      context,
      title: '娉ㄩ攢璐﹀彿',
      content: '纭畾瑕佹敞閿€璐﹀彿鍚楋紵姝ゆ搷浣滀笉鍙仮澶嶃€?,
      confirmText: '娉ㄩ攢',
      isDangerous: true,
    );
    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _deleteAccount() async {
    await AuthService().deleteAccount();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}
