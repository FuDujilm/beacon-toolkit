import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/frequency_allocation.dart';
import '../../services/frequency_allocation_service.dart';

class FrequencyTablePage extends StatefulWidget {
  const FrequencyTablePage({super.key});

  @override
  State<FrequencyTablePage> createState() => _FrequencyTablePageState();
}

class _FrequencyTablePageState extends State<FrequencyTablePage> {
  final _service = FrequencyAllocationService();
  final _searchController = TextEditingController();

  List<FrequencyAllocation> _items = const [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _selectedService = '';
  String _selectedRegion = 'CN';
  Object? _error;
  DateTime? _loadedAt;

  static const _services = ['', '业余', '卫星', '固定', '移动', '广播', '导航', '数字'];
  static const _regions = {
    'CN': '中国大陆',
    'HK': '中国香港',
    'MO': '中国澳门',
    'TW': '中国台湾',
    'ITU3': 'ITU 3区',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = !forceRefresh;
      _isSyncing = forceRefresh;
      _error = null;
    });
    try {
      final items = await _service.getAllocations(
        region: _selectedRegion,
        service: _selectedService.isEmpty ? null : _selectedService,
        query: _searchController.text,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loadedAt = DateTime.now();
        _isLoading = false;
        _isSyncing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sections = _visibleSections;
    return Scaffold(
      appBar: AppBar(
        title: const Text('频率划分'),
        actions: [
          IconButton(
            tooltip: '同步',
            onPressed: _isSyncing ? null : () => _load(forceRefresh: true),
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (_error != null)
                    _InlineMessage(
                      icon: Icons.cloud_off,
                      message: '无法连接 beacon-api，已显示本地数据。',
                      color: scheme.error,
                    ),
                  SearchBar(
                    controller: _searchController,
                    hintText: '搜索波段、业务、脚注或频率',
                    leading: const Icon(Icons.search),
                    trailing: [
                      IconButton(
                        tooltip: '搜索',
                        onPressed: _load,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                    onSubmitted: (_) => _load(),
                  ),
                  const SizedBox(height: 12),
                  _RegionDropdown(
                    value: _selectedRegion,
                    regions: _regions,
                    onChanged: (value) {
                      if (value == null || value == _selectedRegion) return;
                      setState(() => _selectedRegion = value);
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final service in _services)
                        FilterChip(
                          selected: _selectedService == service,
                          label: Text(service.isEmpty ? '全部' : service),
                          selectedColor: _serviceColor(service)
                              .withValues(alpha: service.isEmpty ? 0.12 : 0.22),
                          checkmarkColor: _serviceColor(service),
                          side: BorderSide(
                            color: _selectedService == service
                                ? _serviceColor(service)
                                : scheme.outlineVariant,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedService = service);
                            _load();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InlineMessage(
                    icon: Icons.info_outline,
                    message:
                        '来源：无线电频率划分规定.pdf 第33-142页，${_regions[_selectedRegion] ?? _selectedRegion}列。${_loadedAt == null ? '' : ' 本次加载 ${DateFormat('HH:mm').format(_loadedAt!)}'}',
                    color: scheme.primary,
                  ),
                  if (sections.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text('没有匹配的频率划分')),
                    )
                  else
                    _SpectrumSectionView(sections: sections),
                  const SizedBox(height: 12),
                  const _Legend(),
                ],
              ),
            ),
    );
  }

  List<_FrequencySectionData> get _visibleSections {
    final query = _searchController.text.trim();
    final sections = <_FrequencySectionData>[];
    for (final band in _frequencyBands) {
      final allocations = _allocationsForBand(band);
      final textMatch = query.isEmpty ||
          band.name.contains(query) ||
          band.rangeLabel.contains(query) ||
          band.description.contains(query) ||
          band.tags.any((tag) => tag.contains(query)) ||
          allocations.any((item) =>
              _allocationRangeLabel(item).contains(query) ||
              item.services.any((service) => service.contains(query)) ||
              item.footnotes.any((footnote) => footnote.contains(query)));
      final serviceMatch = _selectedService.isEmpty ||
          band.tags.any((tag) => tag.contains(_selectedService)) ||
          allocations.any((item) => item.services
              .any((service) => service.contains(_selectedService)));
      if (textMatch &&
          serviceMatch &&
          (band.isPinned || allocations.isNotEmpty)) {
        sections
            .add(_FrequencySectionData(band: band, allocations: allocations));
      }
    }
    return sections;
  }

  List<FrequencyAllocation> _allocationsForBand(_FrequencyBand band) {
    return _items.where((item) {
      final lower = _normalizeMhz(item.lowerMhz);
      final upper = _normalizeRangeUpper(item.lowerMhz, item.upperMhz);
      return lower < band.upperMhz && upper > band.lowerMhz;
    }).toList();
  }
}

class _SpectrumSectionView extends StatelessWidget {
  final List<_FrequencySectionData> sections;

  const _SpectrumSectionView({required this.sections});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(
        children: [
          for (var index = 0; index < sections.length; index++)
            _SpectrumBandRow(
              data: sections[index],
              isFirst: index == 0,
              isLast: index == sections.length - 1,
            ),
        ],
      ),
    );
  }
}

class _RegionDropdown extends StatelessWidget {
  final String value;
  final Map<String, String> regions;
  final ValueChanged<String?> onChanged;

  const _RegionDropdown({
    required this.value,
    required this.regions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.expand_more),
            borderRadius: BorderRadius.circular(12),
            items: [
              for (final entry in regions.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(Icons.public, size: 18, color: scheme.primary),
                      const SizedBox(width: 10),
                      Text(entry.value),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _SpectrumBandRow extends StatelessWidget {
  final _FrequencySectionData data;
  final bool isFirst;
  final bool isLast;

  const _SpectrumBandRow({
    required this.data,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 72,
            child: _AxisSegment(
              band: data.band,
              isFirst: isFirst,
              isLast: isLast,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _BandCard(data: data)),
        ],
      ),
    );
  }
}

class _AxisSegment extends StatelessWidget {
  final _FrequencyBand band;
  final bool isFirst;
  final bool isLast;

  const _AxisSegment({
    required this.band,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _axisLabelFor(band),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  height: 1,
                  color: scheme.outlineVariant,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 46,
          top: isFirst ? 8 : 0,
          bottom: isLast ? 20 : 0,
          width: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(
                top: isFirst ? const Radius.circular(999) : Radius.zero,
                bottom: isLast ? const Radius.circular(999) : Radius.zero,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.10),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: isFirst ? const Radius.circular(999) : Radius.zero,
                bottom: isLast ? const Radius.circular(999) : Radius.zero,
              ),
              child: ColoredBox(color: band.color),
            ),
          ),
        ),
      ],
    );
  }
}

class _BandCard extends StatelessWidget {
  final _FrequencySectionData data;

  const _BandCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final band = data.band;
    final allocations = data.allocations;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        leading: Container(
          width: 4,
          height: 88,
          decoration: BoxDecoration(
            color: band.color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        title: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 128),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        band.name,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: band.color,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        band.rangeLabel,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in band.tags) _ServiceTag(label: tag),
                  if (allocations.isNotEmpty)
                    _MutedTag(label: '${allocations.length} 条'),
                ],
              ),
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              band.description,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 10),
          if (allocations.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '暂无本地详细划分。同步 beacon-api 后会显示 PDF 业务类型和脚注。',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            for (final item in allocations) _AllocationTile(item: item),
        ],
      ),
    );
  }
}

class _AllocationTile extends StatelessWidget {
  final FrequencyAllocation item;

  const _AllocationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Center(
              child: Container(
                width: 3,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _allocationRangeLabel(item),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final service in item.services)
                      _ServiceTag(label: _compactTagLabel(service)),
                    for (final footnote in item.footnotes)
                      _MutedTag(label: _compactTagLabel(footnote)),
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _LegendItem(label: '业余'),
            _LegendItem(label: '卫星'),
            _LegendItem(label: '固定'),
            _LegendItem(label: '移动'),
            _LegendItem(label: '导航'),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;

  const _LegendItem({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _serviceColor(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ],
    );
  }
}

class _ServiceTag extends StatelessWidget {
  final String label;

  const _ServiceTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _serviceColor(label);
    return Container(
      constraints: const BoxConstraints(maxWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MutedTag extends StatelessWidget {
  final String label;

  const _MutedTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InlineMessage({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _FrequencySectionData {
  final _FrequencyBand band;
  final List<FrequencyAllocation> allocations;

  const _FrequencySectionData({
    required this.band,
    required this.allocations,
  });
}

class _FrequencyBand {
  final String name;
  final double lowerMhz;
  final double upperMhz;
  final String description;
  final List<String> tags;
  final Color color;
  final bool isPinned;

  const _FrequencyBand({
    required this.name,
    required this.lowerMhz,
    required this.upperMhz,
    required this.description,
    required this.tags,
    required this.color,
    this.isPinned = false,
  });

  String get rangeLabel {
    return '${_formatFrequencyValue(lowerMhz)} - ${_formatFrequencyValue(upperMhz)}';
  }
}

const _frequencyBands = [
  _FrequencyBand(
    name: 'VLF/LF',
    lowerMhz: 0.0,
    upperMhz: 0.3,
    description: '0-300kHz 低频端划分，包含水上、导航、气象辅助等业务。',
    tags: ['固定', '移动', '导航', '气象'],
    color: Color(0xff546e7a),
  ),
  _FrequencyBand(
    name: 'MF',
    lowerMhz: 0.3,
    upperMhz: 1.8,
    description: '300kHz-1.8MHz 中频划分，覆盖广播、移动和导航等业务。',
    tags: ['广播', '移动', '导航'],
    color: Color(0xff78909c),
  ),
  _FrequencyBand(
    name: '160m',
    lowerMhz: 1.8,
    upperMhz: 2.0,
    description: '业余低频远距离通信，常用于 CW、SSB 和数字模式。',
    tags: ['业余', 'CW', 'SSB', '数字'],
    color: Color(0xff7c4dff),
    isPinned: true,
  ),
  _FrequencyBand(
    name: 'HF',
    lowerMhz: 2.0,
    upperMhz: 30.0,
    description: '2-30MHz 短波完整划分，除常用业余卡片外继续显示固定、移动、广播等业务。',
    tags: ['固定', '移动', '广播', '业余'],
    color: Color(0xff00897b),
  ),
  _FrequencyBand(
    name: '80m',
    lowerMhz: 3.5,
    upperMhz: 4.0,
    description: '夜间传播表现稳定，适合本地和区域通信。',
    tags: ['业余', 'CW', 'SSB', '数字'],
    color: Color(0xff42a5f5),
    isPinned: true,
  ),
  _FrequencyBand(
    name: '40m',
    lowerMhz: 7.0,
    upperMhz: 7.3,
    description: '短波核心波段，兼顾白天区域和夜间远距离。',
    tags: ['业余', 'CW', 'SSB', '数字'],
    color: Color(0xff66bb6a),
    isPinned: true,
  ),
  _FrequencyBand(
    name: '20m',
    lowerMhz: 14.0,
    upperMhz: 14.35,
    description: '国际远距离通联常用波段。',
    tags: ['业余', 'CW', 'SSB', '数字'],
    color: Color(0xffffb300),
    isPinned: true,
  ),
  _FrequencyBand(
    name: '15m',
    lowerMhz: 21.0,
    upperMhz: 21.45,
    description: '电离层条件较好时适合远距离通信。',
    tags: ['业余', 'CW', 'SSB', '数字'],
    color: Color(0xffff7043),
    isPinned: true,
  ),
  _FrequencyBand(
    name: '10m',
    lowerMhz: 28.0,
    upperMhz: 29.7,
    description: '高频段，支持 SSB、FM、数字和卫星相关应用。',
    tags: ['业余', 'SSB', 'FM', '数字', '卫星'],
    color: Color(0xff7e57c2),
    isPinned: true,
  ),
  _FrequencyBand(
    name: 'VHF',
    lowerMhz: 30.0,
    upperMhz: 300.0,
    description: '30-300MHz VHF 完整划分，包含广播、固定、移动、导航及业余业务。',
    tags: ['广播', '固定', '移动', '导航', '业余'],
    color: Color(0xff0097a7),
  ),
  _FrequencyBand(
    name: '6m',
    lowerMhz: 50.0,
    upperMhz: 54.0,
    description: 'VHF 低端，适合本地通信和特殊传播窗口。',
    tags: ['业余', 'SSB', 'FM', '数字'],
    color: Color(0xff64b5f6),
    isPinned: true,
  ),
  _FrequencyBand(
    name: '2m',
    lowerMhz: 144.0,
    upperMhz: 148.0,
    description: 'VHF 常用波段，适合中继、手台和卫星通联。',
    tags: ['业余', 'FM', '数字', '卫星'],
    color: Color(0xff81c784),
    isPinned: true,
  ),
  _FrequencyBand(
    name: 'UHF',
    lowerMhz: 300.0,
    upperMhz: 420.0,
    description: '300-420MHz UHF 划分，继续显示 PDF 中固定、移动、卫星等业务。',
    tags: ['固定', '移动', '卫星', '导航'],
    color: Color(0xff00acc1),
  ),
  _FrequencyBand(
    name: '70cm',
    lowerMhz: 420.0,
    upperMhz: 450.0,
    description: 'UHF 常用波段，适合中继、热点和卫星通联。',
    tags: ['业余', 'FM', '数字', '卫星'],
    color: Color(0xffff8a50),
    isPinned: true,
  ),
  _FrequencyBand(
    name: 'UHF+',
    lowerMhz: 450.0,
    upperMhz: 1000.0,
    description: '450MHz 至 1GHz 范围内的完整 PDF 频率划分。',
    tags: ['固定', '移动', '导航', '广播'],
    color: Color(0xff26a69a),
  ),
  _FrequencyBand(
    name: 'L/S',
    lowerMhz: 1000.0,
    upperMhz: 4000.0,
    description: '1-4GHz 微波频段，包含卫星、定位、固定和移动等业务。',
    tags: ['卫星', '固定', '移动', '定位'],
    color: Color(0xff5c6bc0),
  ),
  _FrequencyBand(
    name: 'C/X',
    lowerMhz: 4000.0,
    upperMhz: 12000.0,
    description: '4-12GHz 微波频段，显示法规表中的完整划分。',
    tags: ['卫星', '固定', '移动', '导航'],
    color: Color(0xff8e24aa),
  ),
  _FrequencyBand(
    name: 'Ku/Ka',
    lowerMhz: 12000.0,
    upperMhz: 40000.0,
    description: '12-40GHz 高频微波频段，覆盖 PDF 中的 GHz 级划分。',
    tags: ['卫星', '固定', '移动'],
    color: Color(0xffd81b60),
  ),
  _FrequencyBand(
    name: 'EHF',
    lowerMhz: 40000.0,
    upperMhz: 300000.0,
    description: '40-300GHz 毫米波频段，继续展示 PDF 高频端数据。',
    tags: ['固定', '移动', '卫星'],
    color: Color(0xff6d4c41),
  ),
  _FrequencyBand(
    name: 'THF',
    lowerMhz: 300000.0,
    upperMhz: 3000000.0,
    description: '300-3000GHz 高频端划分，覆盖 PDF 表格末尾的 GHz 数据。',
    tags: ['固定', '移动', '卫星', '未划分'],
    color: Color(0xff455a64),
  ),
];

String _axisLabelFor(_FrequencyBand band) {
  if (band.lowerMhz >= 1000) {
    return _formatFrequencyValue(band.lowerMhz, compact: true);
  }
  if (band.lowerMhz >= 100) return band.lowerMhz.toStringAsFixed(0);
  if (band.lowerMhz >= 10) return band.lowerMhz.toStringAsFixed(0);
  return band.lowerMhz.toStringAsFixed(
    band.lowerMhz.truncateToDouble() == band.lowerMhz ? 0 : 1,
  );
}

String _allocationRangeLabel(FrequencyAllocation item) {
  final lower = _normalizeMhz(item.lowerMhz);
  final upper = _normalizeRangeUpper(item.lowerMhz, item.upperMhz);
  return '${_formatFrequencyValue(lower)} - ${_formatFrequencyValue(upper)}';
}

double _normalizeRangeUpper(double lower, double upper) {
  final normalizedUpper = _normalizeMhz(upper);
  final normalizedLower = _normalizeMhz(lower);
  if (normalizedUpper > 1000 && normalizedLower < 1000) {
    final raw = normalizedUpper.toStringAsFixed(0);
    if (raw.length >= 6) {
      final head = double.tryParse(raw.substring(0, 3));
      if (head != null && head > normalizedLower && head < 1000) {
        return head;
      }
    }
    final lowerPrefix = normalizedLower.floor().toString();
    if (raw.startsWith(lowerPrefix) && raw.length > lowerPrefix.length) {
      final tail = raw.substring(lowerPrefix.length);
      final parsed = double.tryParse(tail);
      if (parsed != null && parsed > normalizedLower && parsed < 1000) {
        return parsed;
      }
    }
  }
  return normalizedUpper;
}

double _normalizeMhz(double value) {
  return value;
}

String _formatFrequencyValue(double mhz, {bool compact = false}) {
  if (mhz >= 1000) {
    final ghz = mhz / 1000;
    final digits = compact || ghz >= 10 ? 0 : 3;
    return '${ghz.toStringAsFixed(digits)} GHz';
  }
  return '${mhz.toStringAsFixed(3)} MHz';
}

String _compactTagLabel(String value) {
  return value
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('无线电定位', '定位')
      .replaceAll('无线电导航', '导航')
      .replaceAll('卫星业余', '卫星业余')
      .replaceAll('业余卫星', '卫星业余');
}

Color _serviceColor(String value) {
  if (value.contains('CW')) return const Color(0xff7c4dff);
  if (value.contains('SSB')) return const Color(0xff42a5f5);
  if (value.contains('FM')) return const Color(0xff43a047);
  if (value.contains('数字')) return const Color(0xffffb300);
  if (value.contains('卫星')) return const Color(0xff26a69a);
  if (value.contains('业余')) return const Color(0xff7c4dff);
  if (value.contains('广播')) return const Color(0xfff9a825);
  if (value.contains('固定')) return const Color(0xff2e7d32);
  if (value.contains('移动')) return const Color(0xff1976d2);
  if (value.contains('定位')) return const Color(0xff00838f);
  if (value.contains('导航')) return const Color(0xff6d4c41);
  if (value.contains('气象')) return const Color(0xff00838f);
  if (value.contains('标准')) return const Color(0xffad1457);
  return const Color(0xff607d8b);
}
