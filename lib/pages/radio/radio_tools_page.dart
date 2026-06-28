import 'package:flutter/material.dart';

import '../home/calendar_page.dart';
import '../practice/practice_page.dart';
import 'frequency_table_page.dart';
import 'callsign_lookup_page.dart';
import 'grid_map_page.dart';
import 'propagation_forecast_page.dart';
import 'radio_placeholder_page.dart';
import 'satellite_tracker_page.dart';

class RadioToolsPage extends StatefulWidget {
  const RadioToolsPage({super.key});

  @override
  State<RadioToolsPage> createState() => _RadioToolsPageState();
}

class _RadioToolsPageState extends State<RadioToolsPage> {
  int _categoryIndex = 0;

  final _categories = const ['全部', '计算', '频率', '传播', '日志', '考试', '其他'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tools = _visibleTools(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        title: const Text('工具'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final sidebarWidth = constraints.maxWidth < 380 ? 72.0 : 88.0;
          return Row(
            children: [
              _CategorySidebar(
                categories: _categories,
                selectedIndex: _categoryIndex,
                width: compact ? sidebarWidth : 104,
                compact: compact,
                onChanged: (index) => setState(() => _categoryIndex = index),
              ),
              Expanded(
                child: _ToolsList(
                  categories: _categories,
                  selectedCategoryIndex: _categoryIndex,
                  tools: tools,
                  compact: compact,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_RadioTool> _visibleTools(BuildContext context) {
    final selected = _categories[_categoryIndex];
    final tools = _tools(context);
    if (selected == '全部') return tools;
    return tools.where((tool) => tool.category == selected).toList();
  }

  List<_RadioTool> _tools(BuildContext context) {
    return [
      _RadioTool(
        '呼号查询',
        '查询电台信息、B站/QRZ 数据',
        Icons.search,
        const Color(0xff347cff),
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CallsignLookupPage()),
        ),
        category: '其他',
        isCommon: true,
      ),
      _RadioTool(
        'QTH 定位',
        '经纬度与 Maidenhead 网格定位',
        Icons.public,
        const Color(0xff5b73ff),
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GridMapPage()),
        ),
        category: '计算',
        isCommon: true,
      ),
      _RadioTool(
        '频率表',
        '业余频段划分与常用频率',
        Icons.radio,
        const Color(0xff38c77b),
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FrequencyTablePage()),
        ),
        category: '频率',
        isCommon: true,
      ),
      _RadioTool(
        '卫星追踪',
        '实时卫星位置与过境预报',
        Icons.satellite_alt,
        const Color(0xff3f8cff),
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SatelliteTrackerPage()),
        ),
        category: '传播',
        isCommon: true,
      ),
      _RadioTool(
        '天线计算器',
        '天线长度、增益等计算工具',
        Icons.settings_input_antenna,
        const Color(0xffef9743),
        () => _openPlaceholder(context, '天线计算器', Icons.settings_input_antenna),
        category: '计算',
        isCommon: true,
      ),
      _RadioTool(
        '声码器',
        'CTCSS / DCS / DTCS 查询',
        Icons.graphic_eq,
        const Color(0xff7357d9),
        () => _openPlaceholder(context, '声码器', Icons.graphic_eq),
        category: '频率',
        isCommon: true,
      ),
      _RadioTool(
        '传播预测',
        'HF 传播预测与电离层数据',
        Icons.cloud_queue,
        const Color(0xff4bc987),
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PropagationForecastPage()),
        ),
        category: '传播',
        isCommon: true,
      ),
      _RadioTool(
        '考试题库',
        'CRAC 题库、模拟考试与错题回顾',
        Icons.assignment,
        const Color(0xffffa33c),
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PracticePage()),
        ),
        category: '考试',
        isCommon: false,
      ),
      _RadioTool(
        '学习日历',
        '练习记录与活跃天数',
        Icons.calendar_month,
        const Color(0xff34aadc),
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CalendarPage()),
        ),
        category: '日志',
        isCommon: false,
      ),
    ];
  }

  void _openPlaceholder(BuildContext context, String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RadioPlaceholderPage(
          title: title,
          icon: icon,
          subtitle: '$title 功能正在接入，当前版本先提供统一入口。',
        ),
      ),
    );
  }
}

class _ToolsList extends StatelessWidget {
  final List<String> categories;
  final int selectedCategoryIndex;
  final List<_RadioTool> tools;
  final bool compact;

  const _ToolsList({
    required this.categories,
    required this.selectedCategoryIndex,
    required this.tools,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 18,
        compact ? 8 : 10,
        compact ? 10 : 18,
        110,
      ),
      children: [
        _ToolsOverview(
          selectedCategory: categories[selectedCategoryIndex],
          toolCount: tools.length,
          compact: compact,
        ),
        SizedBox(height: compact ? 10 : 14),
        for (var index = 0; index < tools.length; index++) ...[
          _ToolRow(tool: tools[index], compact: compact),
          if (index != tools.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CategorySidebar extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final double width;
  final bool compact;
  final ValueChanged<int> onChanged;

  const _CategorySidebar({
    required this.categories,
    required this.selectedIndex,
    required this.width,
    required this.compact,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(compact ? 6 : 8, 12, compact ? 6 : 8, 110),
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(height: compact ? 4 : 6),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return Material(
            color: selected ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(index),
              child: Container(
                height: compact ? 50 : 54,
                padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
                alignment: compact ? Alignment.center : Alignment.centerLeft,
                child: compact
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: selected ? 22 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              color: scheme.secondary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            categories[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 3,
                            height: selected ? 24 : 0,
                            decoration: BoxDecoration(
                              color: scheme.secondary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              categories[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToolsOverview extends StatelessWidget {
  final String selectedCategory;
  final int toolCount;
  final bool compact;

  const _ToolsOverview({
    required this.selectedCategory,
    required this.toolCount,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding:
          EdgeInsets.fromLTRB(14, compact ? 12 : 14, 14, compact ? 12 : 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          if (!compact) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.apps, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCategory == '全部' ? '全部工具' : '$selectedCategory工具',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: compact ? 17 : 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$toolCount 个入口，点击卡片进入对应工具',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: compact ? 12 : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final _RadioTool tool;
  final bool compact;

  const _ToolRow({
    required this.tool,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tool.onTap,
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 48 : 54,
                height: compact ? 48 : 54,
                decoration: BoxDecoration(
                  color: tool.color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tool.icon,
                    color: Colors.white, size: compact ? 26 : 30),
              ),
              SizedBox(width: compact ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: compact ? 16 : 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tool.subtitle,
                      maxLines: compact ? 2 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: compact ? 13 : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioTool {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String category;
  final bool isCommon;
  final VoidCallback onTap;

  const _RadioTool(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap, {
    required this.category,
    required this.isCommon,
  });
}
