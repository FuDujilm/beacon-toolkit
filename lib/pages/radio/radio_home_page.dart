import 'package:flutter/material.dart';

import '../developer/developer_page.dart';
import '../home/calendar_page.dart';
import '../home/leaderboard_page.dart';
import '../practice/practice_page.dart';
import '../../models/home_tool_entry.dart';
import '../../models/practice_history.dart';
import '../../models/radio_profile.dart';
import '../../models/sepc_daily_report.dart';
import '../../models/sepc_k_index.dart';
import '../../services/exam_service.dart';
import '../../services/home_tool_preferences_service.dart';
import '../../services/local_database_service.dart';
import '../../services/sepc_daily_report_service.dart';
import '../../services/sepc_k_index_service.dart';
import '../../services/user_settings_service.dart';
import 'callsign_lookup_page.dart';
import 'beacon_qr_scanner_page.dart';
import 'frequency_table_page.dart';
import 'grid_map_page.dart';
import 'propagation_forecast_page.dart';
import 'radio_placeholder_page.dart';
import 'radio_log_page.dart';
import 'satellite_tracker_page.dart';

class RadioHomePage extends StatefulWidget {
  final VoidCallback? onOpenTools;

  const RadioHomePage({super.key, this.onOpenTools});

  @override
  State<RadioHomePage> createState() => _RadioHomePageState();
}

class _RadioHomePageState extends State<RadioHomePage> {
  final _userSettingsService = UserSettingsService();
  final _examService = ExamService();
  final _databaseService = LocalDatabaseService();
  final _homeToolPreferencesService = HomeToolPreferencesService();
  final _sepcService = SepcDailyReportService();
  final _kIndexService = SepcKIndexService();
  int _developerTapCount = 0;
  bool _examStatsLoading = true;
  int _todayAnswered = 0;
  int _weekAnswered = 0;
  double _weekAccuracy = 0;
  int _completedQuestions = 0;
  int _totalQuestions = 0;
  int _recentExamPassed = 0;
  int _recentExamTotal = 0;
  String _currentLibraryName = '题库';
  String _solarKp = 'Kp --';
  String _solarF107 = 'F10.7 --';
  String _solarSource = 'SEPC 中国';
  List<String> _homeToolIds = List<String>.from(defaultHomeToolIds);
  RadioProfile _radioProfile = RadioProfile.defaults;
  DateTime? _lastDeveloperTapAt;

  @override
  void initState() {
    super.initState();
    _loadHomeTools();
    _loadExamStats();
    _loadSolarSummary();
  }

  @override
  void didUpdateWidget(covariant RadioHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadHomeTools();
  }

  Future<void> _loadHomeTools() async {
    final ids = await _homeToolPreferencesService.getSelectedToolIds();
    if (!mounted) return;
    if (_sameStringList(ids, _homeToolIds)) return;
    setState(() => _homeToolIds = ids);
  }

  Future<void> _loadSolarSummary() async {
    SepcDailyReport? report;
    SepcKIndexReport? kIndex;
    try {
      kIndex = await _kIndexService.fetchRecent(days: 1);
    } catch (_) {}
    try {
      report = await _sepcService.fetchDailyReport();
    } catch (_) {}

    if (kIndex != null || report != null) {
      if (!mounted) return;
      setState(() {
        final latestKp = kIndex?.latestValue?.toString() ?? report?.kp ?? '';
        _solarKp = latestKp.isEmpty ? 'Kp --' : 'Kp $latestKp';
        _solarF107 = report?.f107.isNotEmpty == true
            ? 'F10.7 ${report!.f107}'
            : 'F10.7 --';
        _solarSource = kIndex != null ? 'SEPC K' : 'SEPC';
      });
    }
  }

  Future<void> _loadExamStats() async {
    try {
      final settings = await _userSettingsService.getSettings();
      final radioProfile = await _databaseService.getRadioProfile();
      final remoteCallsign = settings['callsign'] as String?;
      final resolvedRadioProfile =
          remoteCallsign != null && remoteCallsign.trim().isNotEmpty
              ? radioProfile.copyWith(
                  callsign: remoteCallsign.trim().toUpperCase(),
                )
              : radioProfile;
      if (resolvedRadioProfile.callsign != radioProfile.callsign) {
        await _databaseService.saveRadioProfile(resolvedRadioProfile);
      }
      final libraryCode = settings['examType'] as String? ?? 'A_CLASS';
      final results = await Future.wait([
        _userSettingsService.getUserStats(),
        _userSettingsService.getLibraryStats(libraryCode),
        _examService.getExamSummaries(),
      ]);

      final userStats = results[0] as Map<String, dynamic>;
      final libraryStats = results[1] as Map<String, dynamic>;
      final examSummaries = results[2] as List<ExamSummary>;
      final examSummary = examSummaries.isNotEmpty ? examSummaries.first : null;

      if (!mounted) return;
      setState(() {
        _todayAnswered = (userStats['todayAnswered'] as num?)?.toInt() ?? 0;
        _weekAnswered = (userStats['weekAnswered'] as num?)?.toInt() ?? 0;
        _weekAccuracy = (userStats['weekAccuracy'] as num?)?.toDouble() ?? 0;
        _completedQuestions =
            (libraryStats['browsedCount'] as num?)?.toInt() ?? 0;
        _totalQuestions =
            (libraryStats['totalQuestions'] as num?)?.toInt() ?? 0;
        _currentLibraryName =
            libraryStats['libraryName'] as String? ?? libraryCode;
        _radioProfile = resolvedRadioProfile;
        _recentExamPassed = examSummary?.recentFivePassed ?? 0;
        _recentExamTotal = examSummary?.recentFiveTotal ?? 0;
        _examStatsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _examStatsLoading = false);
    }
  }

  void _handleTitleTap() {
    final now = DateTime.now();
    final lastTapAt = _lastDeveloperTapAt;
    final isContinuous =
        lastTapAt != null && now.difference(lastTapAt).inMilliseconds <= 1200;

    _lastDeveloperTapAt = now;
    _developerTapCount = isContinuous ? _developerTapCount + 1 : 1;

    if (_developerTapCount >= 5) {
      _developerTapCount = 0;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const DeveloperPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedTools = _selectedHomeTools();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 258,
              child: _ConstrainedHomeContent(
                padding: EdgeInsets.zero,
                child: _HeroPanel(
                  radioProfile: _radioProfile,
                  onTitleTap: _handleTitleTap,
                  onScanTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BeaconQrScannerPage(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ConstrainedHomeContent(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoGrid(
                    solarKp: _solarKp,
                    solarF107: _solarF107,
                    solarSource: _solarSource,
                    onSolarTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PropagationForecastPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: '常用工具',
                    action: '全部工具',
                    onTap: widget.onOpenTools ?? () {},
                  ),
                  const SizedBox(height: 12),
                  GridView(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      mainAxisExtent: 88,
                    ),
                    children: selectedTools
                        .map(
                          (tool) => _ToolTile(
                            title: tool.title,
                            icon: tool.icon,
                            color: tool.color,
                            onTap: () => _openHomeTool(tool),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: '考试训练',
                    action: '查看统计',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const LeaderboardPage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ExamPanel(
                    isLoading: _examStatsLoading,
                    todayAnswered: _todayAnswered,
                    weekAnswered: _weekAnswered,
                    weekAccuracy: _weekAccuracy,
                    completedQuestions: _completedQuestions,
                    totalQuestions: _totalQuestions,
                    recentExamPassed: _recentExamPassed,
                    recentExamTotal: _recentExamTotal,
                    currentLibraryName: _currentLibraryName,
                    onPractice: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PracticePage()),
                    ),
                    onLeaderboard: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPlaceholder(
    BuildContext context,
    String title,
    IconData icon,
    String subtitle,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RadioPlaceholderPage(
          title: title,
          icon: icon,
          subtitle: subtitle,
        ),
      ),
    );
  }

  List<HomeToolEntry> _selectedHomeTools() {
    final byId = {for (final tool in homeToolEntries) tool.id: tool};
    return _homeToolIds
        .map((id) => byId[id])
        .whereType<HomeToolEntry>()
        .toList();
  }

  void _openHomeTool(HomeToolEntry tool) {
    switch (tool.id) {
      case 'callsign_lookup':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CallsignLookupPage()),
        );
        return;
      case 'beacon_scan':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BeaconQrScannerPage()),
        );
        return;
      case 'qth_locator':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GridMapPage()),
        );
        return;
      case 'frequency_table':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FrequencyTablePage()),
        );
        return;
      case 'exam_practice':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PracticePage()),
        );
        return;
      case 'qso_log':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RadioLogPage()),
        );
        return;
      case 'study_calendar':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CalendarPage()),
        );
        return;
      case 'satellite_tracker':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SatelliteTrackerPage()),
        );
        return;
      case 'propagation_forecast':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PropagationForecastPage()),
        );
        return;
      case 'antenna_calculator':
        _openPlaceholder(
          context,
          '天线计算',
          Icons.settings_input_antenna,
          '计算天线长度、增益与常见换算。',
        );
        return;
      case 'walkie_calculator':
        _openPlaceholder(
          context,
          '对讲计算',
          Icons.calculate,
          '中继频差、亚音与常用参数计算。',
        );
        return;
      case 'tone_decoder':
        _openPlaceholder(
          context,
          '声码器',
          Icons.graphic_eq,
          'CTCSS / DCS / DTCS 查询功能正在接入。',
        );
        return;
      default:
        widget.onOpenTools?.call();
        return;
    }
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

class _HeroPanel extends StatelessWidget {
  final RadioProfile radioProfile;
  final VoidCallback onTitleTap;
  final VoidCallback onScanTap;

  const _HeroPanel({
    required this.radioProfile,
    required this.onTitleTap,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heroGradient = [
      scheme.primaryContainer.withValues(alpha: 0.72),
      scheme.surface,
      scheme.surfaceContainer,
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: heroGradient,
            ),
          ),
        ),
        Positioned(
          right: -28,
          top: 54,
          child: Icon(
            Icons.settings_input_antenna,
            size: 172,
            color: scheme.primary.withValues(alpha: 0.10),
          ),
        ),
        Positioned(
          right: 18,
          top: 48,
          child: _HeroScanButton(onTap: onScanTap),
        ),
        Positioned(
          left: 22,
          right: 22,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTitleTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beacon',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Beacon业余无线电工具箱',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                radioProfile.callsign,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.circle,
                                  color: Color(0xff52dc62), size: 9),
                              const SizedBox(width: 4),
                              Text('在线',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${radioProfile.qth} · ${radioProfile.grid}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '业余电台执照',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          radioProfile.licenseClass,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          radioProfile.licenseExpiry ==
                                  RadioProfile.defaults.licenseExpiry
                              ? radioProfile.licenseExpiry
                              : '${radioProfile.licenseExpiry} 到期',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroScanButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeroScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, color: scheme.onPrimary, size: 18),
              const SizedBox(width: 6),
              Text(
                '扫描',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConstrainedHomeContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ConstrainedHomeContent({
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(action),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ToolTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final String solarKp;
  final String solarF107;
  final String solarSource;
  final VoidCallback onSolarTap;

  const _InfoGrid({
    required this.solarKp,
    required this.solarF107,
    required this.solarSource,
    required this.onSolarTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        return SizedBox(
          height: compact ? 188 : 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MetricCard(
                  title: '实时信息',
                  value: '7.074.00',
                  unit: 'MHz',
                  chips: const ['40m', 'FT8'],
                  icon: Icons.graphic_eq,
                  note: '当前频率',
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: _MetricCard(
                  title: '太阳活动',
                  value: solarKp,
                  unit: solarF107,
                  chips: [solarSource],
                  icon: Icons.wb_sunny,
                  note: _solarKpStatus(solarKp),
                  imageUrl:
                      'https://sdo.gsfc.nasa.gov/assets/img/latest/latest_1024_0304.jpg',
                  onTap: onSolarTap,
                  compact: compact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final List<String> chips;
  final IconData icon;
  final VoidCallback? onTap;
  final String? imageUrl;
  final String? note;
  final bool compact;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.chips,
    required this.icon,
    this.onTap,
    this.imageUrl,
    this.note,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showVisual = imageUrl?.isNotEmpty == true;
    final visual = showVisual
        ? _MetricVisual(
            icon: icon,
            imageUrl: imageUrl,
            size: compact ? 54 : 72,
          )
        : Icon(icon, color: scheme.primary, size: compact ? 24 : 28);

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Container(
            padding: EdgeInsets.all(compact ? 12 : 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (!showVisual) ...[
                      const SizedBox(width: 6),
                      visual,
                    ],
                  ],
                ),
                SizedBox(height: compact ? 8 : 10),
                if (showVisual)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                          child: _MetricTextBlock(
                              value: value,
                              unit: unit,
                              note: note,
                              compact: compact)),
                      const SizedBox(width: 8),
                      visual,
                    ],
                  )
                else
                  _MetricTextBlock(
                    value: value,
                    unit: unit,
                    note: note,
                    compact: compact,
                  ),
                const Spacer(),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: chips
                      .map(
                        (chip) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            chip,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricTextBlock extends StatelessWidget {
  final String value;
  final String unit;
  final String? note;
  final bool compact;

  const _MetricTextBlock({
    required this.value,
    required this.unit,
    this.note,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unitParts = _splitMetricUnit(unit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: compact ? 22 : 24,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
        ),
        if (unitParts == null)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              unit,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          )
        else ...[
          Text(
            unitParts.$1,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            unitParts.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        if (note?.isNotEmpty == true) ...[
          const SizedBox(height: 3),
          Text(
            note!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

(String, String)? _splitMetricUnit(String unit) {
  final trimmed = unit.trim();
  final match = RegExp(r'^(F10\.7)\s+(.+)$').firstMatch(trimmed);
  if (match == null) return null;
  return (match.group(1)!, match.group(2)!);
}

class _MetricVisual extends StatelessWidget {
  final IconData icon;
  final String? imageUrl;
  final double size;

  const _MetricVisual({
    required this.icon,
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return Icon(icon, color: scheme.primary);
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(icon, color: scheme.primary),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(icon, color: scheme.primary, size: 28),
            );
          },
        ),
      ),
    );
  }
}

String _solarKpStatus(String kpLabel) {
  final value = double.tryParse(
    RegExp(r'(\d+(?:\.\d+)?)').firstMatch(kpLabel)?.group(1) ?? '',
  );
  if (value == null) return '等待太阳活动数据';
  if (value < 4) return '地磁平静';
  if (value < 5) return '轻微扰动';
  if (value < 7) return '地磁扰动';
  return '强扰动';
}

class _ExamPanel extends StatelessWidget {
  final bool isLoading;
  final int todayAnswered;
  final int weekAnswered;
  final double weekAccuracy;
  final int completedQuestions;
  final int totalQuestions;
  final int recentExamPassed;
  final int recentExamTotal;
  final String currentLibraryName;
  final VoidCallback onPractice;
  final VoidCallback onLeaderboard;

  const _ExamPanel({
    required this.isLoading,
    required this.todayAnswered,
    required this.weekAnswered,
    required this.weekAccuracy,
    required this.completedQuestions,
    required this.totalQuestions,
    required this.recentExamPassed,
    required this.recentExamTotal,
    required this.currentLibraryName,
    required this.onPractice,
    required this.onLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CRAC 考试训练',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ExamLibraryChip(label: currentLibraryName),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const LinearProgressIndicator()
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ExamInlineStat(
                              label: '今日答题',
                              value: '$todayAnswered 题',
                            ),
                          ),
                          Expanded(
                            child: _ExamInlineStat(
                              label: '本周正确率',
                              value: '${weekAccuracy.toStringAsFixed(1)}%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ExamInlineStat(
                              label: '近五次合格',
                              value: '$recentExamPassed/$recentExamTotal',
                            ),
                          ),
                          Expanded(
                            child: _ExamInlineStat(
                              label: '本周答题',
                              value: '$weekAnswered 题',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: totalQuestions == 0
                        ? 0
                        : (completedQuestions / totalQuestions)
                            .clamp(0, 1)
                            .toDouble(),
                    minHeight: 7,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '题库进度 $completedQuestions / $totalQuestions',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      totalQuestions == 0
                          ? '0%'
                          : '${(completedQuestions / totalQuestions * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPractice,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始练习'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onLeaderboard,
                icon: const Icon(Icons.query_stats),
                label: const Text('查看统计'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExamLibraryChip extends StatelessWidget {
  final String label;

  const _ExamLibraryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ExamInlineStat extends StatelessWidget {
  final String label;
  final String value;

  const _ExamInlineStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
