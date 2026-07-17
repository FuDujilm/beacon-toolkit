import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/timezone_tool.dart';
import '../../services/timezone_tool_service.dart';
import 'radio_theme.dart';

enum _MapBaseLayer {
  light,
  dark,
}

enum _SelectionTarget {
  pointA,
  pointB,
}

class TimezoneCalculatorPage extends StatefulWidget {
  const TimezoneCalculatorPage({super.key});

  @override
  State<TimezoneCalculatorPage> createState() => _TimezoneCalculatorPageState();
}

class _TimezoneCalculatorPageState extends State<TimezoneCalculatorPage> {
  final _timezoneService = const TimezoneToolService();

  final _latAController = TextEditingController(text: '39.904200');
  final _lonAController = TextEditingController(text: '116.407400');
  final _latBController = TextEditingController(text: '51.507400');
  final _lonBController = TextEditingController(text: '-0.127800');

  String? _message;
  bool _locating = false;
  _MapBaseLayer _baseLayer = _MapBaseLayer.light;
  _SelectionTarget _selectionTarget = _SelectionTarget.pointA;
  DateTime _utcNow = DateTime.now().toUtc();
  TimezonePoint? _pointA;
  TimezonePoint? _pointB;

  @override
  void initState() {
    super.initState();
    _rebuildPoints(moveMap: false);
  }

  @override
  void dispose() {
    _latAController.dispose();
    _lonAController.dispose();
    _latBController.dispose();
    _lonBController.dispose();
    super.dispose();
  }

  void _rebuildPoints({bool moveMap = true}) {
    final latitudeA = _parseCoordinate(
      _latAController.text,
      min: -90,
      max: 90,
      label: '地点 A 纬度',
    );
    final longitudeA = _parseCoordinate(
      _lonAController.text,
      min: -180,
      max: 180,
      label: '地点 A 经度',
    );
    final latitudeB = _parseCoordinate(
      _latBController.text,
      min: -90,
      max: 90,
      label: '地点 B 纬度',
    );
    final longitudeB = _parseCoordinate(
      _lonBController.text,
      min: -180,
      max: 180,
      label: '地点 B 经度',
    );
    final pointA = _timezoneService.resolvePoint(
      latitude: latitudeA,
      longitude: longitudeA,
      label: '地点 A',
    );
    final pointB = _timezoneService.resolvePoint(
      latitude: latitudeB,
      longitude: longitudeB,
      label: '地点 B',
    );
    setState(() {
      _pointA = pointA;
      _pointB = pointB;
      _utcNow = DateTime.now().toUtc();
      _message = null;
    });
  }

  void _setSelectionTarget(_SelectionTarget target) {
    if (_selectionTarget == target) return;
    setState(() => _selectionTarget = target);
  }

  void _swapPoints() {
    final latA = _latAController.text;
    final lonA = _lonAController.text;
    _latAController.text = _latBController.text;
    _lonAController.text = _lonBController.text;
    _latBController.text = latA;
    _lonBController.text = lonA;
    _rebuildPoints();
  }

  void _onMapTap(_GeoPoint point) {
    if (_selectionTarget == _SelectionTarget.pointA) {
      _latAController.text = _formatCoord(point.latitude);
      _lonAController.text = _formatCoord(point.longitude);
    } else {
      _latBController.text = _formatCoord(point.latitude);
      _lonBController.text = _formatCoord(point.longitude);
    }
    _rebuildPoints(moveMap: false);
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _message = '定位服务未开启');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _message = '定位权限未授权');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (_selectionTarget == _SelectionTarget.pointA) {
        _latAController.text = _formatCoord(position.latitude);
        _lonAController.text = _formatCoord(position.longitude);
      } else {
        _latBController.text = _formatCoord(position.latitude);
        _lonBController.text = _formatCoord(position.longitude);
      }
      _rebuildPoints();
    } catch (e) {
      setState(() => _message = '定位失败: $e');
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _setBaseLayer(_MapBaseLayer layer) {
    setState(() {
      _baseLayer = layer;
      _message = null;
    });
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label 已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    final pointA = _pointA;
    final pointB = _pointB;
    final comparison = pointA != null && pointB != null
        ? _timezoneService.compare(
            pointA: pointA,
            pointB: pointB,
            utcTime: _utcNow,
          )
        : null;

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        title: const Text('时区计算'),
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
      ),
      body: StreamBuilder<DateTime>(
        stream: Stream<DateTime>.periodic(
          const Duration(seconds: 1),
          (_) => DateTime.now().toUtc(),
        ),
        initialData: _utcNow,
        builder: (context, snapshot) {
          _utcNow = snapshot.data ?? DateTime.now().toUtc();
          final liveComparison = pointA != null && pointB != null
              ? _timezoneService.compare(
                  pointA: pointA,
                  pointB: pointB,
                  utcTime: _utcNow,
                )
              : null;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final controls = _TimezoneControlsPanel(
                selectionTarget: _selectionTarget,
                latAController: _latAController,
                lonAController: _lonAController,
                latBController: _latBController,
                lonBController: _lonBController,
                pointA: pointA,
                pointB: pointB,
                utcNow: _utcNow,
                comparison: liveComparison ?? comparison,
                message: _message,
                locating: _locating,
                onTargetChanged: _setSelectionTarget,
                onUseLocation: _useCurrentLocation,
                onApplyCoordinates: () {
                  try {
                    _rebuildPoints();
                  } on FormatException catch (e) {
                    setState(() => _message = e.message);
                  }
                },
                onSwap: _swapPoints,
                onCopy: _copy,
              );
              final map = _TimezoneWorldMap(
                pointA: pointA,
                pointB: pointB,
                baseLayer: _baseLayer,
                selectionTarget: _selectionTarget,
                timezoneService: _timezoneService,
                utcNow: _utcNow,
                onTap: _onMapTap,
                onBaseLayerChanged: _setBaseLayer,
              );

              if (wide) {
                return Row(
                  children: [
                    SizedBox(
                      width: 400,
                      child: SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: controls,
                        ),
                      ),
                    ),
                    Expanded(child: map),
                  ],
                );
              }

              return Stack(
                children: [
                  Positioned.fill(child: map),
                  DraggableScrollableSheet(
                    initialChildSize: 0.42,
                    minChildSize: 0.20,
                    maxChildSize: 0.82,
                    builder: (context, scrollController) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 18,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          children: [
                            Center(
                              child: Container(
                                width: 38,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            controls,
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  double _parseCoordinate(
    String value, {
    required double min,
    required double max,
    required String label,
  }) {
    final trimmed = value.trim();
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < min || parsed > max) {
      throw FormatException('$label 必须在 $min 到 $max 之间');
    }
    return parsed;
  }

  String _formatCoord(double value) => value.toStringAsFixed(6);
}

class _TimezoneControlsPanel extends StatelessWidget {
  final _SelectionTarget selectionTarget;
  final TextEditingController latAController;
  final TextEditingController lonAController;
  final TextEditingController latBController;
  final TextEditingController lonBController;
  final TimezonePoint? pointA;
  final TimezonePoint? pointB;
  final DateTime utcNow;
  final TimezoneComparisonResult? comparison;
  final String? message;
  final bool locating;
  final ValueChanged<_SelectionTarget> onTargetChanged;
  final VoidCallback onUseLocation;
  final VoidCallback onApplyCoordinates;
  final VoidCallback onSwap;
  final Future<void> Function(String value, String label) onCopy;

  const _TimezoneControlsPanel({
    required this.selectionTarget,
    required this.latAController,
    required this.lonAController,
    required this.latBController,
    required this.lonBController,
    required this.pointA,
    required this.pointB,
    required this.utcNow,
    required this.comparison,
    required this.message,
    required this.locating,
    required this.onTargetChanged,
    required this.onUseLocation,
    required this.onApplyCoordinates,
    required this.onSwap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '双地点时区换算',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '按近似 UTC 偏移计算，地图点击可设置地点，并叠加白天 / 黑夜区域。',
                style: TextStyle(color: colors.muted, height: 1.45),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TargetChip(
                    label: '设置地点 A',
                    selected: selectionTarget == _SelectionTarget.pointA,
                    onTap: () => onTargetChanged(_SelectionTarget.pointA),
                  ),
                  _TargetChip(
                    label: '设置地点 B',
                    selected: selectionTarget == _SelectionTarget.pointB,
                    onTap: () => onTargetChanged(_SelectionTarget.pointB),
                  ),
                  OutlinedButton.icon(
                    onPressed: locating ? null : onUseLocation,
                    icon: locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(locating ? '定位中...' : '使用当前定位'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onSwap,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('互换 A/B'),
                  ),
                ],
              ),
              if (message?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _LocationEditorCard(
          title: '地点 A',
          color: const Color(0xff347cff),
          latitudeController: latAController,
          longitudeController: lonAController,
          point: pointA,
          utcNow: utcNow,
          onApplyCoordinates: onApplyCoordinates,
          onCopy: onCopy,
        ),
        const SizedBox(height: 14),
        _LocationEditorCard(
          title: '地点 B',
          color: const Color(0xffef9743),
          latitudeController: latBController,
          longitudeController: lonBController,
          point: pointB,
          utcNow: utcNow,
          onApplyCoordinates: onApplyCoordinates,
          onCopy: onCopy,
        ),
        const SizedBox(height: 14),
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '换算结果',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              if (comparison == null)
                Text('请先设置两个有效地点。', style: TextStyle(color: colors.muted))
              else ...[
                _ResultRow(
                  label: 'A 本地时间',
                  value: _formatDateTime(comparison!.timeA),
                ),
                _ResultRow(
                  label: 'B 本地时间',
                  value: _formatDateTime(comparison!.timeB),
                ),
                _ResultRow(
                  label: 'B 相对 A',
                  value: _differenceLabel(comparison!.differenceMinutes),
                ),
                _ResultRow(
                  label: '日期进位',
                  value: _dayShiftLabel(comparison!.dayShift),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '仅供参考，请遵守当地法规和主管部门要求。',
          style: TextStyle(color: colors.muted, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _differenceLabel(int minutes) {
    if (minutes == 0) return '相同';
    final sign = minutes > 0 ? '快' : '慢';
    final absolute = minutes.abs();
    final hours = absolute ~/ 60;
    final remainMinutes = absolute % 60;
    if (remainMinutes == 0) {
      return '$sign $hours 小时';
    }
    return '$sign $hours 小时 $remainMinutes 分';
  }

  String _dayShiftLabel(int dayShift) {
    if (dayShift == 0) return '同一天';
    if (dayShift > 0) return 'B 晚 $dayShift 天';
    return 'B 早 ${dayShift.abs()} 天';
  }
}

class _LocationEditorCard extends StatelessWidget {
  final String title;
  final Color color;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TimezonePoint? point;
  final DateTime utcNow;
  final VoidCallback onApplyCoordinates;
  final Future<void> Function(String value, String label) onCopy;

  const _LocationEditorCard({
    required this.title,
    required this.color,
    required this.latitudeController,
    required this.longitudeController,
    required this.point,
    required this.utcNow,
    required this.onApplyCoordinates,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    final pointValue = point;
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              if (pointValue != null)
                Text(
                  pointValue.utcOffsetLabel,
                  style: TextStyle(
                    color: colors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '纬度',
                    hintText: '39.904200',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '经度',
                    hintText: '116.407400',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onApplyCoordinates,
                  icon: const Icon(Icons.calculate),
                  label: const Text('应用坐标'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pointValue == null
                      ? null
                      : () => onCopy(
                            '${pointValue.latitude.toStringAsFixed(6)}, ${pointValue.longitude.toStringAsFixed(6)}',
                            '$title 坐标',
                          ),
                  icon: const Icon(Icons.copy),
                  label: const Text('复制坐标'),
                ),
              ),
            ],
          ),
          if (pointValue != null) ...[
            const SizedBox(height: 12),
            _ResultRow(
              label: '本地时间',
              value:
                  '${pointValue.localTimeAt(utcNow).hour.toString().padLeft(2, '0')}:${pointValue.localTimeAt(utcNow).minute.toString().padLeft(2, '0')}:${pointValue.localTimeAt(utcNow).second.toString().padLeft(2, '0')}',
            ),
            _ResultRow(label: 'UTC 偏移', value: pointValue.utcOffsetLabel),
            _ResultRow(
              label: '昼夜状态',
              value: const TimezoneToolService().isDaylight(
                latitude: pointValue.latitude,
                longitude: pointValue.longitude,
                utcTime: utcNow,
              )
                  ? '近似白天'
                  : '近似夜间',
            ),
          ],
        ],
      ),
    );
  }
}

class _TimezoneWorldMap extends StatelessWidget {
  final TimezonePoint? pointA;
  final TimezonePoint? pointB;
  final _MapBaseLayer baseLayer;
  final _SelectionTarget selectionTarget;
  final TimezoneToolService timezoneService;
  final DateTime utcNow;
  final ValueChanged<_GeoPoint> onTap;
  final ValueChanged<_MapBaseLayer> onBaseLayerChanged;

  const _TimezoneWorldMap({
    required this.pointA,
    required this.pointB,
    required this.baseLayer,
    required this.selectionTarget,
    required this.timezoneService,
    required this.utcNow,
    required this.onTap,
    required this.onBaseLayerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: baseLayer == _MapBaseLayer.light
                ? const Color(0xffd5edf8)
                : const Color(0xff15233a),
          ),
          child: _EquirectangularWorldMap(
            pointA: pointA,
            pointB: pointB,
            baseLayer: baseLayer,
            timezoneService: timezoneService,
            utcNow: utcNow,
            onTap: onTap,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _LayerMenu(
            value: baseLayer,
            onChanged: onBaseLayerChanged,
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                selectionTarget == _SelectionTarget.pointA
                    ? '地图点击将设置地点 A'
                    : '地图点击将设置地点 B',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GeoPoint {
  final double latitude;
  final double longitude;

  const _GeoPoint({
    required this.latitude,
    required this.longitude,
  });
}

class _ProjectedWorldPoint {
  final double x;
  final double y;

  const _ProjectedWorldPoint({
    required this.x,
    required this.y,
  });
}

class _WorldMapLayout {
  final Size viewportSize;
  final Size worldSize;
  final Offset pan;

  const _WorldMapLayout({
    required this.viewportSize,
    required this.worldSize,
    required this.pan,
  });

  double get worldWidth => worldSize.width;

  double get worldHeight => worldSize.height;
}

class _EquirectangularWorldMap extends StatefulWidget {
  final TimezonePoint? pointA;
  final TimezonePoint? pointB;
  final _MapBaseLayer baseLayer;
  final TimezoneToolService timezoneService;
  final DateTime utcNow;
  final ValueChanged<_GeoPoint> onTap;

  const _EquirectangularWorldMap({
    required this.pointA,
    required this.pointB,
    required this.baseLayer,
    required this.timezoneService,
    required this.utcNow,
    required this.onTap,
  });

  @override
  State<_EquirectangularWorldMap> createState() =>
      _EquirectangularWorldMapState();
}

class _EquirectangularWorldMapState extends State<_EquirectangularWorldMap> {
  static const double _zoom = 1;
  Offset _pan = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final layout = _layoutFor(viewportSize, _pan, _zoom);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final nextPan = _normalizePan(
              _pan + details.delta,
              viewportSize,
              _zoom,
            );
            setState(() {
              _pan = nextPan;
            });
          },
          onTapUp: (details) {
            final geo = _projectOffsetToGeo(details.localPosition, layout);
            widget.onTap(geo);
          },
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final dx in _imageOffsets(layout))
                  Positioned(
                    left: dx,
                    top: layout.pan.dy,
                    width: layout.worldWidth,
                    height: layout.worldHeight,
                    child: _WorldMapImage(baseLayer: widget.baseLayer),
                  ),
                CustomPaint(
                  painter: _TimezoneOverlayPainter(
                    layout: layout,
                    timezoneService: widget.timezoneService,
                    utcNow: widget.utcNow,
                    baseLayer: widget.baseLayer,
                  ),
                ),
                if (widget.pointA != null)
                  _markerForPoint(
                    context,
                    widget.pointA!,
                    'A',
                    const Color(0xff347cff),
                    layout,
                  ),
                if (widget.pointB != null)
                  _markerForPoint(
                    context,
                    widget.pointB!,
                    'B',
                    const Color(0xffef9743),
                    layout,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  _WorldMapLayout _layoutFor(Size viewportSize, Offset pan, double zoom) {
    final worldSize = _worldSizeFor(viewportSize, zoom);
    final centeredPan = _centeredPanFor(viewportSize, worldSize);
    final normalizedPan = _normalizePan(pan, viewportSize, zoom);
    return _WorldMapLayout(
      viewportSize: viewportSize,
      worldSize: worldSize,
      pan: centeredPan + normalizedPan,
    );
  }

  Widget _markerForPoint(
    BuildContext context,
    TimezonePoint point,
    String label,
    Color color,
    _WorldMapLayout layout,
  ) {
    const markerWidth = 118.0;
    const markerHeight = 64.0;
    const dotSize = 18.0;
    const horizontalPadding = 6.0;
    final projected = _projectGeoToOffset(
      _GeoPoint(latitude: point.latitude, longitude: point.longitude),
      layout,
    );
    final scheme = Theme.of(context).colorScheme;
    final maxLeft =
        (layout.viewportSize.width - markerWidth - horizontalPadding)
            .clamp(horizontalPadding, double.infinity);
    final left = (projected.x - markerWidth / 2).clamp(
      horizontalPadding,
      maxLeft,
    );
    final top = (projected.y - 52).clamp(
      0.0,
      layout.viewportSize.height - markerHeight,
    );
    final dotLeft = (projected.x - left - dotSize / 2).clamp(
      0.0,
      markerWidth - dotSize,
    );
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: SizedBox(
          width: markerWidth,
          height: markerHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  '$label ${point.utcOffsetLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: dotLeft),
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<double> _imageOffsets(_WorldMapLayout layout) {
    final wrapped = _wrapHorizontal(layout.pan.dx, layout.worldWidth);
    return [
      wrapped - layout.worldWidth,
      wrapped,
      wrapped + layout.worldWidth,
    ];
  }

  Offset _normalizePan(Offset totalPan, Size viewportSize, double zoom) {
    final worldSize = _worldSizeFor(viewportSize, zoom);
    final centeredPan = _centeredPanFor(viewportSize, worldSize);
    final screenPan = centeredPan + totalPan;
    final minY = viewportSize.height - worldSize.height;
    const maxY = 0.0;
    final clampedScreenY = screenPan.dy.clamp(minY, maxY);
    return Offset(totalPan.dx, clampedScreenY - centeredPan.dy);
  }

  Size _worldSizeFor(Size viewportSize, double zoom) {
    final baseHeight = viewportSize.width / 2;
    final coverScale = baseHeight < viewportSize.height
        ? viewportSize.height / baseHeight
        : 1.0;
    return Size(
      viewportSize.width * coverScale * zoom,
      baseHeight * coverScale * zoom,
    );
  }

  Offset _centeredPanFor(Size viewportSize, Size worldSize) {
    return Offset(
      (viewportSize.width - worldSize.width) / 2,
      (viewportSize.height - worldSize.height) / 2,
    );
  }

  double _wrapHorizontal(double dx, double worldWidth) {
    if (worldWidth <= 0) return 0;
    return ((dx % worldWidth) + worldWidth) % worldWidth;
  }

  static _ProjectedWorldPoint _projectGeoToOffset(
    _GeoPoint point,
    _WorldMapLayout layout,
  ) {
    final normalizedX = (point.longitude + 180) / 360;
    final rawX = normalizedX * layout.worldWidth + layout.pan.dx;
    final y =
        ((90 - point.latitude) / 180) * layout.worldHeight + layout.pan.dy;
    final wrappedX =
        ((rawX % layout.worldWidth) + layout.worldWidth) % layout.worldWidth;
    final displayX = wrappedX > layout.viewportSize.width
        ? wrappedX - layout.worldWidth
        : wrappedX;
    return _ProjectedWorldPoint(x: displayX, y: y);
  }

  static _GeoPoint _projectOffsetToGeo(
    Offset offset,
    _WorldMapLayout layout,
  ) {
    final worldX = (((offset.dx - layout.pan.dx) % layout.worldWidth) +
            layout.worldWidth) %
        layout.worldWidth;
    final worldY = (offset.dy - layout.pan.dy).clamp(0.0, layout.worldHeight);
    final longitude = worldX / layout.worldWidth * 360 - 180;
    final latitude = 90 - worldY / layout.worldHeight * 180;
    return _GeoPoint(latitude: latitude, longitude: longitude);
  }
}

class _WorldMapImage extends StatelessWidget {
  final _MapBaseLayer baseLayer;

  const _WorldMapImage({required this.baseLayer});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: baseLayer == _MapBaseLayer.light
              ? const Color(0xffcfe8f6)
              : const Color(0xff102033),
        ),
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            baseLayer == _MapBaseLayer.light
                ? const Color(0xfff6f4ee)
                : const Color(0xff121820),
            BlendMode.srcIn,
          ),
          child: Image.asset(
            'assets/images/world_map_equirectangular.png',
            fit: BoxFit.fill,
          ),
        ),
      ],
    );
  }
}

class _TimezoneOverlayPainter extends CustomPainter {
  final _WorldMapLayout layout;
  final TimezoneToolService timezoneService;
  final DateTime utcNow;
  final _MapBaseLayer baseLayer;

  const _TimezoneOverlayPainter({
    required this.layout,
    required this.timezoneService,
    required this.utcNow,
    required this.baseLayer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintTimezoneLines(canvas, size);
    _paintNightMask(canvas, size);
    _paintTerminator(canvas);
  }

  void _paintTimezoneLines(Canvas canvas, Size size) {
    final offsets = <int>[
      -720,
      -660,
      -600,
      -570,
      -540,
      -480,
      -420,
      -360,
      -300,
      -240,
      -210,
      -180,
      -120,
      -60,
      0,
      60,
      120,
      180,
      240,
      300,
      330,
      345,
      360,
      420,
      480,
      525,
      540,
      570,
      600,
      630,
      660,
      720,
      765,
      780,
      840,
    ];
    for (final offset in offsets) {
      final longitude = timezoneService.zoneCenterLongitude(offset);
      final normalizedX = (longitude + 180) / 360;
      final x = normalizedX * layout.worldWidth + layout.pan.dx;
      final hue = ((offset + 720) / 1560).clamp(0.0, 1.0);
      final color = HSVColor.fromAHSV(1, hue * 360, 0.45, 0.95).toColor();
      final paint = Paint()
        ..color = color.withValues(
          alpha: baseLayer == _MapBaseLayer.light
              ? (offset % 60 == 0 ? 0.12 : 0.06)
              : (offset % 60 == 0 ? 0.18 : 0.10),
        )
        ..strokeWidth = offset % 60 == 0 ? 1.0 : 0.6;
      for (final dx in [x - layout.worldWidth, x, x + layout.worldWidth]) {
        canvas.drawLine(
          Offset(dx, 0),
          Offset(dx, layout.viewportSize.height),
          paint,
        );
      }
    }
  }

  void _paintNightMask(Canvas canvas, Size size) {
    const xStep = 3.0;
    const gradientBand = 22.0;
    final solidPaint = Paint()
      ..color = (baseLayer == _MapBaseLayer.light
              ? const Color(0xFF163257)
              : const Color(0xFF09111F))
          .withValues(alpha: baseLayer == _MapBaseLayer.light ? 0.22 : 0.34);

    for (double x = 0; x < layout.viewportSize.width; x += xStep) {
      final stripWidth = (x + xStep <= layout.viewportSize.width)
          ? xStep
          : layout.viewportSize.width - x;
      if (stripWidth <= 0) continue;

      final sampleX = x + stripWidth / 2;
      final topPoint = _screenToGeo(sampleX, 0);
      final bottomPoint = _screenToGeo(sampleX, layout.viewportSize.height);
      final topNight = !timezoneService.isDaylight(
        latitude: topPoint.latitude,
        longitude: topPoint.longitude,
        utcTime: utcNow,
      );
      final bottomNight = !timezoneService.isDaylight(
        latitude: bottomPoint.latitude,
        longitude: bottomPoint.longitude,
        utcTime: utcNow,
      );

      if (topNight == bottomNight) {
        if (topNight) {
          canvas.drawRect(
            Rect.fromLTWH(x, 0, stripWidth, layout.viewportSize.height),
            solidPaint,
          );
        }
        continue;
      }

      double low = 0;
      double high = layout.viewportSize.height;
      for (var i = 0; i < 14; i++) {
        final mid = (low + high) / 2;
        final sample = _screenToGeo(sampleX, mid);
        final night = !timezoneService.isDaylight(
          latitude: sample.latitude,
          longitude: sample.longitude,
          utcTime: utcNow,
        );
        if (night == topNight) {
          low = mid;
        } else {
          high = mid;
        }
      }

      final boundaryY = (low + high) / 2;
      final bandStart = (boundaryY - gradientBand).clamp(
        0.0,
        layout.viewportSize.height,
      );
      final bandEnd = (boundaryY + gradientBand).clamp(
        0.0,
        layout.viewportSize.height,
      );

      if (topNight) {
        if (bandStart > 0) {
          canvas.drawRect(
            Rect.fromLTWH(x, 0, stripWidth, bandStart),
            solidPaint,
          );
        }
      } else if (bandEnd < layout.viewportSize.height) {
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            bandEnd,
            stripWidth,
            layout.viewportSize.height - bandEnd,
          ),
          solidPaint,
        );
      }

      if (bandEnd > bandStart) {
        final gradientRect =
            Rect.fromLTWH(x, bandStart, stripWidth, bandEnd - bandStart);
        final gradientPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: topNight
                ? [
                    const Color(0xFF163257).withValues(alpha: 0.18),
                    const Color(0xFF163257).withValues(alpha: 0.08),
                    const Color(0xFF163257).withValues(alpha: 0.00),
                  ]
                : [
                    const Color(0xFF163257).withValues(alpha: 0.00),
                    const Color(0xFF163257).withValues(alpha: 0.08),
                    const Color(0xFF163257).withValues(alpha: 0.18),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(gradientRect);
        canvas.drawRect(gradientRect, gradientPaint);
      }
    }
  }

  void _paintTerminator(Canvas canvas) {
    final points = timezoneService.buildTerminator(
      utcTime: utcNow,
      longitudeStep: 2,
    );
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.82);

    for (final shift in [-layout.worldWidth, 0.0, layout.worldWidth]) {
      final path = Path();
      var started = false;
      for (final point in points) {
        final projected = _projectGeoToCanvas(
          point.latitude,
          point.longitude,
          shift,
        );
        if (!started) {
          path.moveTo(projected.dx, projected.dy);
          started = true;
        } else {
          path.lineTo(projected.dx, projected.dy);
        }
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
    }
  }

  _GeoPoint _screenToGeo(double x, double y) {
    final worldX =
        (((x - layout.pan.dx) % layout.worldWidth) + layout.worldWidth) %
            layout.worldWidth;
    final worldY = (y - layout.pan.dy).clamp(0.0, layout.worldHeight);
    final longitude = worldX / layout.worldWidth * 360 - 180;
    final latitude = 90 - worldY / layout.worldHeight * 180;
    return _GeoPoint(latitude: latitude, longitude: longitude);
  }

  Offset _projectGeoToCanvas(double latitude, double longitude, double shift) {
    final normalizedX = (longitude + 180) / 360;
    final x = normalizedX * layout.worldWidth + layout.pan.dx + shift;
    final y = ((90 - latitude) / 180) * layout.worldHeight + layout.pan.dy;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _TimezoneOverlayPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.utcNow != utcNow ||
        oldDelegate.baseLayer != baseLayer;
  }
}

class _PanelCard extends StatelessWidget {
  final Widget child;

  const _PanelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color:
          selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerMenu extends StatelessWidget {
  final _MapBaseLayer value;
  final ValueChanged<_MapBaseLayer> onChanged;

  const _LayerMenu({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<_MapBaseLayer>(
        initialValue: value,
        tooltip: '底图图层',
        onSelected: onChanged,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _MapBaseLayer.light,
            child: Text('浅色世界图'),
          ),
          const PopupMenuItem(
            value: _MapBaseLayer.dark,
            child: Text('深色世界图'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers, color: scheme.onSurface),
              const SizedBox(width: 8),
              Text(
                '底图',
                style: TextStyle(
                  color: scheme.onSurface,
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
