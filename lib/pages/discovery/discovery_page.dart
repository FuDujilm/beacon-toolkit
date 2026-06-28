import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/discovery.dart';
import '../../models/radio_profile.dart';
import '../../services/discovery_preferences_service.dart';
import '../../services/discovery_service.dart';
import '../../services/local_database_service.dart';
import '../../services/satellite_service.dart';
import '../practice/practice_page.dart';
import '../radio/frequency_table_page.dart';
import '../radio/radio_placeholder_page.dart';
import 'discovery_detail_page.dart';
import 'satellite_detail_page.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage>
    with SingleTickerProviderStateMixin {
  final _preferencesService = DiscoveryPreferencesService();
  final _discoveryService = DiscoveryService();
  final _satelliteService = SatelliteService();
  final _databaseService = LocalDatabaseService();
  late final TabController _tabController;

  DiscoveryPreferences _preferences = const DiscoveryPreferences();
  RadioProfile _radioProfile = RadioProfile.defaults;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final results = await Future.wait([
      _preferencesService.getPreferences(),
      _databaseService.getRadioProfile(),
    ]);
    if (!mounted) return;
    setState(() {
      _preferences = results[0] as DiscoveryPreferences;
      _radioProfile = results[1] as RadioProfile;
      _isLoadingSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final area = [_preferences.province, _preferences.city]
        .where((item) => item != null && item.isNotEmpty)
        .join(' / ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '推荐'),
            Tab(text: '考试'),
            Tab(text: '资讯'),
            Tab(text: '卫星'),
          ],
        ),
      ),
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _FeedList(
                  title: area.isEmpty ? '为你推荐' : area,
                  variant: _FeedListVariant.dashboard,
                  onOpenExamTab: () => _tabController.animateTo(1),
                  loader: (page) => _discoveryService.getFeed(
                    apiSources: _preferences.apiSources,
                    province: _preferences.province,
                    city: _preferences.city,
                    examLevel: _preferences.examLevel,
                    query: _preferences.keywords.isEmpty
                        ? null
                        : _preferences.keywords.join(' '),
                    page: page,
                  ),
                ),
                _FeedList(
                  title: '考试信息',
                  variant: _FeedListVariant.examBoard,
                  loader: (page) => _discoveryService.getExams(
                    apiSources: _preferences.apiSources,
                    province: _preferences.province,
                    city: _preferences.city,
                    examLevel: _preferences.examLevel,
                    page: page,
                  ),
                ),
                _FeedList(
                  title: '本地无线电资讯',
                  variant: _FeedListVariant.newsBoard,
                  loader: (page) => _discoveryService.getFeed(
                    apiSources: _preferences.apiSources,
                    contentType: 'activity',
                    province: _preferences.province,
                    city: _preferences.city,
                    page: page,
                  ),
                ),
                _SatellitePanel(
                  preferences: _preferences,
                  radioProfile: _radioProfile,
                  service: _satelliteService,
                ),
              ],
            ),
    );
  }
}

class _FeedList extends StatefulWidget {
  final String title;
  final _FeedListVariant variant;
  final Future<DiscoveryPageResult> Function(int page) loader;
  final VoidCallback? onOpenExamTab;

  const _FeedList({
    required this.title,
    required this.loader,
    this.variant = _FeedListVariant.list,
    this.onOpenExamTab,
  });

  @override
  State<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<_FeedList> {
  final _scrollController = ScrollController();
  final List<DiscoveryFeedItem> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.loader != widget.loader) {
      _load(reset: true);
    }
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 360 &&
        !_isLoading &&
        _hasMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading && !reset) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _items.clear();
      }
    });

    try {
      final result = await widget.loader(_page);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _page += 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _StateMessage(
        icon: Icons.cloud_off,
        title: '加载失败',
        subtitle: '请检查服务器地址或稍后再试。\n$_error',
        action: FilledButton.icon(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }
    if (_items.isEmpty) {
      return _StateMessage(
        icon: Icons.inbox_outlined,
        title: '暂无内容',
        subtitle: '当前筛选条件下没有已发布资讯。',
        action: OutlinedButton.icon(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
      );
    }

    if (widget.variant == _FeedListVariant.dashboard) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _DiscoveryDashboard(
          controller: _scrollController,
          title: widget.title,
          items: _items,
          isLoadingMore: _hasMore || _isLoading,
          loadMore: _load,
          onOpenExamTab: widget.onOpenExamTab,
        ),
      );
    }

    if (widget.variant == _FeedListVariant.examBoard) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _ExamBoard(
          controller: _scrollController,
          items: _items,
          isLoadingMore: _hasMore || _isLoading,
          loadMore: _load,
        ),
      );
    }

    if (widget.variant == _FeedListVariant.newsBoard) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _NewsBoard(
          controller: _scrollController,
          items: _items,
          isLoadingMore: _hasMore || _isLoading,
          loadMore: _load,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length + (_hasMore || _isLoading ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _FeedCard(item: _items[index]);
        },
      ),
    );
  }
}

enum _FeedListVariant { list, dashboard, examBoard, newsBoard }

class _ExamBoard extends StatelessWidget {
  final ScrollController controller;
  final List<DiscoveryFeedItem> items;
  final bool isLoadingMore;
  final VoidCallback loadMore;

  const _ExamBoard({
    required this.controller,
    required this.items,
    required this.isLoadingMore,
    required this.loadMore,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where(_isVisibleExamItem).toList();
    final sortedItems = [...visibleItems]
      ..sort((a, b) => _examDate(a).compareTo(_examDate(b)));

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _ExamSummaryCard(items: sortedItems),
        const SizedBox(height: 20),
        _Panel(
          title: '近期考试',
          icon: Icons.history_edu,
          iconColor: const Color(0xFF8B5CF6),
          child: sortedItems.isEmpty
              ? const _EmptyExamNotice()
              : Column(
                  children: sortedItems
                      .take(8)
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ExamCompactCard(item: item),
                          ))
                      .toList(),
                ),
        ),
        if (isLoadingMore) ...[
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: loadMore,
              icon: const Icon(Icons.expand_more),
              label: const Text('加载更多考试'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExamSummaryCard extends StatelessWidget {
  final List<DiscoveryFeedItem> items;

  const _ExamSummaryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthCount = items.where((item) {
      final date = _examDate(item);
      return date.year == now.year && date.month == now.month;
    }).length;
    final openCount = items.length;
    final upcomingCount =
        items.where((item) => !_examDate(item).isBefore(now)).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        return Container(
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2B1E6E), Color(0xFF071526)],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '业余无线电操作技术能力考试',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AB类 · 各地考试信息与公告',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    _ExamStatsRow(
                      stats: [
                        (monthCount.toString(), '本月考试'),
                        (openCount.toString(), '可查看'),
                        (upcomingCount.toString(), '即将开始'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => _openExamCalendar(context),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('全部考试日历'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 16),
                Icon(
                  Icons.assignment_turned_in,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 94,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openExamCalendar(BuildContext context) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可展示的考试日历数据')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ExamCalendarPage(items: items)),
    );
  }
}

class _ExamStatsRow extends StatelessWidget {
  final List<(String, String)> stats;

  const _ExamStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          Expanded(
            child: _ExamStat(value: stats[index].$1, label: stats[index].$2),
          ),
          if (index != stats.length - 1) const _ExamDivider(),
        ],
      ],
    );
  }
}

class _ExamCalendarPage extends StatefulWidget {
  final List<DiscoveryFeedItem> items;

  const _ExamCalendarPage({required this.items});

  @override
  State<_ExamCalendarPage> createState() => _ExamCalendarPageState();
}

class _ExamCalendarPageState extends State<_ExamCalendarPage> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthItems = _sortedItems().where((item) {
      final date = _examDate(item);
      return date.year == _visibleMonth.year &&
          date.month == _visibleMonth.month;
    }).toList();
    final selectedItems = monthItems
        .where((item) => _isSameDay(_examDate(item), _selectedDay))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('考试日历')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _CalendarHeader(
            month: _visibleMonth,
            count: monthItems.length,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                const _WeekdayHeader(),
                const SizedBox(height: 8),
                _MonthGrid(
                  month: _visibleMonth,
                  items: monthItems,
                  selectedDay: _selectedDay,
                  onSelected: (day) {
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            title: _formatChineseDay(_selectedDay),
            icon: Icons.event_note,
            iconColor: const Color(0xFF8B5CF6),
            child: selectedItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        '当天暂无考试信息',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : Column(
                    children: selectedItems
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ExamCompactCard(item: item),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  List<DiscoveryFeedItem> _sortedItems() {
    return [...widget.items]
      ..sort((a, b) => _examDate(a).compareTo(_examDate(b)));
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }
}

class _EmptyExamNotice extends StatelessWidget {
  const _EmptyExamNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '暂无未过期考试信息',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final DateTime month;
  final int count;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _CalendarHeader({
    required this.month,
    required this.count,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${month.year}年${month.month}月',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count 场考试信息',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: weekdays
          .map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<DiscoveryFeedItem> items;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelected;

  const _MonthGrid({
    required this.month,
    required this.items,
    required this.selectedDay,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;
    final cellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        mainAxisExtent: 46,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        final dayNumber = index - leading + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }
        final day = DateTime(month.year, month.month, dayNumber);
        final dayItems =
            items.where((item) => _isSameDay(_examDate(item), day)).toList();
        return _CalendarDayCell(
          day: day,
          count: dayItems.length,
          selected: selectedDay != null && _isSameDay(selectedDay!, day),
          onTap: () => onSelected(day),
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime day;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.day,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = _isSameDay(day, DateTime.now());
    final hasExam = count > 0;
    return Material(
      color: selected
          ? scheme.primary
          : today
              ? scheme.primaryContainer
              : hasExam
                  ? scheme.primaryContainer.withValues(alpha: 0.58)
                  : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : today
                      ? scheme.primary.withValues(alpha: 0.3)
                      : hasExam
                          ? scheme.primary.withValues(alpha: 0.42)
                          : scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: selected
                      ? scheme.onPrimary
                      : today
                          ? scheme.onPrimaryContainer
                          : hasExam
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: hasExam ? 16 : 4,
                height: 4,
                decoration: BoxDecoration(
                  color: hasExam
                      ? (selected ? scheme.onPrimary : scheme.primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamStat extends StatelessWidget {
  final String value;
  final String label;

  const _ExamStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ExamDivider extends StatelessWidget {
  const _ExamDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

class _NewsBoard extends StatelessWidget {
  final ScrollController controller;
  final List<DiscoveryFeedItem> items;
  final bool isLoadingMore;
  final VoidCallback loadMore;

  const _NewsBoard({
    required this.controller,
    required this.items,
    required this.isLoadingMore,
    required this.loadMore,
  });

  @override
  Widget build(BuildContext context) {
    final featured = items.take(4).toList();
    final quick = items.skip(4).take(4).toList();

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const _NewsCategoryChips(),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.05,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children:
              featured.map((item) => _FeaturedNewsCard(item: item)).toList(),
        ),
        const SizedBox(height: 20),
        _Panel(
          title: '热点快讯',
          icon: Icons.bolt,
          iconColor: const Color(0xFFF43F5E),
          child: Column(
            children: quick.isEmpty
                ? items
                    .take(3)
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NewsTickerTile(item: item),
                        ))
                    .toList()
                : quick
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NewsTickerTile(item: item),
                        ))
                    .toList(),
          ),
        ),
        if (isLoadingMore) ...[
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: loadMore,
              icon: const Icon(Icons.expand_more),
              label: const Text('加载更多资讯'),
            ),
          ),
        ],
      ],
    );
  }
}

class _NewsCategoryChips extends StatelessWidget {
  const _NewsCategoryChips();

  @override
  Widget build(BuildContext context) {
    const categories = ['全部', '政策法规', '协会动态', '技术文章', '设备评测', 'DX新闻'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map((category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: category == '全部',
                    label: Text(category),
                    onSelected: (_) {},
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _FeaturedNewsCard extends StatelessWidget {
  final DiscoveryFeedItem item;

  const _FeaturedNewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiscoveryDetailPage(item: item)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.35),
              scheme.surfaceContainerHighest.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topRight,
                child: Icon(_typeIcon(item.contentType),
                    color: scheme.primary.withValues(alpha: 0.75), size: 34),
              ),
            ),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _SolidPill(label: _typeLabel(item.contentType)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDate(item.publishedAt ?? item.fetchedAt),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.outline, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsTickerTile extends StatelessWidget {
  final DiscoveryFeedItem item;

  const _NewsTickerTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiscoveryDetailPage(item: item)),
      ),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.46),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDate(item.publishedAt ?? item.fetchedAt),
              style: TextStyle(color: scheme.outline, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryDashboard extends StatelessWidget {
  final ScrollController controller;
  final String title;
  final List<DiscoveryFeedItem> items;
  final bool isLoadingMore;
  final VoidCallback loadMore;
  final VoidCallback? onOpenExamTab;

  const _DiscoveryDashboard({
    required this.controller,
    required this.title,
    required this.items,
    required this.isLoadingMore,
    required this.loadMore,
    this.onOpenExamTab,
  });

  @override
  Widget build(BuildContext context) {
    final hero = items.first;
    final exams =
        items.where((item) => item.contentType == 'exam_info').toList();
    final news =
        items.where((item) => item.contentType != 'exam_info').toList();
    final recentExams =
        exams.isEmpty ? items.take(3).toList() : exams.take(3).toList();
    final hotNews =
        news.isEmpty ? items.skip(1).take(3).toList() : news.take(3).toList();

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _HeroExamCard(item: hero),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 780;
            if (!wide) {
              return Column(
                children: [
                  _RecentExamSection(items: recentExams),
                  const SizedBox(height: 20),
                  _HotNewsSection(items: hotNews),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 3, child: _RecentExamSection(items: recentExams)),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: _HotNewsSection(items: hotNews)),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _QuickLinksSection(onOpenExamTab: onOpenExamTab),
        if (isLoadingMore) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: loadMore,
              icon: const Icon(Icons.expand_more),
              label: const Text('加载更多'),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroExamCard extends StatelessWidget {
  final DiscoveryFeedItem item;

  const _HeroExamCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final place = [item.province, item.city]
        .where((value) => value != null && value.isNotEmpty)
        .join(' ');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiscoveryDetailPage(item: item)),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 190),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF15305C),
              const Color(0xFF071526),
              scheme.primary.withValues(alpha: 0.22),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 18,
              top: 16,
              bottom: 16,
              child: Opacity(
                opacity: 0.34,
                child: Icon(Icons.settings_input_antenna,
                    size: 150, color: scheme.primaryContainer),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: const BoxDecoration(
                  color: Color(0xFF6D3CEB),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  '热门推荐',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _GlassPill(label: _typeLabel(item.contentType)),
                      if (item.examLevel != null)
                        _GlassPill(label: '${item.examLevel} 类'),
                      if (place.isNotEmpty) _GlassPill(label: place),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (item.summary != null && item.summary!.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: Text(
                        item.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.35,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _HeroMeta(
                        icon: Icons.schedule,
                        label: _formatDate(item.publishedAt ?? item.fetchedAt),
                      ),
                      _HeroMeta(
                        icon: Icons.source,
                        label: item.sourceName,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentExamSection extends StatelessWidget {
  final List<DiscoveryFeedItem> items;

  const _RecentExamSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '近期考试',
      icon: Icons.school,
      iconColor: const Color(0xFF8B5CF6),
      child: Column(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExamCompactCard(item: item),
                ))
            .toList(),
      ),
    );
  }
}

class _HotNewsSection extends StatelessWidget {
  final List<DiscoveryFeedItem> items;

  const _HotNewsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '热门资讯',
      icon: Icons.local_fire_department,
      iconColor: const Color(0xFF38BDF8),
      child: Column(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NewsCompactTile(item: item),
                ))
            .toList(),
      ),
    );
  }
}

class _ExamCompactCard extends StatelessWidget {
  final DiscoveryFeedItem item;

  const _ExamCompactCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = item.publishedAt ?? item.fetchedAt ?? DateTime.now();
    final place = [item.province, item.city]
        .where((value) => value != null && value.isNotEmpty)
        .join(' ');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiscoveryDetailPage(item: item)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6D3CEB), Color(0xFF1D4ED8)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${date.month}月',
                      style: const TextStyle(color: Colors.white70)),
                  Text(
                    '${date.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.examLevel != null)
                    _SolidPill(label: '${item.examLevel} 类'),
                  const SizedBox(height: 5),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (place.isNotEmpty)
                        _SmallMeta(icon: Icons.place, label: place),
                      _SmallMeta(
                          icon: Icons.schedule, label: _formatDate(date)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.bookmark_border, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

class _NewsCompactTile extends StatelessWidget {
  final DiscoveryFeedItem item;

  const _NewsCompactTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiscoveryDetailPage(item: item)),
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.9),
                  scheme.tertiary.withValues(alpha: 0.62),
                ],
              ),
            ),
            child: Icon(_typeIcon(item.contentType),
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(item.publishedAt ?? item.fetchedAt),
                        style: TextStyle(color: scheme.outline, fontSize: 12),
                      ),
                    ),
                    Icon(Icons.visibility_outlined,
                        size: 15, color: scheme.outline),
                    const SizedBox(width: 4),
                    Text('1.2k',
                        style: TextStyle(color: scheme.outline, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinksSection extends StatelessWidget {
  final VoidCallback? onOpenExamTab;

  const _QuickLinksSection({this.onOpenExamTab});

  @override
  Widget build(BuildContext context) {
    final links = [
      (Icons.article_outlined, '考试指南', '报考流程与说明', onOpenExamTab ?? () {}),
      (
        Icons.edit_note,
        '模拟练习',
        '在线题库练习',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PracticePage()),
            ),
      ),
      (
        Icons.graphic_eq,
        '频率数据库',
        '业余频段速查',
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FrequencyTablePage()),
            ),
      ),
      (
        Icons.radio,
        '电台设备库',
        '设备资料查询',
        () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RadioPlaceholderPage(
                  title: '电台设备库',
                  icon: Icons.radio,
                  subtitle: '电台设备资料查询功能正在接入，当前版本先提供统一入口。',
                ),
              ),
            ),
      ),
    ];
    return _Panel(
      title: '精选推荐',
      icon: Icons.thumb_up,
      iconColor: const Color(0xFF3B82F6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 720 ? 4 : 2;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: links
                .map((link) => _QuickLinkCard(
                      icon: link.$1,
                      title: link.$2,
                      subtitle: link.$3,
                      onTap: link.$4,
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.34),
                scheme.surfaceContainerHighest.withValues(alpha: 0.54),
              ],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.outline, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: scheme.primary, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _Panel({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String label;

  const _GlassPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _SolidPill extends StatelessWidget {
  final String label;

  const _SolidPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF6D3CEB),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 17),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _SmallMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: outline, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: outline, fontSize: 12)),
      ],
    );
  }
}

IconData _typeIcon(String type) {
  return switch (type) {
    'exam_info' => Icons.assignment,
    'license_renewal' => Icons.badge,
    'policy' => Icons.gavel,
    'activity' => Icons.event,
    _ => Icons.article,
  };
}

String _typeLabel(String type) {
  return switch (type) {
    'exam_info' => '考试',
    'license_renewal' => '换证',
    'policy' => '政策',
    'activity' => '活动',
    _ => '资讯',
  };
}

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return DateFormat('MM-dd HH:mm').format(date.toLocal());
}

DateTime _examDate(DiscoveryFeedItem item) {
  return (item.examTime ?? item.publishedAt ?? item.fetchedAt ?? DateTime.now())
      .toLocal();
}

bool _isVisibleExamItem(DiscoveryFeedItem item) {
  if (item.isExpired) return false;
  final examTime = item.examTime;
  if (examTime == null) return true;
  final date = examTime.toLocal();
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  return !date.isBefore(todayStart);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatChineseDay(DateTime date) {
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return '${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
}

class _FeedCard extends StatelessWidget {
  final DiscoveryFeedItem item;

  const _FeedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final place = [item.province, item.city]
        .where((value) => value != null && value.isNotEmpty)
        .join(' / ');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DiscoveryDetailPage(item: item)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon(item.contentType),
                      color: scheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(_typeLabel(item.contentType),
                      style: TextStyle(
                          color: scheme.primary, fontWeight: FontWeight.w600)),
                  if (place.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.outline, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (item.summary != null && item.summary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.summary!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.sourceName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.outline, fontSize: 12),
                    ),
                  ),
                  Text(
                    _formatDate(item.publishedAt ?? item.fetchedAt),
                    style: TextStyle(color: scheme.outline, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      'exam_info' => Icons.assignment,
      'license_renewal' => Icons.badge,
      'policy' => Icons.gavel,
      'activity' => Icons.event,
      _ => Icons.article,
    };
  }

  String _typeLabel(String type) {
    return switch (type) {
      'exam_info' => '考试',
      'license_renewal' => '换证',
      'policy' => '政策',
      'activity' => '活动',
      _ => '资讯',
    };
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MM-dd HH:mm').format(date.toLocal());
  }
}

class _SatellitePanel extends StatefulWidget {
  final DiscoveryPreferences preferences;
  final RadioProfile radioProfile;
  final SatelliteService service;

  const _SatellitePanel({
    required this.preferences,
    required this.radioProfile,
    required this.service,
  });

  @override
  State<_SatellitePanel> createState() => _SatellitePanelState();
}

class _SatellitePanelState extends State<_SatellitePanel> {
  late Future<List<SatelliteSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SatelliteSummary>> _load() {
    return widget.service.getSubscribedSatellites(
      grid: widget.radioProfile.grid,
      tleSourceUrls: widget.preferences.tleSourceUrls,
      satelliteNames: widget.preferences.satelliteNames,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SatelliteSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StateMessage(
            icon: Icons.satellite_alt,
            title: '无法计算过境',
            subtitle: snapshot.error.toString(),
            action: OutlinedButton.icon(
              onPressed: () => setState(() => _future = _load()),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          );
        }
        final satellites = snapshot.data ?? const [];
        if (satellites.isEmpty) {
          return const _StateMessage(
            icon: Icons.satellite_alt,
            title: '暂无订阅卫星',
            subtitle: '请在我的 > 系统设置 > 发现源配置中添加关注卫星。',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: _SatelliteBoard(
            satellites: satellites,
            radioProfile: widget.radioProfile,
            tleSourceUrls: widget.preferences.tleSourceUrls,
            service: widget.service,
          ),
        );
      },
    );
  }
}

class _SatelliteBoard extends StatelessWidget {
  final List<SatelliteSummary> satellites;
  final RadioProfile radioProfile;
  final List<String> tleSourceUrls;
  final SatelliteService service;

  const _SatelliteBoard({
    required this.satellites,
    required this.radioProfile,
    required this.tleSourceUrls,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final available = satellites.where((item) => item.nextPass != null).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _SatelliteHeaderCard(
          total: satellites.length,
          available: available,
          source: satellites.first.tleSource,
          grid: radioProfile.grid,
        ),
        const SizedBox(height: 20),
        _Panel(
          title: '已订阅卫星',
          icon: Icons.satellite_alt,
          iconColor: const Color(0xFF60A5FA),
          child: Column(
            children: satellites
                .map((satellite) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SatelliteSummaryCard(
                        satellite: satellite,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SatelliteDetailPage(
                              satelliteName: satellite.name,
                              radioProfile: radioProfile,
                              tleSourceUrls: tleSourceUrls,
                              service: service,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SatelliteHeaderCard extends StatelessWidget {
  final int total;
  final int available;
  final String source;
  final String grid;

  const _SatelliteHeaderCard({
    required this.total,
    required this.available,
    required this.source,
    required this.grid,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.32)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.25),
            scheme.surfaceContainerHighest.withValues(alpha: 0.68),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: scheme.primary.withValues(alpha: 0.16),
                ),
                child: Icon(Icons.public, color: scheme.primary, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '卫星追踪',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '订阅卫星过境、转发器和手机对星',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SatelliteMetric(label: '订阅', value: '$total')),
              Expanded(
                  child:
                      _SatelliteMetric(label: '48h 可见', value: '$available')),
              Expanded(child: _SatelliteMetric(label: 'Grid', value: grid)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.storage, size: 16, color: scheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.outline, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SatelliteSummaryCard extends StatelessWidget {
  final SatelliteSummary satellite;
  final VoidCallback onTap;

  const _SatelliteSummaryCard({
    required this.satellite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pass = satellite.nextPass;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: scheme.primaryContainer.withValues(alpha: 0.65),
                    ),
                    child: Icon(Icons.satellite_alt, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          satellite.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          satellite.noradCatId == null
                              ? 'NORAD 未知'
                              : 'NORAD ${satellite.noradCatId}',
                          style: TextStyle(color: scheme.outline, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.outline),
                ],
              ),
              const SizedBox(height: 14),
              if (pass == null)
                Text(
                  '未来 48 小时暂无过境',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _SatelliteMetric(
                        label: '下一次',
                        value: DateFormat('HH:mm').format(pass.aos),
                      ),
                    ),
                    Expanded(
                      child: _SatelliteMetric(
                        label: '最高仰角',
                        value: '${pass.maxElevation.toStringAsFixed(0)}°',
                      ),
                    ),
                    Expanded(
                      child: _SatelliteMetric(
                        label: '时长',
                        value: '${pass.duration.inMinutes}分',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (pass.maxElevation / 90).clamp(0.08, 1).toDouble(),
                  borderRadius: BorderRadius.circular(99),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SatelliteMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SatelliteMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.outline, fontSize: 12)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
