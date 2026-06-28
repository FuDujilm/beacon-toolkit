import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as osm;
import 'package:url_launcher/url_launcher.dart';

import '../../models/discovery.dart';
import '../../models/radio_profile.dart';
import '../../services/discovery_preferences_service.dart';
import '../../services/local_database_service.dart';
import '../../services/satellite_observer_service.dart';
import '../../services/satellite_service.dart';
import '../discovery/satellite_detail_page.dart';
import 'radio_theme.dart';

class SatelliteTrackerPage extends StatefulWidget {
  const SatelliteTrackerPage({super.key});

  @override
  State<SatelliteTrackerPage> createState() => _SatelliteTrackerPageState();
}

class _SatelliteTrackerPageState extends State<SatelliteTrackerPage> {
  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('卫星追踪'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SatelliteToolCard(
            title: '订阅卫星地图',
            subtitle: '在 OpenStreetMap 上查看订阅卫星位置、轨迹和过境状态',
            icon: Icons.map,
            color: const Color(0xff3f8cff),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SatelliteSubscribedMapPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SatelliteToolCard(
            title: '订阅卫星',
            subtitle: '从 TLE 源搜索卫星，管理订阅和显示顺序',
            icon: Icons.playlist_add_check,
            color: const Color(0xff20d174),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SatelliteSubscriptionPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SatelliteToolCard(
            title: '卫星信息',
            subtitle: '查看订阅卫星资料、转发器、过境和轨道数据',
            icon: Icons.info_outline,
            color: const Color(0xffffb547),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SatelliteInfoPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SatelliteToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SatelliteToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Material(
      color: colors.panelAlt,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class SatelliteSubscribedMapPage extends StatefulWidget {
  const SatelliteSubscribedMapPage({super.key});

  @override
  State<SatelliteSubscribedMapPage> createState() =>
      _SatelliteSubscribedMapPageState();
}

class _SatelliteSubscribedMapPageState
    extends State<SatelliteSubscribedMapPage> {
  final _preferencesService = DiscoveryPreferencesService();
  final _databaseService = LocalDatabaseService();
  final _satelliteService = SatelliteService();
  late final SatelliteObserverService _observerService;

  DiscoveryPreferences _preferences = const DiscoveryPreferences();
  RadioProfile _radioProfile = RadioProfile.defaults;
  SatelliteObserverState? _observerState;
  List<SatelliteMapItem> _mapItems = const [];
  String? _focusedSatellite;
  Object? _error;
  bool _isLoading = true;
  double? _heading;
  Timer? _refreshTimer;
  StreamSubscription<double>? _headingSubscription;

  @override
  void initState() {
    super.initState();
    _observerService = SatelliteObserverService(
      satelliteService: _satelliteService,
    );
    _headingSubscription = _observerService.headingStream.listen(
      (heading) {
        if (mounted) setState(() => _heading = heading);
      },
      onError: (_) {},
    );
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _headingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load({String? satellite}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = _mapItems.isEmpty;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _preferencesService.getPreferences(),
        _databaseService.getRadioProfile(),
      ]);
      final preferences = results[0] as DiscoveryPreferences;
      final radioProfile = results[1] as RadioProfile;
      final observerState = await _observerService.resolveLocation(
        radioProfile.grid,
      );
      final observer = observerState.location;
      if (observer == null) {
        throw const FormatException('请在我的资料中设置有效 Grid，或授予定位权限');
      }
      final items = await _satelliteService.getSubscribedSatelliteMapItems(
        observer: observer,
        tleSourceUrls: preferences.tleSourceUrls,
        satelliteNames: preferences.satelliteNames,
      );
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _radioProfile = radioProfile;
        _observerState = observerState;
        _mapItems = items;
        _focusedSatellite = satellite ?? _focusedSatellite;
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

  bool _sameSatellite(String a, String b) {
    final aa = a.toUpperCase();
    final bb = b.toUpperCase();
    return aa.contains(bb) || bb.contains(aa);
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    final observer = _observerState?.location;
    final focusedItem = _focusedSatellite == null
        ? null
        : _mapItems
            .where((item) => _sameSatellite(item.name, _focusedSatellite!))
            .cast<SatelliteMapItem?>()
            .firstOrNull;

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('订阅卫星地图'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _mapItems.isEmpty
              ? _TrackerStateMessage(
                  title: '无法加载订阅卫星地图',
                  subtitle: _error.toString(),
                  action: FilledButton.icon(
                    onPressed: () => _load(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      if (_error != null)
                        _InlineWarning(message: _error.toString()),
                      _MapHeader(
                        items: _mapItems,
                        focusedItem: focusedItem,
                        observer: observer,
                        observerStatus: _observerState?.status ?? '',
                      ),
                      const SizedBox(height: 12),
                      _MapSatelliteSelector(
                        items: _mapItems,
                        focusedSatellite: _focusedSatellite,
                        onSelected: (name) {
                          setState(() => _focusedSatellite = name);
                        },
                      ),
                      const SizedBox(height: 12),
                      _SubscribedWorldMapPanel(
                        observer: observer,
                        items: _mapItems,
                        focusedItem: focusedItem,
                        onFocus: (name) {
                          setState(() => _focusedSatellite = name);
                        },
                      ),
                      if (focusedItem?.nextPass != null) ...[
                        const SizedBox(height: 12),
                        _SkyRadarPanel(
                          pass: focusedItem!.nextPass,
                          heading: _heading,
                        ),
                        const SizedBox(height: 12),
                        _DopplerEstimatePanel(pass: focusedItem.nextPass!),
                        const SizedBox(height: 12),
                        _TrackerPanel(
                          title: '聚焦卫星',
                          icon: Icons.satellite_alt,
                          action: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SatelliteDetailPage(
                                    satelliteName: focusedItem.name,
                                    radioProfile: _radioProfile,
                                    tleSourceUrls: _preferences.tleSourceUrls,
                                    service: _satelliteService,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('详情'),
                          ),
                          child: _MapItemSummary(item: focusedItem),
                        ),
                      ],
                      if (_mapItems.isEmpty) ...[
                        const SizedBox(height: 12),
                        _TrackerPanel(
                          title: '暂无订阅',
                          icon: Icons.playlist_add,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SatelliteSubscriptionPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('去订阅卫星'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _MapHeader extends StatelessWidget {
  final List<SatelliteMapItem> items;
  final SatelliteMapItem? focusedItem;
  final ObserverLocation? observer;
  final String observerStatus;

  const _MapHeader({
    required this.items,
    required this.focusedItem,
    required this.observer,
    required this.observerStatus,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    final visible = items.where((item) => item.currentPosition != null).length;
    final nextPass = focusedItem?.nextPass ??
        items
            .map((item) => item.nextPass)
            .whereType<SatellitePass>()
            .fold<SatellitePass?>(null, (best, pass) {
          if (best == null || pass.aos.isBefore(best.aos)) return pass;
          return best;
        });
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colors.panelAlt,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xff3f8cff),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.map, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      focusedItem?.name ?? '全部订阅卫星',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${items.length} 颗订阅 · $visible 颗有当前位置',
                      style: TextStyle(color: colors.muted),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: nextPass == null
                    ? '暂无过境'
                    : 'AOS ${DateFormat('HH:mm').format(nextPass.aos)}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(label: '订阅', value: '${items.length}'),
              ),
              const Expanded(
                child: _HeaderMetric(label: '地图', value: 'OSM'),
              ),
              Expanded(
                child: _HeaderMetric(
                  label: '观测点',
                  value: observer?.source ?? '--',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            observer == null
                ? observerStatus
                : '${observer!.label} · $observerStatus',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MapSatelliteSelector extends StatelessWidget {
  final List<SatelliteMapItem> items;
  final String? focusedSatellite;
  final ValueChanged<String?> onSelected;

  const _MapSatelliteSelector({
    required this.items,
    required this.focusedSatellite,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final name = isAll ? null : items[index - 1].name;
          final selected = isAll
              ? focusedSatellite == null
              : focusedSatellite != null &&
                  (focusedSatellite!
                          .toUpperCase()
                          .contains(name!.toUpperCase()) ||
                      name
                          .toUpperCase()
                          .contains(focusedSatellite!.toUpperCase()));
          return ChoiceChip(
            label: Text(isAll ? '全部' : name!, overflow: TextOverflow.ellipsis),
            selected: selected,
            onSelected: (_) => onSelected(name),
            selectedColor: const Color(0xff3f8cff),
            labelStyle: TextStyle(
              color: selected ? Colors.white : colors.text,
              fontWeight: FontWeight.w800,
            ),
          );
        },
      ),
    );
  }
}

class _MapItemSummary extends StatelessWidget {
  final SatelliteMapItem item;

  const _MapItemSummary({required this.item});

  @override
  Widget build(BuildContext context) {
    final pass = item.nextPass;
    return Column(
      children: [
        _InfoLine('卫星', item.name),
        _InfoLine('NORAD', item.noradCatId?.toString() ?? '--'),
        _InfoLine(
          '下一次 AOS',
          pass == null ? '--' : DateFormat('MM-dd HH:mm').format(pass.aos),
        ),
        _InfoLine(
          '最高仰角',
          pass == null ? '--' : '${pass.maxElevation.toStringAsFixed(0)}°',
        ),
      ],
    );
  }
}

class _SkyRadarPanel extends StatelessWidget {
  final SatellitePass? pass;
  final double? heading;

  const _SkyRadarPanel({required this.pass, required this.heading});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    final currentAzimuth = pass?.currentAzimuth ??
        (pass == null ? null : (pass!.aosAzimuth + pass!.losAzimuth) / 2);
    final delta = heading == null || currentAzimuth == null
        ? null
        : _bearingDelta(heading!, currentAzimuth);
    return _TrackerPanel(
      title: '天空雷达',
      icon: Icons.radar,
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: pass == null
                ? Center(
                    child: Text('未来窗口暂无可见过境',
                        style: TextStyle(color: colors.muted)),
                  )
                : CustomPaint(
                    painter: _SkyRadarPainter(
                      pass: pass!,
                      heading: heading,
                      colors: colors,
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniInfo(
                  label: '手机朝向',
                  value: heading == null
                      ? '--'
                      : '${heading!.toStringAsFixed(0)}°',
                ),
              ),
              Expanded(
                child: _MiniInfo(
                  label: '目标方位',
                  value: currentAzimuth == null
                      ? '--'
                      : '${currentAzimuth.toStringAsFixed(0)}°',
                ),
              ),
              Expanded(
                child: _MiniInfo(
                  label: '偏差',
                  value: delta == null
                      ? '--'
                      : '${delta.abs().toStringAsFixed(0)}°',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DopplerEstimatePanel extends StatelessWidget {
  final SatellitePass pass;

  const _DopplerEstimatePanel({required this.pass});

  static const _bands = <_DopplerBand>[
    _DopplerBand(label: '2m', frequencyHz: 145800000),
    _DopplerBand(label: '70cm', frequencyHz: 435000000),
    _DopplerBand(label: '23cm', frequencyHz: 1260000000),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return _TrackerPanel(
      title: '多普勒频移',
      icon: Icons.graphic_eq,
      child: StreamBuilder<DateTime>(
        stream: Stream<DateTime>.periodic(
          const Duration(seconds: 1),
          (_) => DateTime.now(),
        ),
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          final currentPoint = _currentDopplerPoint(pass, now);
          final points = [
            if (currentPoint != null) currentPoint,
            ..._dopplerPoints(pass),
          ];
          if (points.isEmpty) {
            return Text(
              '当前过境数据缺少有效多普勒采样。',
              style: TextStyle(color: colors.muted),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pass.isActive
                    ? '正在按当前时间实时估算频移，下面同时保留 AOS / TCA / LOS 预测值。'
                    : '当前未过境，先显示下一次过境的 AOS / TCA / LOS 预测值。',
                style: TextStyle(color: colors.muted, height: 1.45),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 42,
                  dataRowMaxHeight: 50,
                  columnSpacing: 14,
                  horizontalMargin: 8,
                  columns: const [
                    DataColumn(label: Text('时刻')),
                    DataColumn(label: Text('因子')),
                    DataColumn(label: Text('2m 偏移')),
                    DataColumn(label: Text('70cm 偏移')),
                    DataColumn(label: Text('23cm 偏移')),
                  ],
                  rows: [
                    for (final point in points)
                      DataRow(
                        selected: point.isCurrent,
                        cells: [
                          DataCell(Text(point.label)),
                          DataCell(Text(point.factor.toStringAsFixed(8))),
                          for (final band in _bands)
                            DataCell(Text(_dopplerOffset(
                              band.frequencyHz,
                              point.factor,
                            ))),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final band in _bands)
                    _DopplerBandChip(
                      label: band.label,
                      frequency: _formatDopplerBaseFrequency(band.frequencyHz),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DopplerBandChip extends StatelessWidget {
  final String label;
  final String frequency;

  const _DopplerBandChip({
    required this.label,
    required this.frequency,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xff3f8cff).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        '$label · $frequency',
        style: TextStyle(
          color: colors.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DopplerBand {
  final String label;
  final int frequencyHz;

  const _DopplerBand({
    required this.label,
    required this.frequencyHz,
  });
}

class _DopplerPassPoint {
  final String label;
  final double factor;
  final bool isCurrent;

  const _DopplerPassPoint({
    required this.label,
    required this.factor,
    this.isCurrent = false,
  });
}

class _SubscribedWorldMapPanel extends StatelessWidget {
  final ObserverLocation? observer;
  final List<SatelliteMapItem> items;
  final SatelliteMapItem? focusedItem;
  final ValueChanged<String> onFocus;

  const _SubscribedWorldMapPanel({
    required this.observer,
    required this.items,
    required this.focusedItem,
    required this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = focusedItem == null ? items : [focusedItem!];
    final firstPosition = visibleItems
        .map((item) => item.currentPosition)
        .whereType<GroundTrackPoint>()
        .firstOrNull;
    final center = firstPosition == null
        ? observer == null
            ? const osm.LatLng(0, 0)
            : osm.LatLng(observer!.latitude, observer!.longitude)
        : osm.LatLng(firstPosition.latitude, firstPosition.longitude);
    final trackSegments =
        visibleItems.expand((item) => _splitTrack(item.groundTrack)).toList();
    final markers = <Marker>[
      if (observer != null)
        Marker(
          point: osm.LatLng(observer!.latitude, observer!.longitude),
          width: 44,
          height: 44,
          child: const Tooltip(
            message: '观测点',
            child: _MapMarker(
              icon: Icons.my_location,
              color: Color(0xff20d174),
            ),
          ),
        ),
      ...visibleItems.where((item) => item.currentPosition != null).map(
            (item) => Marker(
              point: osm.LatLng(
                item.currentPosition!.latitude,
                item.currentPosition!.longitude,
              ),
              width: 48,
              height: 48,
              child: Tooltip(
                message: item.name,
                child: GestureDetector(
                  onTap: () => onFocus(item.name),
                  child: const _MapMarker(
                    icon: Icons.satellite_alt,
                    color: Color(0xffffb547),
                  ),
                ),
              ),
            ),
          ),
    ];

    return _TrackerPanel(
      title: 'OpenStreetMap 轨迹',
      icon: Icons.public,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 260,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: focusedItem == null ? 1.4 : 2.8,
              minZoom: 1,
              maxZoom: 8,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'work.hamcy.exam.beacon',
              ),
              if (trackSegments.isNotEmpty)
                PolylineLayer(
                  polylines: trackSegments
                      .map(
                        (segment) => Polyline(
                          points: segment,
                          color: const Color(0xff3f8cff),
                          strokeWidth: 3,
                        ),
                      )
                      .toList(),
                ),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<List<osm.LatLng>> _splitTrack(List<GroundTrackPoint> points) {
    if (points.isEmpty) return const [];
    final segments = <List<osm.LatLng>>[];
    var current = <osm.LatLng>[];
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      if (index > 0) {
        final previous = points[index - 1];
        if ((point.longitude - previous.longitude).abs() > 180 &&
            current.isNotEmpty) {
          segments.add(current);
          current = <osm.LatLng>[];
        }
      }
      current.add(osm.LatLng(point.latitude, point.longitude));
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }
}

class _MapMarker extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MapMarker({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class SatelliteSubscriptionPage extends StatefulWidget {
  const SatelliteSubscriptionPage({super.key});

  @override
  State<SatelliteSubscriptionPage> createState() =>
      _SatelliteSubscriptionPageState();
}

class _SatelliteSubscriptionPageState extends State<SatelliteSubscriptionPage> {
  final _preferencesService = DiscoveryPreferencesService();
  final _satelliteService = SatelliteService();
  final _searchController = TextEditingController();

  DiscoveryPreferences _preferences = const DiscoveryPreferences();
  List<SatelliteCatalogItem> _results = const [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  Object? _error;

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

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final preferences = await _preferencesService.getPreferences();
      final results = await _satelliteService.searchSatellites(
        query: _searchController.text,
        tleSourceUrls: preferences.tleSourceUrls,
        subscribedNames: preferences.satelliteNames,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _results = results;
        _page = 1;
        _hasMore = results.length >= 50;
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

  Future<void> _search({bool loadMore = false}) async {
    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isSearching = true;
      }
      _error = null;
    });
    try {
      final page = loadMore ? _page + 1 : 1;
      final results = await _satelliteService.searchSatellites(
        query: _searchController.text,
        tleSourceUrls: _preferences.tleSourceUrls,
        subscribedNames: _preferences.satelliteNames,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _results = loadMore ? [..._results, ...results] : results;
        _page = page;
        _hasMore = results.length >= 50;
        _isSearching = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isSearching = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _saveNames(List<String> names) async {
    final preferences = _preferences.copyWith(satelliteNames: names);
    await _preferencesService.savePreferences(preferences);
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _results = _results
          .map((item) => item.copyWith(
                subscribed:
                    names.any((name) => _sameSatellite(name, item.name)),
              ))
          .toList();
    });
  }

  Future<void> _toggleSatellite(SatelliteCatalogItem item) async {
    final names = [..._preferences.satelliteNames];
    final exists = names.any((name) => _sameSatellite(name, item.name));
    if (exists) {
      names.removeWhere((name) => _sameSatellite(name, item.name));
    } else {
      names.add(item.name);
    }
    await _saveNames(names);
  }

  Future<void> _moveSubscribed(int index, int delta) async {
    final names = [..._preferences.satelliteNames];
    final target = index + delta;
    if (target < 0 || target >= names.length) return;
    final item = names.removeAt(index);
    names.insert(target, item);
    await _saveNames(names);
  }

  bool _sameSatellite(String a, String b) {
    final aa = a.toUpperCase();
    final bb = b.toUpperCase();
    return aa.contains(bb) || bb.contains(aa);
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('订阅卫星'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (_error != null)
                    _InlineWarning(message: _error.toString()),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: '搜索卫星名称或 NORAD',
                      border: const OutlineInputBorder(),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: '搜索',
                              onPressed: _search,
                              icon: const Icon(Icons.search),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TrackerPanel(
                    title: '已订阅',
                    icon: Icons.playlist_add_check,
                    child: _preferences.satelliteNames.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: Text('暂无订阅卫星')),
                          )
                        : Column(
                            children: List.generate(
                              _preferences.satelliteNames.length,
                              (index) => _SubscribedSatelliteTile(
                                name: _preferences.satelliteNames[index],
                                index: index,
                                total: _preferences.satelliteNames.length,
                                onMoveUp: () => _moveSubscribed(index, -1),
                                onMoveDown: () => _moveSubscribed(index, 1),
                                onRemove: () async {
                                  final names = [
                                    ..._preferences.satelliteNames,
                                  ]..removeAt(index);
                                  await _saveNames(names);
                                },
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _TrackerPanel(
                    title: '搜索结果',
                    icon: Icons.manage_search,
                    child: _results.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: Text('没有匹配的卫星')),
                          )
                        : Column(
                            children: [
                              ..._results.map(
                                (item) => _CatalogSatelliteTile(
                                  item: item,
                                  onChanged: () => _toggleSatellite(item),
                                ),
                              ),
                              if (_hasMore)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoadingMore
                                        ? null
                                        : () => _search(loadMore: true),
                                    icon: _isLoadingMore
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.expand_more),
                                    label: const Text('加载更多'),
                                  ),
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

class _SubscribedSatelliteTile extends StatelessWidget {
  final String name;
  final int index;
  final int total;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  const _SubscribedSatelliteTile({
    required this.name,
    required this.index,
    required this.total,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.satellite_alt),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: '上移',
            onPressed: index == 0 ? null : onMoveUp,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: '下移',
            onPressed: index == total - 1 ? null : onMoveDown,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          IconButton(
            tooltip: '取消订阅',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _CatalogSatelliteTile extends StatelessWidget {
  final SatelliteCatalogItem item;
  final VoidCallback onChanged;

  const _CatalogSatelliteTile({
    required this.item,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: item.subscribed,
      onChanged: (_) => onChanged(),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        item.noradCatId == null ? item.tleSource : 'NORAD ${item.noradCatId}',
      ),
      secondary: _SatelliteAvatar(imageUrl: item.imageUrl, size: 40),
    );
  }
}

class _SatelliteAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _SatelliteAvatar({
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: imageUrl == null || imageUrl!.isEmpty
            ? Icon(Icons.satellite_alt, color: scheme.primary)
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.satellite_alt, color: scheme.primary),
              ),
      ),
    );
  }
}

class SatelliteInfoPage extends StatefulWidget {
  const SatelliteInfoPage({super.key});

  @override
  State<SatelliteInfoPage> createState() => _SatelliteInfoPageState();
}

class _SatelliteInfoPageState extends State<SatelliteInfoPage> {
  final _preferencesService = DiscoveryPreferencesService();
  final _databaseService = LocalDatabaseService();
  final _satelliteService = SatelliteService();
  final _searchController = TextEditingController();

  DiscoveryPreferences _preferences = const DiscoveryPreferences();
  RadioProfile _radioProfile = RadioProfile.defaults;
  List<SatelliteSummary> _summaries = const [];
  List<SatelliteCatalogItem> _results = const [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  Object? _error;

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

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _preferencesService.getPreferences(),
        _databaseService.getRadioProfile(),
      ]);
      final preferences = results[0] as DiscoveryPreferences;
      final radioProfile = results[1] as RadioProfile;
      final summaries = await _satelliteService.getSubscribedSatellites(
        grid: radioProfile.grid,
        tleSourceUrls: preferences.tleSourceUrls,
        satelliteNames: preferences.satelliteNames,
      );
      final searchResults = await _satelliteService.searchSatellites(
        query: _searchController.text,
        tleSourceUrls: preferences.tleSourceUrls,
        subscribedNames: preferences.satelliteNames,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _radioProfile = radioProfile;
        _summaries = summaries;
        _results = searchResults;
        _page = 1;
        _hasMore = searchResults.length >= 50;
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

  Future<void> _search({bool loadMore = false}) async {
    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isSearching = true;
      }
      _error = null;
    });
    try {
      final page = loadMore ? _page + 1 : 1;
      final results = await _satelliteService.searchSatellites(
        query: _searchController.text,
        tleSourceUrls: _preferences.tleSourceUrls,
        subscribedNames: _preferences.satelliteNames,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _results = loadMore ? [..._results, ...results] : results;
        _page = page;
        _hasMore = results.length >= 50;
        _isSearching = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isSearching = false;
        _isLoadingMore = false;
      });
    }
  }

  void _openDetail(String satelliteName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SatelliteDetailPage(
          satelliteName: satelliteName,
          radioProfile: _radioProfile,
          tleSourceUrls: _preferences.tleSourceUrls,
          service: _satelliteService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('卫星信息'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (_error != null)
                    _InlineWarning(message: _error.toString()),
                  _TrackerPanel(
                    title: '订阅卫星',
                    icon: Icons.satellite_alt,
                    child: _summaries.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: Text('暂无订阅卫星')),
                          )
                        : Column(
                            children: _summaries
                                .map(
                                  (summary) => _SatelliteSummaryInfoTile(
                                    summary: summary,
                                    onTap: () => _openDetail(summary.name),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: '搜索更多卫星',
                      border: const OutlineInputBorder(),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: '搜索',
                              onPressed: _search,
                              icon: const Icon(Icons.search),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TrackerPanel(
                    title: 'TLE 目录',
                    icon: Icons.list_alt,
                    child: _results.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: Text('没有匹配的卫星')),
                          )
                        : Column(
                            children: [
                              ..._results.map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: _SatelliteAvatar(
                                    imageUrl: item.imageUrl,
                                    size: 40,
                                  ),
                                  title: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(item.noradCatId == null
                                      ? item.tleSource
                                      : 'NORAD ${item.noradCatId}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openDetail(item.name),
                                ),
                              ),
                              if (_hasMore)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoadingMore
                                        ? null
                                        : () => _search(loadMore: true),
                                    icon: _isLoadingMore
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.expand_more),
                                    label: const Text('加载更多'),
                                  ),
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

class _SatelliteSummaryInfoTile extends StatelessWidget {
  final SatelliteSummary summary;
  final VoidCallback onTap;

  const _SatelliteSummaryInfoTile({
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pass = summary.nextPass;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _SatelliteAvatar(
        imageUrl: summary.catalogItem?.imageUrl,
        size: 40,
      ),
      title: Text(summary.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        pass == null
            ? '未来 48 小时暂无过境'
            : 'AOS ${DateFormat('MM-dd HH:mm').format(pass.aos)} · ${pass.maxElevation.toStringAsFixed(0)}°',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _TrackerPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  const _TrackerPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xff3f8cff)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Column(
      children: [
        Text(label, style: TextStyle(color: colors.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: TextStyle(color: colors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff20d174).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xff20d174),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  final String message;

  const _InlineWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(message),
        ),
      ),
    );
  }
}

class _TrackerStateMessage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _TrackerStateMessage({
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
            Icon(Icons.satellite_alt,
                size: 46, color: Theme.of(context).colorScheme.primary),
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

class _SkyRadarPainter extends CustomPainter {
  final SatellitePass pass;
  final double? heading;
  final RadioThemeColors colors;

  _SkyRadarPainter({
    required this.pass,
    required this.heading,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 18;
    final gridPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = colors.muted.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final scale in [1.0, 0.66, 0.33]) {
      canvas.drawCircle(center, radius * scale, gridPaint);
    }
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), axisPaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), axisPaint);

    final pathPaint = Paint()
      ..color = const Color(0xff3f8cff)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    final path = Path();
    final samples = pass.lookSamples;
    for (var i = 0; i < samples.length; i++) {
      final point =
          _skyPoint(center, radius, samples[i].azimuth, samples[i].elevation);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, pathPaint);

    final target = pass.currentAzimuth == null || pass.currentElevation == null
        ? _skyPoint(center, radius, (pass.aosAzimuth + pass.losAzimuth) / 2,
            pass.maxElevation)
        : _skyPoint(
            center, radius, pass.currentAzimuth!, pass.currentElevation!);
    canvas.drawCircle(target, 7, Paint()..color = const Color(0xffffb547));

    if (heading != null) {
      final p = _skyPoint(center, radius, heading!, 0);
      canvas.drawLine(
        center,
        p,
        Paint()
          ..color = const Color(0xff20d174)
          ..strokeWidth = 2,
      );
    }

    _drawLabel(canvas, center + Offset(-4, -radius - 14), 'N');
    _drawLabel(canvas, center + Offset(radius + 8, -7), 'E');
    _drawLabel(canvas, center + Offset(-4, radius + 4), 'S');
    _drawLabel(canvas, center + Offset(-radius - 16, -7), 'W');
  }

  Offset _skyPoint(
      Offset center, double radius, double azimuth, double elevation) {
    final r = radius * (1 - elevation.clamp(0, 90) / 90);
    final angle = (azimuth - 90) * pi / 180;
    return Offset(center.dx + cos(angle) * r, center.dy + sin(angle) * r);
  }

  void _drawLabel(Canvas canvas, Offset offset, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: colors.muted, fontWeight: FontWeight.w900),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SkyRadarPainter oldDelegate) {
    return oldDelegate.pass != pass ||
        oldDelegate.heading != heading ||
        oldDelegate.colors != colors;
  }
}

double _bearingDelta(double heading, double target) {
  var delta = (target - heading + 540) % 360 - 180;
  return delta;
}

List<_DopplerPassPoint> _dopplerPoints(SatellitePass pass) {
  final fallback = pass.dopplerFactor ?? 1.0;
  final samples = pass.lookSamples
      .where((sample) => _isFiniteFactor(sample.dopplerFactor))
      .toList(growable: false);
  if (samples.isEmpty) {
    if (!_isFiniteFactor(fallback)) return const [];
    return [
      _DopplerPassPoint(label: 'AOS', factor: fallback),
      _DopplerPassPoint(label: 'TCA', factor: fallback),
      _DopplerPassPoint(label: 'LOS', factor: fallback),
    ];
  }

  final tca = samples.reduce((a, b) {
    final aDelta = a.time.difference(pass.maxElevationAt).inSeconds.abs();
    final bDelta = b.time.difference(pass.maxElevationAt).inSeconds.abs();
    return aDelta <= bDelta ? a : b;
  });

  return [
    _DopplerPassPoint(label: 'AOS', factor: samples.first.dopplerFactor!),
    _DopplerPassPoint(label: 'TCA', factor: tca.dopplerFactor!),
    _DopplerPassPoint(label: 'LOS', factor: samples.last.dopplerFactor!),
  ];
}

_DopplerPassPoint? _currentDopplerPoint(SatellitePass pass, DateTime now) {
  if (now.isBefore(pass.aos) || now.isAfter(pass.los)) return null;
  final factor = _interpolatedDopplerFactor(pass, now);
  if (factor == null) return null;
  return _DopplerPassPoint(
    label: '实时',
    factor: factor,
    isCurrent: true,
  );
}

double? _interpolatedDopplerFactor(SatellitePass pass, DateTime target) {
  final samples = pass.lookSamples
      .where((sample) => _isFiniteFactor(sample.dopplerFactor))
      .toList(growable: false);
  if (samples.isEmpty) {
    return _isFiniteFactor(pass.dopplerFactor) ? pass.dopplerFactor : null;
  }
  if (!target.isAfter(samples.first.time)) return samples.first.dopplerFactor;
  if (!target.isBefore(samples.last.time)) return samples.last.dopplerFactor;

  for (var index = 1; index < samples.length; index++) {
    final previous = samples[index - 1];
    final next = samples[index];
    if (target.isBefore(previous.time) || target.isAfter(next.time)) {
      continue;
    }
    final span = next.time.difference(previous.time).inMilliseconds;
    if (span <= 0) return next.dopplerFactor;
    final elapsed = target.difference(previous.time).inMilliseconds;
    final ratio = (elapsed / span).clamp(0.0, 1.0);
    return previous.dopplerFactor! +
        (next.dopplerFactor! - previous.dopplerFactor!) * ratio;
  }
  return pass.dopplerFactor;
}

String _dopplerOffset(int frequencyHz, double factor) {
  if (!factor.isFinite) return '--';
  final khz = frequencyHz * (factor - 1) / 1000;
  final sign = khz >= 0 ? '+' : '';
  return '$sign${khz.toStringAsFixed(1)} kHz';
}

String _formatDopplerBaseFrequency(int frequencyHz) {
  return '${(frequencyHz / 1000000).toStringAsFixed(3)} MHz';
}

bool _isFiniteFactor(double? value) {
  return value != null && value.isFinite;
}
