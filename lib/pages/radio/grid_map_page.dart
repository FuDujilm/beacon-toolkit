import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as osm;
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_endpoint_settings_service.dart';
import '../../services/grid_locator_service.dart';
import 'radio_theme.dart';

enum _MapBaseLayer {
  osm,
  tiandituVector,
  tiandituImage,
}

class GridMapPage extends StatefulWidget {
  const GridMapPage({super.key});

  @override
  State<GridMapPage> createState() => _GridMapPageState();
}

class _GridMapPageState extends State<GridMapPage> {
  static const _defaultPoint = GridPoint(latitude: 39.9, longitude: 116.4);

  final _mapController = MapController();
  final _gridController = TextEditingController(text: 'OM89');
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _gridService = const GridLocatorService();
  final _settingsService = const AppEndpointSettingsService();

  int _precision = 6;
  String _tiandituToken = '';
  String? _message;
  bool _locating = false;
  _MapBaseLayer _baseLayer = _MapBaseLayer.osm;
  GridCell _cell = const GridLocatorService().decodeMaidenhead('OM89');
  GridPoint _selectedPoint = _defaultPoint;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setPoint(_defaultPoint, moveMap: false);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _gridController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final token = await _settingsService.getTiandituToken();
    if (!mounted) return;
    setState(() => _tiandituToken = token);
  }

  void _searchGrid() {
    try {
      final cell = _gridService.decodeMaidenhead(_gridController.text);
      setState(() {
        _cell = cell;
        _selectedPoint = cell.center;
        _precision = cell.precision;
        _message = null;
        _latController.text = _formatCoord(cell.center.latitude);
        _lonController.text = _formatCoord(cell.center.longitude);
      });
      _moveToCell(cell);
    } on FormatException catch (e) {
      setState(() => _message = e.message);
    }
  }

  void _searchCoordinates() {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat == null || lon == null) {
      setState(() => _message = '请输入有效经纬度');
      return;
    }
    try {
      _setPoint(GridPoint(latitude: lat, longitude: lon));
    } on FormatException catch (e) {
      setState(() => _message = e.message);
    }
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
      _setPoint(
        GridPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (e) {
      setState(() => _message = '定位失败: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _setPoint(GridPoint point, {bool moveMap = true}) {
    final locator = _gridService.encodeMaidenhead(
      latitude: point.latitude,
      longitude: point.longitude,
      precision: _precision,
    );
    final cell = _gridService.decodeMaidenhead(locator);
    setState(() {
      _selectedPoint = point;
      _cell = cell;
      _gridController.text = locator;
      _latController.text = _formatCoord(point.latitude);
      _lonController.text = _formatCoord(point.longitude);
      _message = null;
    });
    if (moveMap) {
      _mapController.move(
        osm.LatLng(point.latitude, point.longitude),
        _zoomForPrecision(_precision),
      );
    }
  }

  void _setPrecision(int precision) {
    if (_precision == precision) return;
    setState(() => _precision = precision);
    _setPoint(_selectedPoint);
  }

  void _setBaseLayer(_MapBaseLayer layer) {
    if (layer != _MapBaseLayer.osm && _tiandituToken.isEmpty) {
      setState(() => _message = '请在开发者设置中配置天地图 Token');
      return;
    }
    setState(() {
      _baseLayer = layer;
      _message = null;
    });
  }

  void _moveToCell(GridCell cell) {
    _mapController.move(
      osm.LatLng(cell.center.latitude, cell.center.longitude),
      _zoomForPrecision(cell.precision),
    );
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
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        title: const Text('GRID 地图定位'),
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          final controls = _ControlsPanel(
            gridController: _gridController,
            latController: _latController,
            lonController: _lonController,
            precision: _precision,
            selectedPoint: _selectedPoint,
            cell: _cell,
            message: _message,
            locating: _locating,
            onSearchGrid: _searchGrid,
            onSearchCoordinates: _searchCoordinates,
            onUseLocation: _useCurrentLocation,
            onPrecisionChanged: _setPrecision,
            onCopy: _copy,
          );
          final map = _GridMap(
            controller: _mapController,
            cell: _cell,
            selectedPoint: _selectedPoint,
            baseLayer: _baseLayer,
            tiandituToken: _tiandituToken,
            onTap: (point) => _setPoint(
              GridPoint(latitude: point.latitude, longitude: point.longitude),
            ),
            onBaseLayerChanged: _setBaseLayer,
          );

          if (wide) {
            return Row(
              children: [
                SizedBox(
                  width: 380,
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
                maxChildSize: 0.78,
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
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
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
      ),
    );
  }

  double _zoomForPrecision(int precision) {
    switch (precision) {
      case 4:
        return 7;
      case 6:
        return 10;
      case 8:
        return 13;
      case 10:
        return 15;
      default:
        return 10;
    }
  }

  String _formatCoord(double value) => value.toStringAsFixed(6);
}

class _GridMap extends StatefulWidget {
  final MapController controller;
  final GridCell cell;
  final GridPoint selectedPoint;
  final _MapBaseLayer baseLayer;
  final String tiandituToken;
  final ValueChanged<osm.LatLng> onTap;
  final ValueChanged<_MapBaseLayer> onBaseLayerChanged;

  const _GridMap({
    required this.controller,
    required this.cell,
    required this.selectedPoint,
    required this.baseLayer,
    required this.tiandituToken,
    required this.onTap,
    required this.onBaseLayerChanged,
  });

  @override
  State<_GridMap> createState() => _GridMapState();
}

class _GridMapState extends State<_GridMap> {
  osm.LatLng _mapCenter = const osm.LatLng(39.9, 116.4);
  double _mapZoom = 7;
  LatLngBounds? _visibleBounds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: osm.LatLng(
              widget.cell.center.latitude,
              widget.cell.center.longitude,
            ),
            initialZoom: 7,
            minZoom: 2,
            maxZoom: 18,
            onMapReady: () {
              final camera = widget.controller.camera;
              setState(() {
                _mapCenter = camera.center;
                _mapZoom = camera.zoom;
                _visibleBounds = camera.visibleBounds;
              });
            },
            onPositionChanged: (camera, _) {
              setState(() {
                _mapCenter = camera.center;
                _mapZoom = camera.zoom;
                _visibleBounds = camera.visibleBounds;
              });
            },
            onTap: (_, point) => widget.onTap(point),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.scrollWheelZoom,
            ),
          ),
          children: [
            ..._tileLayers(),
            _MaidenheadGridOverlay(
              bounds: _visibleBounds,
              center: _mapCenter,
              zoom: _mapZoom,
              precision: widget.cell.precision,
            ),
            PolygonLayer(
              polygons: [
                Polygon(
                  points: [
                    osm.LatLng(
                      widget.cell.bounds.south,
                      widget.cell.bounds.west,
                    ),
                    osm.LatLng(
                      widget.cell.bounds.south,
                      widget.cell.bounds.east,
                    ),
                    osm.LatLng(
                      widget.cell.bounds.north,
                      widget.cell.bounds.east,
                    ),
                    osm.LatLng(
                      widget.cell.bounds.north,
                      widget.cell.bounds.west,
                    ),
                  ],
                  color: scheme.primary.withValues(alpha: 0.18),
                  borderColor: scheme.primary,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: osm.LatLng(
                    widget.selectedPoint.latitude,
                    widget.selectedPoint.longitude,
                  ),
                  width: 28,
                  height: 28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  widget.baseLayer == _MapBaseLayer.osm
                      ? 'OpenStreetMap contributors'
                      : '天地图',
                  onTap: () => launchUrl(
                    Uri.parse(
                      widget.baseLayer == _MapBaseLayer.osm
                          ? 'https://www.openstreetmap.org/copyright'
                          : 'https://www.tianditu.gov.cn/',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _LayerMenu(
            value: widget.baseLayer,
            tiandituEnabled: widget.tiandituToken.isNotEmpty,
            onChanged: widget.onBaseLayerChanged,
          ),
        ),
      ],
    );
  }

  List<Widget> _tileLayers() {
    if (widget.baseLayer == _MapBaseLayer.tiandituVector) {
      return [
        _tiandituLayer('vec_w'),
        _tiandituLayer('cva_w'),
      ];
    }
    if (widget.baseLayer == _MapBaseLayer.tiandituImage) {
      return [
        _tiandituLayer('img_w'),
        _tiandituLayer('cia_w'),
      ];
    }
    return [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'work.hamcy.exam.beacon',
      ),
    ];
  }

  TileLayer _tiandituLayer(String type) {
    return TileLayer(
      urlTemplate:
          'https://t{s}.tianditu.gov.cn/DataServer?T=$type&x={x}&y={y}&l={z}&tk=${widget.tiandituToken}',
      subdomains: const ['0', '1', '2', '3', '4', '5', '6', '7'],
      userAgentPackageName: 'work.hamcy.exam.beacon',
    );
  }
}

class _MaidenheadGridOverlay extends StatelessWidget {
  final LatLngBounds? bounds;
  final osm.LatLng center;
  final double zoom;
  final int precision;

  const _MaidenheadGridOverlay({
    required this.bounds,
    required this.center,
    required this.zoom,
    required this.precision,
  });

  @override
  Widget build(BuildContext context) {
    final visibleBounds = bounds;
    if (visibleBounds == null) return const SizedBox.shrink();

    final effectivePrecision = _effectivePrecision();
    final step = _stepForPrecision(effectivePrecision);
    final padded = _paddedBounds(visibleBounds, step);
    final lines = <Polyline>[
      ..._verticalLines(padded, step),
      ..._horizontalLines(padded, step),
    ];
    final labels = _labels(padded, step, effectivePrecision);
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        PolylineLayer(polylines: lines),
        if (labels.isNotEmpty) MarkerLayer(markers: labels),
        Positioned(
          left: 12,
          top: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                '$effectivePrecision 位 Grid',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

  int _effectivePrecision() {
    if (zoom < 5.5) return 4;
    if (zoom < 10) return precision <= 4 ? 4 : 6;
    if (zoom < 13.5) return precision <= 6 ? precision : 8;
    return precision;
  }

  _GridStep _stepForPrecision(int value) {
    switch (value) {
      case 4:
        return const _GridStep(latitude: 1, longitude: 2);
      case 6:
        return const _GridStep(latitude: 1 / 24, longitude: 2 / 24);
      case 8:
        return const _GridStep(latitude: 1 / 240, longitude: 2 / 240);
      case 10:
        return const _GridStep(latitude: 1 / 5760, longitude: 2 / 5760);
      default:
        return const _GridStep(latitude: 1 / 24, longitude: 2 / 24);
    }
  }

  _GridBoundsView _paddedBounds(LatLngBounds bounds, _GridStep step) {
    final latPad = step.latitude * 2;
    final lonPad = step.longitude * 2;
    final south = (bounds.south - latPad).clamp(-90.0, 90.0);
    final north = (bounds.north + latPad).clamp(-90.0, 90.0);
    final west = (bounds.west - lonPad).clamp(-180.0, 180.0);
    final east = (bounds.east + lonPad).clamp(-180.0, 180.0);
    return _GridBoundsView(
      south: south,
      west: west,
      north: north,
      east: east,
    );
  }

  List<Polyline> _verticalLines(_GridBoundsView bounds, _GridStep step) {
    final color = Colors.black.withValues(alpha: 0.34);
    final start = _snapDown(bounds.west + 180, step.longitude) - 180;
    final lines = <Polyline>[];
    for (var lon = start; lon <= bounds.east; lon += step.longitude) {
      if (lines.length >= 160) break;
      lines.add(
        Polyline(
          points: [
            osm.LatLng(bounds.south, lon),
            osm.LatLng(bounds.north, lon),
          ],
          color: color,
          strokeWidth: _strokeWidth(),
        ),
      );
    }
    return lines;
  }

  List<Polyline> _horizontalLines(_GridBoundsView bounds, _GridStep step) {
    final color = Colors.black.withValues(alpha: 0.34);
    final start = _snapDown(bounds.south + 90, step.latitude) - 90;
    final lines = <Polyline>[];
    for (var lat = start; lat <= bounds.north; lat += step.latitude) {
      if (lines.length >= 160) break;
      lines.add(
        Polyline(
          points: [
            osm.LatLng(lat, bounds.west),
            osm.LatLng(lat, bounds.east),
          ],
          color: color,
          strokeWidth: _strokeWidth(),
        ),
      );
    }
    return lines;
  }

  List<Marker> _labels(
    _GridBoundsView bounds,
    _GridStep step,
    int effectivePrecision,
  ) {
    if (effectivePrecision > 6 || zoom < 5) return const [];

    const service = GridLocatorService();
    final labelStepLat =
        effectivePrecision == 4 ? step.latitude : step.latitude * 4;
    final labelStepLon =
        effectivePrecision == 4 ? step.longitude : step.longitude * 4;
    final startLat = _snapDown(bounds.south + 90, labelStepLat) - 90;
    final startLon = _snapDown(bounds.west + 180, labelStepLon) - 180;
    final labels = <Marker>[];
    for (var lat = startLat; lat <= bounds.north; lat += labelStepLat) {
      for (var lon = startLon; lon <= bounds.east; lon += labelStepLon) {
        if (labels.length >= 60) return labels;
        final labelLat = (lat + step.latitude / 2).clamp(-89.999999, 89.999999);
        final labelLon =
            (lon + step.longitude / 2).clamp(-179.999999, 179.999999);
        final locator = service.encodeMaidenhead(
          latitude: labelLat,
          longitude: labelLon,
          precision: effectivePrecision,
        );
        labels.add(
          Marker(
            point: osm.LatLng(labelLat, labelLon),
            width: 76,
            height: 24,
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: Text(
                      locator,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return labels;
  }

  double _snapDown(double value, double step) {
    return (value / step).floorToDouble() * step;
  }

  double _strokeWidth() {
    if (precision >= 8 && zoom >= 13) return 0.8;
    if (precision >= 6 && zoom >= 9) return 1.0;
    return 1.2;
  }
}

class _GridStep {
  final double latitude;
  final double longitude;

  const _GridStep({
    required this.latitude,
    required this.longitude,
  });
}

class _GridBoundsView {
  final double south;
  final double west;
  final double north;
  final double east;

  const _GridBoundsView({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
}

class _LayerMenu extends StatelessWidget {
  final _MapBaseLayer value;
  final bool tiandituEnabled;
  final ValueChanged<_MapBaseLayer> onChanged;

  const _LayerMenu({
    required this.value,
    required this.tiandituEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: PopupMenuButton<_MapBaseLayer>(
        tooltip: '切换底图',
        initialValue: value,
        onSelected: onChanged,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _MapBaseLayer.osm,
            child: Text('OpenStreetMap'),
          ),
          PopupMenuItem(
            value: _MapBaseLayer.tiandituVector,
            enabled: tiandituEnabled,
            child: const Text('天地图矢量'),
          ),
          PopupMenuItem(
            value: _MapBaseLayer.tiandituImage,
            enabled: tiandituEnabled,
            child: const Text('天地图影像'),
          ),
        ],
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.layers_outlined),
        ),
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final TextEditingController gridController;
  final TextEditingController latController;
  final TextEditingController lonController;
  final int precision;
  final GridPoint selectedPoint;
  final GridCell cell;
  final String? message;
  final bool locating;
  final VoidCallback onSearchGrid;
  final VoidCallback onSearchCoordinates;
  final VoidCallback onUseLocation;
  final ValueChanged<int> onPrecisionChanged;
  final void Function(String value, String label) onCopy;

  const _ControlsPanel({
    required this.gridController,
    required this.latController,
    required this.lonController,
    required this.precision,
    required this.selectedPoint,
    required this.cell,
    required this.message,
    required this.locating,
    required this.onSearchGrid,
    required this.onSearchCoordinates,
    required this.onUseLocation,
    required this.onPrecisionChanged,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GRID 地图定位',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '输入 Maidenhead Grid，或点击地图/使用当前位置生成不同精度网格。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 4, label: Text('4')),
            ButtonSegment(value: 6, label: Text('6')),
            ButtonSegment(value: 8, label: Text('8')),
            ButtonSegment(value: 10, label: Text('10')),
          ],
          selected: {precision},
          onSelectionChanged: (values) => onPrecisionChanged(values.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: gridController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Grid',
                  hintText: 'OM89dw',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => onSearchGrid(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '查询 Grid',
              onPressed: onSearchGrid,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: latController,
                decoration: const InputDecoration(
                  labelText: '纬度',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onSubmitted: (_) => onSearchCoordinates(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: lonController,
                decoration: const InputDecoration(
                  labelText: '经度',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onSubmitted: (_) => onSearchCoordinates(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onSearchCoordinates,
              icon: const Icon(Icons.pin_drop_outlined),
              label: const Text('定位坐标'),
            ),
            OutlinedButton.icon(
              onPressed: locating ? null : onUseLocation,
              icon: locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(locating ? '定位中...' : '当前位置'),
            ),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          _MessagePanel(message: message!),
        ],
        const SizedBox(height: 16),
        _ResultPanel(
          cell: cell,
          selectedPoint: selectedPoint,
          precision: precision,
          onCopy: onCopy,
        ),
        const SizedBox(height: 12),
        Text(
          '仅供参考，请遵守当地法规和主管部门要求。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final String message;

  const _MessagePanel({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final GridCell cell;
  final GridPoint selectedPoint;
  final int precision;
  final void Function(String value, String label) onCopy;

  const _ResultPanel({
    required this.cell,
    required this.selectedPoint,
    required this.precision,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const service = GridLocatorService();
    final gridValues = {
      for (final item in GridLocatorService.supportedPrecisions)
        item: service.encodeMaidenhead(
          latitude: selectedPoint.latitude,
          longitude: selectedPoint.longitude,
          precision: item,
        ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cell.locator,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: '复制 Grid',
                  onPressed: () => onCopy(cell.locator, 'Grid'),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in gridValues.entries)
                  InputChip(
                    selected: entry.key == precision,
                    label: Text('${entry.key}: ${entry.value}'),
                    onPressed: () => onCopy(entry.value, '${entry.key} 位 Grid'),
                  ),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(
              label: '选点坐标',
              value:
                  '${selectedPoint.latitude.toStringAsFixed(6)}, ${selectedPoint.longitude.toStringAsFixed(6)}',
              onCopy: () => onCopy(
                '${selectedPoint.latitude.toStringAsFixed(6)}, ${selectedPoint.longitude.toStringAsFixed(6)}',
                '选点坐标',
              ),
            ),
            _InfoRow(
              label: '网格中心',
              value:
                  '${cell.center.latitude.toStringAsFixed(6)}, ${cell.center.longitude.toStringAsFixed(6)}',
              onCopy: () => onCopy(
                '${cell.center.latitude.toStringAsFixed(6)}, ${cell.center.longitude.toStringAsFixed(6)}',
                '网格中心',
              ),
            ),
            _InfoRow(
              label: '边界范围',
              value:
                  'S ${cell.bounds.south.toStringAsFixed(6)} / W ${cell.bounds.west.toStringAsFixed(6)}\nN ${cell.bounds.north.toStringAsFixed(6)} / E ${cell.bounds.east.toStringAsFixed(6)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: '复制',
              visualDensity: VisualDensity.compact,
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
            ),
        ],
      ),
    );
  }
}
