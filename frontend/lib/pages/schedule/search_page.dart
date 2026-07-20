import 'dart:async';
import 'package:flutter/material.dart';
import '../../model/schedule_model.dart';
import '../../model/group_model.dart';
import '../../service/schedule_service.dart';
import '../../service/group_service.dart';
import '../../utils/message_utils.dart';
import 'add_schedule_page.dart';
import '../group/group_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Schedule> _schedules = [];
  List<Group> _groups = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isFirstBuild = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFirstBuild) {
      _searchController.clear();
      setState(() {
        _schedules = [];
        _groups = [];
        _hasSearched = false;
      });
    }
    _isFirstBuild = false;
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _performSearch(_searchController.text);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _schedules = [];
        _groups = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final futures = await Future.wait([
        ScheduleService().getSchedules(search: query),
        _searchGroups(query),
      ]);

      if (mounted) {
        setState(() {
          _schedules = futures[0] as List<Schedule>;
          _groups = futures[1] as List<Group>;
          _hasSearched = true;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        MessageUtils.show(context, '搜索失败: $e');
      }
    }
  }

  Future<List<Group>> _searchGroups(String query) async {
    final groups = await GroupService().getMyGroups();
    return groups.where((g) =>
        g.name.contains(query) || g.description.contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: Colors.black54, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '搜索日程、群组',
                          hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                        child: const Icon(Icons.close, size: 18, color: Colors.black54),
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
              ? Center(
                  child: Text(
                    '输入关键词搜索日程和群组',
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              : _schedules.isEmpty && _groups.isEmpty
                  ? Center(
                      child: Text(
                        '未找到相关结果',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 群组搜索结果
                          if (_groups.isNotEmpty) ...[
                            _buildSectionTitle('群组', _groups.length),
                            const SizedBox(height: 8),
                            ..._groups.map((g) => _buildGroupCard(g)),
                            const SizedBox(height: 24),
                          ],
                          // 日程搜索结果
                          if (_schedules.isNotEmpty) ...[
                            _buildSectionTitle('日程', _schedules.length),
                            const SizedBox(height: 8),
                            ..._schedules.map((s) => _buildScheduleCard(s)),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(Group group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openGroupDetail(group),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.group,
                    color: Colors.blue.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (group.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          group.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.people, size: 14, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            '${group.memberCount} 人',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openScheduleDetail(schedule),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black,
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
                      if (schedule.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          schedule.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
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
                        _formatDateTime(schedule.time),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openScheduleDetail(Schedule schedule) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSchedulePage(schedule: schedule),
      ),
    );
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  Future<void> _openGroupDetail(Group group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailPage(group: group),
      ),
    );
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}年${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}