import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discovery.dart';
import '../../models/radio_profile.dart';
import '../../models/satellite_doppler.dart';
import '../../services/satellite_service.dart';

class SatelliteDetailPage extends StatefulWidget {
  final String satelliteName;
  final RadioProfile radioProfile;
  final List<String> tleSourceUrls;
  final SatelliteService service;

  const SatelliteDetailPage({
    super.key,
    required this.satelliteName,
    required this.radioProfile,
    required this.tleSourceUrls,
    required this.service,
  });

  @override
  State<SatelliteDetailPage> createState() => _SatelliteDetailPageState();
}

class _SatelliteDetailPageState extends State<SatelliteDetailPage> {
  late Future<SatelliteDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SatelliteDetail> _load() {
    return widget.service.getSatelliteDetail(
      grid: widget.radioProfile.grid,
      observer: _observerFromProfile(),
      tleSourceUrls: widget.tleSourceUrls,
      satelliteName: widget.satelliteName,
    );
  }

  ObserverLocation? _observerFromProfile() {
    final latitude = widget.radioProfile.latitude;
    final longitude = widget.radioProfile.longitude;
    if (latitude == null || longitude == null) return null;
    return ObserverLocation(
      latitude: latitude,
      longitude: longitude,
      altitudeKm: widget.radioProfile.altitudeMeters / 1000,
      label: '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
      source: '电台资料',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(widget.satelliteName),
        actions: [
          IconButton(
            tooltip: '收藏',
            onPressed: () {},
            icon: const Icon(Icons.star_border),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: FutureBuilder<SatelliteDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _DetailStateMessage(
              icon: Icons.satellite_alt,
              title: '无法加载卫星详情',
              subtitle: snapshot.error.toString(),
              action: OutlinedButton.icon(
                onPressed: () => setState(() => _future = _load()),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            );
          }

          final detail = snapshot.data!;
          final nextPass = detail.nextPass;
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _HeroCard(detail: detail),
                const SizedBox(height: 16),
                if (nextPass != null) ...[
                  _CompassEntryCard(
                    satelliteName: detail.name,
                    pass: nextPass,
                    transponders: detail.transponders,
                    observer: _observerFromProfile() ??
                        widget.service.observerFromGrid(
                          widget.radioProfile.grid,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _PassRadarCard(pass: nextPass),
                  const SizedBox(height: 16),
                ],
                _TransponderPanel(transponders: detail.transponders),
                if (nextPass != null && detail.transponders.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DopplerPredictionPanel(
                    pass: nextPass,
                    transponders: detail.transponders,
                  ),
                ],
                const SizedBox(height: 16),
                _AmsatStatusPanel(
                  summaries: detail.statusSummaries,
                  satelliteName: detail.name,
                ),
                const SizedBox(height: 16),
                _UpcomingPassPanel(passes: detail.passes),
                const SizedBox(height: 16),
                _TlePanel(detail: detail),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final SatelliteDetail detail;

  const _HeroCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final pass = detail.nextPass;
    final status = detail.catalogItem?.status;
    final callsign = detail.catalogItem?.callsign;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064D8D), Color(0xFF032D5E), Color(0xFF05223E)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SatelliteImage(
                imageUrl: detail.catalogItem?.imageUrl,
                satelliteName: detail.name,
                size: 82,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (status != null && status.isNotEmpty) ...[
                      _StatusPill(label: status),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      detail.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (detail.noradCatId == null)
                          'NORAD 未知'
                        else
                          'NORAD ${detail.noradCatId}',
                        if (callsign?.isNotEmpty == true) 'AMSAT $callsign',
                      ].join(' · '),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _HeroTleBlock(detail: detail),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _HeroMetric(
                icon: Icons.schedule,
                label: '下一次 AOS',
                value: pass == null
                    ? '暂无'
                    : DateFormat('MM-dd HH:mm').format(pass.aos),
                helper: pass == null ? '暂无预报' : _aosHelper(pass),
              ),
              _HeroMetric(
                icon: Icons.landscape,
                label: '最高仰角',
                value: pass == null
                    ? '--'
                    : '${pass.maxElevation.toStringAsFixed(0)}°',
                helper: _elevationQuality(pass?.maxElevation),
                accent: const Color(0xFF67D96B),
              ),
              _HeroMetric(
                icon: Icons.access_time,
                label: '可见时长',
                value: pass == null ? '--' : '${pass.duration.inMinutes}',
                unit: '分钟',
                helper: pass == null ? '' : _formatDuration(pass.duration),
              ),
              _HeroMetric(
                icon: Icons.settings_input_antenna,
                label: '转发器',
                value: '${detail.transponders.length}',
                unit: '个',
                helper: detail.transponders.any((item) => item.alive)
                    ? 'active'
                    : '暂无活跃',
                accent: const Color(0xFF67D96B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _aosHelper(SatellitePass pass) {
    final now = DateTime.now();
    if (pass.isActive) return '正在过境';
    final remaining = pass.aos.difference(now);
    if (remaining.isNegative) return '即将结束';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return '距离 AOS 还有 ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String _elevationQuality(double? elevation) {
    if (elevation == null) return '--';
    if (elevation >= 50) return '良好';
    if (elevation >= 25) return '可用';
    return '低仰角';
  }
}

class _SatelliteImage extends StatelessWidget {
  final String? imageUrl;
  final String satelliteName;
  final double size;

  const _SatelliteImage({
    required this.imageUrl,
    required this.satelliteName,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: imageUrl == null || imageUrl!.isEmpty
          ? null
          : () => _downloadSatelliteImage(context),
      child: Tooltip(
        message: imageUrl == null || imageUrl!.isEmpty ? '暂无卫星图' : '长按下载卫星图',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: size,
            height: size,
            color: Colors.white.withValues(alpha: 0.12),
            child: imageUrl == null || imageUrl!.isEmpty
                ? const Icon(Icons.satellite_alt, color: Colors.white)
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.satellite_alt, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadSatelliteImage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      final uri = Uri.parse(imageUrl!);
      final response = await Dio().get<List<int>>(
        imageUrl!,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('图片数据为空');
      }

      final directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final extension = _imageExtension(uri.path);
      final filename = '${_safeFileName(satelliteName)}$extension';
      final file = File('${directory.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(bytes);

      messenger.showSnackBar(SnackBar(content: Text('卫星图已保存到 ${file.path}')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('下载卫星图失败: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  String _safeFileName(String value) {
    final normalized = value.trim().isEmpty ? 'satellite' : value.trim();
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  String _imageExtension(String path) {
    final match = RegExp(r'\.([A-Za-z0-9]{2,5})$').firstMatch(path);
    final extension = match?.group(0)?.toLowerCase();
    if (extension == null) return '.jpg';
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
      return extension;
    }
    return '.jpg';
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String helper;
  final Color? accent;

  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.unit = '',
    this.helper = '',
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Colors.white;
    return SizedBox(
      width: 136,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          if (helper.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              helper,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    (accent ?? const Color(0xFF64B5F6)).withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroTleBlock extends StatelessWidget {
  final SatelliteDetail detail;

  const _HeroTleBlock({required this.detail});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TLE 来源',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            detail.tleSource,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.16), height: 18),
          const Text('更新',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.tleUpdatedAt == null
                      ? '刚刚'
                      : DateFormat('MM-dd HH:mm').format(detail.tleUpdatedAt!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.refresh, color: Colors.white, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _PassRadarCard extends StatelessWidget {
  final SatellitePass pass;

  const _PassRadarCard({required this.pass});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _DetailPanel(
      title: '过境轨迹',
      icon: Icons.radar,
      child: Row(
        children: [
          SizedBox(
            width: 156,
            height: 156,
            child: CustomPaint(painter: _PassRadarPainter(pass, scheme)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                _InfoRow('AOS', DateFormat('MM-dd HH:mm').format(pass.aos)),
                _InfoRow('LOS', DateFormat('HH:mm').format(pass.los)),
                _InfoRow('时长', '${pass.duration.inMinutes} 分钟'),
                _InfoRow('入/出方位',
                    '${pass.aosAzimuth.toStringAsFixed(0)}° / ${pass.losAzimuth.toStringAsFixed(0)}°'),
                _InfoRow('最高仰角', '${pass.maxElevation.toStringAsFixed(0)}°'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassEntryCard extends StatelessWidget {
  final String satelliteName;
  final SatellitePass pass;
  final List<SatelliteTransponder> transponders;
  final ObserverLocation? observer;

  const _CompassEntryCard({
    required this.satelliteName,
    required this.pass,
    required this.transponders,
    required this.observer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
            ),
            child: Icon(Icons.explore, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '实时大罗盘',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '全屏轨迹罗盘、实时方位仰角和 UV 多普勒频移',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _SatelliteCompassPage(
                  satelliteName: satelliteName,
                  pass: pass,
                  transponders: transponders,
                  observer: observer,
                ),
              ),
            ),
            icon: const Icon(Icons.open_in_full),
            label: const Text('打开'),
          ),
        ],
      ),
    );
  }
}

class _SatelliteCompassPage extends StatelessWidget {
  final String satelliteName;
  final SatellitePass pass;
  final List<SatelliteTransponder> transponders;
  final ObserverLocation? observer;

  const _SatelliteCompassPage({
    required this.satelliteName,
    required this.pass,
    required this.transponders,
    required this.observer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('$satelliteName 实时大罗盘'),
      ),
      body: StreamBuilder<DateTime>(
        stream: Stream<DateTime>.periodic(
          const Duration(seconds: 1),
          (_) => DateTime.now(),
        ),
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          final target = _interpolatedLook(pass, now);
          final phase = _passPhase(pass, now);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = min(constraints.maxWidth, 520.0);
                  return Center(
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: CustomPaint(
                        painter: _LargeCompassPainter(
                          pass: pass,
                          target: target,
                          scheme: scheme,
                          now: now,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _CompassStatusPanel(
                pass: pass,
                target: target,
                phase: phase,
                observer: observer,
                now: now,
              ),
              const SizedBox(height: 16),
              _RealtimeDopplerPanel(
                pass: pass,
                transponders: transponders,
                now: now,
              ),
              const SizedBox(height: 10),
              Text(
                '仅供参考，请遵守当地法规和主管部门要求。',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompassLook {
  final double azimuth;
  final double elevation;
  final double? rangeKm;
  final double? dopplerFactor;

  const _CompassLook({
    required this.azimuth,
    required this.elevation,
    this.rangeKm,
    this.dopplerFactor,
  });
}

class _CompassStatusPanel extends StatelessWidget {
  final SatellitePass pass;
  final _CompassLook target;
  final _PassPhase phase;
  final ObserverLocation? observer;
  final DateTime now;

  const _CompassStatusPanel({
    required this.pass,
    required this.target,
    required this.phase,
    required this.observer,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                phase.icon,
                color: phase.color(scheme),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  phase.label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                DateFormat('HH:mm:ss').format(now.toLocal()),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CompassMetric('目标方位', '${target.azimuth.toStringAsFixed(0)}°'),
              _CompassMetric('目标仰角', '${target.elevation.toStringAsFixed(0)}°'),
              _CompassMetric(
                '距离',
                target.rangeKm == null
                    ? '--'
                    : '${target.rangeKm!.toStringAsFixed(0)} km',
              ),
              _CompassMetric('AOS', DateFormat('HH:mm').format(pass.aos)),
              _CompassMetric(
                'TCA',
                DateFormat('HH:mm').format(pass.maxElevationAt),
              ),
              _CompassMetric('LOS', DateFormat('HH:mm').format(pass.los)),
              _CompassMetric(
                '最高仰角',
                '${pass.maxElevation.toStringAsFixed(0)}°',
              ),
              _CompassMetric(
                '观测者',
                observer == null
                    ? 'Grid'
                    : '${observer!.source} ${(observer!.altitudeKm * 1000).toStringAsFixed(0)} m',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompassMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CompassMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _RealtimeDopplerPanel extends StatelessWidget {
  static const _vhfHz = 145800000;
  static const _uhfHz = 435000000;

  final SatellitePass pass;
  final List<SatelliteTransponder> transponders;
  final DateTime now;

  const _RealtimeDopplerPanel({
    required this.pass,
    required this.transponders,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final currentPoint = currentDopplerPoint(pass, now);
    final points = [
      if (currentPoint != null) currentPoint,
      ...dopplerPassPoints(pass),
    ];
    final scheme = Theme.of(context).colorScheme;
    return _DetailPanel(
      title: 'UV 多普勒',
      icon: Icons.graphic_eq,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: scheme.surfaceContainerLowest,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: points.isEmpty
            ? Text(
                '当前过境数据缺少有效多普勒采样。',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pass.isActive
                        ? '当前过境窗口内，按实时插值显示。'
                        : '当前未过境，显示 AOS / TCA / LOS 预测值。',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  _DopplerFrequencyTable(
                    title: '固定参考',
                    rows: const [
                      _DopplerFrequencyRow('VHF', _vhfHz),
                      _DopplerFrequencyRow('UHF', _uhfHz),
                    ],
                    points: points,
                  ),
                  ..._realFrequencyTables(points),
                ],
              ),
      ),
    );
  }

  List<Widget> _realFrequencyTables(List<DopplerPassPoint> points) {
    final usable = transponders
        .where((item) => item.uplinkLow != null || item.downlinkLow != null)
        .toList();
    return [
      for (var index = 0; index < usable.length; index++) ...[
        const SizedBox(height: 12),
        _DopplerFrequencyTable(
          title:
              '转发器 ${index + 1} · ${usable[index].mode.isEmpty ? usable[index].description : usable[index].mode}',
          rows: [
            if (usable[index].downlinkLow != null)
              _DopplerFrequencyRow('下行', usable[index].downlinkLow!),
            if (usable[index].uplinkLow != null)
              _DopplerFrequencyRow('上行', usable[index].uplinkLow!),
          ],
          points: points,
        ),
      ],
    ];
  }
}

class _DopplerFrequencyRow {
  final String label;
  final int hz;

  const _DopplerFrequencyRow(this.label, this.hz);
}

class _DopplerFrequencyTable extends StatelessWidget {
  final String title;
  final List<_DopplerFrequencyRow> rows;
  final List<DopplerPassPoint> points;

  const _DopplerFrequencyTable({
    required this.title,
    required this.rows,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 30,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 44,
            columnSpacing: 12,
            horizontalMargin: 8,
            columns: const [
              DataColumn(label: Text('频点')),
              DataColumn(label: Text('时刻')),
              DataColumn(label: Text('偏移')),
              DataColumn(label: Text('修正后')),
            ],
            rows: [
              for (final row in rows)
                for (final point in points)
                  DataRow(
                    selected: point.isCurrent,
                    cells: [
                      DataCell(Text(row.label)),
                      DataCell(Text(point.label)),
                      DataCell(Text(frequencyOffset(row.hz, point.factor))),
                      DataCell(Text(shiftedFrequency(row.hz, point.factor))),
                    ],
                  ),
            ],
          ),
        ),
        if (rows.isEmpty)
          Text('暂无可用频点', style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _LargeCompassPainter extends CustomPainter {
  final SatellitePass pass;
  final _CompassLook target;
  final ColorScheme scheme;
  final DateTime now;

  const _LargeCompassPainter({
    required this.pass,
    required this.target,
    required this.scheme,
    required this.now,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 34;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outlineVariant.withValues(alpha: 0.72);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = scheme.primary.withValues(alpha: 0.86);

    canvas.drawCircle(
      center,
      radius + 18,
      Paint()..color = scheme.surfaceContainerHighest.withValues(alpha: 0.45),
    );
    for (final scale in [1.0, 0.66, 0.33]) {
      canvas.drawCircle(center, radius * scale, gridPaint);
    }
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      gridPaint,
    );

    for (var degree = 0; degree < 360; degree += 10) {
      final major = degree % 30 == 0;
      final angle = (degree - 90) * pi / 180;
      final start = Offset(
        center.dx + cos(angle) * (radius - (major ? 12 : 7)),
        center.dy + sin(angle) * (radius - (major ? 12 : 7)),
      );
      final end = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = major ? 2 : 1
          ..color = scheme.onSurface.withValues(alpha: major ? 0.72 : 0.38),
      );
    }

    _drawCompassLabel(canvas, center, radius + 21, 'N', 0);
    _drawCompassLabel(canvas, center, radius + 21, 'E', 90);
    _drawCompassLabel(canvas, center, radius + 21, 'S', 180);
    _drawCompassLabel(canvas, center, radius + 21, 'W', 270);
    _drawElevationLabel(canvas, center, radius * 0.66, '30°');
    _drawElevationLabel(canvas, center, radius * 0.33, '60°');
    _drawElevationLabel(canvas, center, 0, '90°');

    _drawTrack(canvas, center, radius);
    _drawEventMarker(canvas, center, radius, pass.aosAzimuth, 0, 'AOS');
    _drawEventMarker(
      canvas,
      center,
      radius,
      _lookAtTime(pass.maxElevationAt).azimuth,
      pass.maxElevation,
      'TCA',
    );
    _drawEventMarker(canvas, center, radius, pass.losAzimuth, 0, 'LOS');

    final targetPoint =
        _polarPoint(center, radius, target.azimuth, target.elevation);
    canvas.drawCircle(
      targetPoint,
      13,
      Paint()..color = const Color(0xFFFFB020),
    );
    canvas.drawCircle(
      targetPoint,
      19,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFB020).withValues(alpha: 0.35),
    );
    _drawSatelliteIcon(canvas, targetPoint);
    _drawNowLabel(canvas, targetPoint);
  }

  void _drawTrack(Canvas canvas, Offset center, double radius) {
    final samples = pass.lookSamples;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = scheme.primary.withValues(alpha: 0.78);
    final futurePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = scheme.primary.withValues(alpha: 0.28);

    if (samples.length >= 2) {
      final pastPath = Path();
      final futurePath = Path();
      var hasPast = false;
      var hasFuture = false;
      for (var index = 0; index < samples.length; index++) {
        final sample = samples[index];
        final point = _polarPoint(
          center,
          radius,
          sample.azimuth,
          sample.elevation,
        );
        if (!sample.time.isAfter(now)) {
          if (!hasPast) {
            pastPath.moveTo(point.dx, point.dy);
            hasPast = true;
          } else {
            pastPath.lineTo(point.dx, point.dy);
          }
        }
        if (!sample.time.isBefore(now)) {
          if (!hasFuture) {
            futurePath.moveTo(point.dx, point.dy);
            hasFuture = true;
          } else {
            futurePath.lineTo(point.dx, point.dy);
          }
        }
      }
      if (hasPast) canvas.drawPath(pastPath, trackPaint);
      if (hasFuture) canvas.drawPath(futurePath, futurePaint);
      return;
    }

    final start = _polarPoint(center, radius, pass.aosAzimuth, 0);
    final peak = _polarPoint(
      center,
      radius,
      (pass.aosAzimuth + pass.losAzimuth) / 2,
      pass.maxElevation,
    );
    final end = _polarPoint(center, radius, pass.losAzimuth, 0);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(peak.dx, peak.dy, end.dx, end.dy);
    canvas.drawPath(path, futurePaint);
  }

  void _drawEventMarker(
    Canvas canvas,
    Offset center,
    double radius,
    double azimuth,
    double elevation,
    String label,
  ) {
    final point = _polarPoint(center, radius, azimuth, elevation);
    canvas.drawCircle(
      point,
      4.5,
      Paint()..color = scheme.onSurface.withValues(alpha: 0.76),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(point.dx + 6, point.dy - painter.height / 2));
  }

  _CompassLook _lookAtTime(DateTime time) {
    return _interpolatedLook(pass, time);
  }

  void _drawSatelliteIcon(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, 4, paint);
    canvas.drawLine(
      Offset(center.dx - 9, center.dy - 9),
      Offset(center.dx - 3, center.dy - 3),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 3, center.dy + 3),
      Offset(center.dx + 9, center.dy + 9),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - 11, center.dy - 4),
      Offset(center.dx - 4, center.dy - 11),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 4, center.dy + 11),
      Offset(center.dx + 11, center.dy + 4),
      paint,
    );
  }

  void _drawNowLabel(Canvas canvas, Offset point) {
    final painter = TextPainter(
      text: TextSpan(
        text:
            '${target.azimuth.toStringAsFixed(0)}° / ${target.elevation.toStringAsFixed(0)}°',
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final offset = Offset(
      (point.dx + 12).clamp(0, double.infinity).toDouble(),
      point.dy - painter.height - 10,
    );
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offset.dx - 6,
        offset.dy - 4,
        painter.width + 12,
        painter.height + 8,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = scheme.surface.withValues(alpha: 0.84),
    );
    painter.paint(canvas, offset);
  }

  Offset _polarPoint(
      Offset center, double radius, double azimuth, double elevation) {
    final polarRadius = radius * (1 - elevation.clamp(0, 90) / 90);
    final angle = (azimuth - 90) * pi / 180;
    return Offset(
      center.dx + cos(angle) * polarRadius,
      center.dy + sin(angle) * polarRadius,
    );
  }

  void _drawCompassLabel(Canvas canvas, Offset center, double radius,
      String label, double degree) {
    final angle = (degree - 90) * pi / 180;
    final point = Offset(
      center.dx + cos(angle) * radius,
      center.dy + sin(angle) * radius,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(point.dx - painter.width / 2, point.dy - painter.height / 2),
    );
  }

  void _drawElevationLabel(
      Canvas canvas, Offset center, double radius, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx + radius + 4, center.dy - painter.height - 2),
    );
  }

  @override
  bool shouldRepaint(covariant _LargeCompassPainter oldDelegate) {
    return oldDelegate.pass != pass ||
        oldDelegate.target != target ||
        oldDelegate.scheme != scheme ||
        oldDelegate.now != now;
  }
}

class _TransponderPanel extends StatelessWidget {
  final List<SatelliteTransponder> transponders;

  const _TransponderPanel({required this.transponders});

  @override
  Widget build(BuildContext context) {
    if (transponders.isEmpty) {
      return const _DetailPanel(
        title: '转发器',
        icon: Icons.settings_input_antenna,
        child: Text('暂无公开转发器信息'),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < transponders.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TransponderCard(
              index: index + 1,
              transponder: transponders[index],
            ),
          ),
      ],
    );
  }
}

class _TransponderCard extends StatelessWidget {
  final int index;
  final SatelliteTransponder transponder;

  const _TransponderCard({
    required this.index,
    required this.transponder,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_input_antenna,
                  color: Colors.deepOrange.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '转发器 $index',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _StatusPill(
                label: transponder.status,
                color: transponder.alive ? const Color(0xFF4CAF50) : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final width = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 40) / 3;
              return Wrap(
                spacing: 20,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _TransponderMetric(
                      label: '上行频率（发射）',
                      value: _formatFrequency(transponder.uplinkLow),
                      helper: _rangeLabel(transponder.uplinkLow),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _TransponderMetric(
                      label: '下行频率（接收）',
                      value: _formatFrequency(transponder.downlinkLow),
                      helper: _rangeLabel(transponder.downlinkLow),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _TransponderMetric(
                      label: '模式',
                      value: transponder.mode.isEmpty ? '--' : transponder.mode,
                      helper: transponder.description,
                      accent: scheme.onSurface,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _rangeLabel(int? hz) {
    if (hz == null || hz <= 0) return '范围：--';
    final mhz = hz / 1000000;
    return '范围：${mhz.toStringAsFixed(3)} MHz';
  }
}

class _TransponderMetric extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color? accent;

  const _TransponderMetric({
    required this.label,
    required this.value,
    required this.helper,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent ?? scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helper,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DopplerPredictionPanel extends StatelessWidget {
  final SatellitePass pass;
  final List<SatelliteTransponder> transponders;

  const _DopplerPredictionPanel({
    required this.pass,
    required this.transponders,
  });

  @override
  Widget build(BuildContext context) {
    final usable = transponders
        .where((item) => item.uplinkLow != null || item.downlinkLow != null)
        .toList();
    if (usable.isEmpty) {
      return const _DetailPanel(
        title: '多普勒频移预测',
        icon: Icons.graphic_eq,
        child: Text('暂无可用于计算的转发器频率'),
      );
    }
    return _DetailPanel(
      title: '多普勒频移',
      icon: Icons.graphic_eq,
      child: StreamBuilder<DateTime>(
        stream: Stream<DateTime>.periodic(
          const Duration(seconds: 1),
          (_) => DateTime.now(),
        ),
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          final currentPoint = currentDopplerPoint(pass, now);
          final points = [
            if (currentPoint != null) currentPoint,
            ...dopplerPassPoints(pass),
          ];
          if (points.isEmpty) {
            return Text(
              '当前过境数据缺少有效多普勒采样。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pass.isActive
                    ? '正在按当前时间实时估算多普勒修正。下行显示建议接收频率；上行显示建议发射修正参考。'
                    : '当前未过境，先显示下一次过境的 AOS / TCA / LOS 预测值。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < usable.length; index++) ...[
                _DopplerTransponderCard(
                  index: index + 1,
                  transponder: usable[index],
                  points: points,
                ),
                if (index != usable.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DopplerTransponderCard extends StatelessWidget {
  final int index;
  final SatelliteTransponder transponder;
  final List<DopplerPassPoint> points;

  const _DopplerTransponderCard({
    required this.index,
    required this.transponder,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '转发器 $index · ${transponder.mode.isEmpty ? transponder.description : transponder.mode}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
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
                DataColumn(label: Text('下行接收')),
                DataColumn(label: Text('下行偏移')),
                DataColumn(label: Text('上行发射')),
                DataColumn(label: Text('上行偏移')),
              ],
              rows: [
                for (final point in points)
                  DataRow(
                    selected: point.isCurrent,
                    cells: [
                      DataCell(Text(point.label)),
                      DataCell(Text(shiftedFrequency(
                        transponder.downlinkLow,
                        point.factor,
                      ))),
                      DataCell(Text(frequencyOffset(
                        transponder.downlinkLow,
                        point.factor,
                      ))),
                      DataCell(Text(shiftedFrequency(
                        transponder.uplinkLow,
                        point.factor,
                      ))),
                      DataCell(Text(frequencyOffset(
                        transponder.uplinkLow,
                        point.factor,
                      ))),
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

class _AmsatStatusPanel extends StatelessWidget {
  final List<SatelliteStatusSummary> summaries;
  final String satelliteName;

  const _AmsatStatusPanel({
    required this.summaries,
    required this.satelliteName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.satellite_alt, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AMSAT 状态',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://amsat.org/status'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('查看 AMSAT 页面'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (summaries.isEmpty)
            Text(
              '暂无 AMSAT 状态报告\n最近未收到该卫星的信号报告。',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            Column(
              children: summaries
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AmsatStatusTile(summary: item),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _AmsatStatusTile extends StatelessWidget {
  final SatelliteStatusSummary summary;

  const _AmsatStatusTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (summary.statusLevel) {
      'crew_active' => scheme.tertiary,
      'active' => scheme.primary,
      'telemetry' => Colors.orange,
      'silent' => scheme.error,
      _ => scheme.outline,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(_amsatStatusIcon(summary.statusLevel), color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _amsatStatusText(summary.report),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  summary.reportLabel.isEmpty
                      ? summary.report
                      : summary.reportLabel,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            [
              '${summary.reportCount} 次',
              if (summary.latestReportedAt != null)
                DateFormat('MM-dd HH:mm')
                    .format(summary.latestReportedAt!.toLocal()),
            ].join('\n'),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  IconData _amsatStatusIcon(String level) {
    return switch (level) {
      'crew_active' => Icons.record_voice_over,
      'active' => Icons.check_circle,
      'telemetry' => Icons.sensors,
      'silent' => Icons.signal_cellular_connected_no_internet_4_bar,
      _ => Icons.help_outline,
    };
  }

  String _amsatStatusText(String report) {
    return switch (report) {
      'Heard' => '可接收',
      'Telemetry Only' => '仅遥测/信标',
      'Not Heard' => '未听到',
      'Crew Active' => '乘组语音活跃',
      _ => report,
    };
  }
}

class _UpcomingPassPanel extends StatelessWidget {
  final List<SatellitePass> passes;

  const _UpcomingPassPanel({required this.passes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, color: Colors.deepOrange.shade600),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '后续过境',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            IconButton(
              tooltip: '说明',
              onPressed: () {},
              icon: Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children:
              passes.take(10).map((pass) => _PassRow(pass: pass)).toList(),
        ),
      ],
    );
  }
}

class _PassRow extends StatelessWidget {
  final SatellitePass pass;

  const _PassRow({required this.pass});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _elevationColor(pass.maxElevation);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(width: 5, height: 92, color: color),
          const SizedBox(width: 20),
          Container(
            width: 72,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: color.withValues(alpha: 0.10),
            ),
            child: Text(
              '${pass.maxElevation.toStringAsFixed(0)}°',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MM-dd HH:mm').format(pass.aos),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pass.duration.inMinutes} 分钟 · ${pass.aosAzimuth.toStringAsFixed(0)}° -> ${pass.losAzimuth.toStringAsFixed(0)}°',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '提醒',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
    );
  }

  Color _elevationColor(double elevation) {
    if (elevation >= 45) return const Color(0xFF2F9E2F);
    if (elevation >= 25) return Colors.deepOrange;
    return const Color(0xFFE7A900);
  }
}

class _TlePanel extends StatelessWidget {
  final SatelliteDetail detail;

  const _TlePanel({required this.detail});

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      title: '轨道数据',
      icon: Icons.storage,
      child: Column(
        children: [
          _InfoRow('来源', detail.tleSource),
          _InfoRow(
            '缓存更新时间',
            detail.tleUpdatedAt == null
                ? '本次未记录'
                : DateFormat('MM-dd HH:mm').format(detail.tleUpdatedAt!),
          ),
          const _InfoRow('计算方式', 'TLE / SGP4'),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: scheme.outline, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color? color;

  const _StatusPill({
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: tint.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tint,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _DetailStateMessage({
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

class _PassRadarPainter extends CustomPainter {
  final SatellitePass pass;
  final ColorScheme scheme;

  _PassRadarPainter(this.pass, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    final gridPaint = Paint()
      ..color = scheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final pathPaint = Paint()
      ..color = scheme.primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    for (final scale in [1.0, 0.66, 0.33]) {
      canvas.drawCircle(center, radius * scale, gridPaint);
    }
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      axisPaint,
    );

    if (pass.lookSamples.length >= 2) {
      final path = Path();
      for (var i = 0; i < pass.lookSamples.length; i++) {
        final sample = pass.lookSamples[i];
        final point = _point(center, radius, sample.azimuth, sample.elevation);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, pathPaint);
    } else {
      final start = _point(center, radius, pass.aosAzimuth, 0);
      final peak = _point(center, radius,
          (pass.aosAzimuth + pass.losAzimuth) / 2, pass.maxElevation);
      final end = _point(center, radius, pass.losAzimuth, 0);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(peak.dx, peak.dy, end.dx, end.dy);
      canvas.drawPath(path, pathPaint);
    }

    final current = pass.currentAzimuth == null || pass.currentElevation == null
        ? _point(center, radius, (pass.aosAzimuth + pass.losAzimuth) / 2,
            pass.maxElevation)
        : _point(center, radius, pass.currentAzimuth!, pass.currentElevation!);
    final dotPaint = Paint()..color = scheme.tertiary;
    canvas.drawCircle(current, 5, dotPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(center.dx - 4, center.dy - radius - 3));
  }

  Offset _point(
      Offset center, double radius, double azimuth, double elevation) {
    final polarRadius = radius * (1 - elevation.clamp(0, 90) / 90);
    final angle = (azimuth - 90) * pi / 180;
    return Offset(
      center.dx + cos(angle) * polarRadius,
      center.dy + sin(angle) * polarRadius,
    );
  }

  @override
  bool shouldRepaint(covariant _PassRadarPainter oldDelegate) {
    return oldDelegate.pass != pass || oldDelegate.scheme != scheme;
  }
}

String _formatFrequency(int? hz) {
  if (hz == null || hz <= 0) return '--';
  return '${(hz / 1000000).toStringAsFixed(3)} MHz';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours <= 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

class _PassPhase {
  final String label;
  final IconData icon;
  final Color Function(ColorScheme scheme) color;

  const _PassPhase({
    required this.label,
    required this.icon,
    required this.color,
  });
}

_PassPhase _passPhase(SatellitePass pass, DateTime now) {
  if (now.isBefore(pass.aos)) {
    final remaining = pass.aos.difference(now);
    return _PassPhase(
      label: '未进入过境窗口，距离 AOS ${_formatDuration(remaining)}',
      icon: Icons.schedule,
      color: (scheme) => scheme.primary,
    );
  }
  if (now.isAfter(pass.los)) {
    return _PassPhase(
      label: '本次过境已结束',
      icon: Icons.check_circle_outline,
      color: (scheme) => scheme.outline,
    );
  }
  if (now.isBefore(pass.maxElevationAt)) {
    final remaining = pass.maxElevationAt.difference(now);
    return _PassPhase(
      label: '过境中，上升段，距离 TCA ${_formatDuration(remaining)}',
      icon: Icons.trending_up,
      color: (scheme) => const Color(0xFF2F9E44),
    );
  }
  final remaining = pass.los.difference(now);
  return _PassPhase(
    label: '过境中，下降段，距离 LOS ${_formatDuration(remaining)}',
    icon: Icons.trending_down,
    color: (scheme) => Colors.deepOrange,
  );
}

double _bearingDelta(double heading, double target) {
  return (target - heading + 540) % 360 - 180;
}

_CompassLook _interpolatedLook(SatellitePass pass, DateTime target) {
  final samples = pass.lookSamples;
  if (samples.isEmpty) {
    return _CompassLook(
      azimuth: pass.currentAzimuth ?? ((pass.aosAzimuth + pass.losAzimuth) / 2),
      elevation: pass.currentElevation ?? pass.maxElevation,
      rangeKm: pass.currentRangeKm,
      dopplerFactor: pass.dopplerFactor,
    );
  }
  if (!target.isAfter(samples.first.time)) {
    return _lookFromSample(samples.first);
  }
  if (!target.isBefore(samples.last.time)) {
    return _lookFromSample(samples.last);
  }

  for (var index = 1; index < samples.length; index++) {
    final previous = samples[index - 1];
    final next = samples[index];
    if (target.isBefore(previous.time) || target.isAfter(next.time)) {
      continue;
    }
    final span = next.time.difference(previous.time).inMilliseconds;
    if (span <= 0) return _lookFromSample(next);
    final elapsed = target.difference(previous.time).inMilliseconds;
    final ratio = (elapsed / span).clamp(0.0, 1.0);
    return _CompassLook(
      azimuth: _interpolateAngle(previous.azimuth, next.azimuth, ratio),
      elevation:
          previous.elevation + (next.elevation - previous.elevation) * ratio,
      rangeKm: previous.rangeKm + (next.rangeKm - previous.rangeKm) * ratio,
      dopplerFactor: _interpolateNullable(
        previous.dopplerFactor,
        next.dopplerFactor,
        ratio,
      ),
    );
  }
  return _lookFromSample(samples.last);
}

_CompassLook _lookFromSample(SatelliteLookSample sample) {
  return _CompassLook(
    azimuth: sample.azimuth,
    elevation: sample.elevation,
    rangeKm: sample.rangeKm,
    dopplerFactor: sample.dopplerFactor,
  );
}

double _interpolateAngle(double start, double end, double ratio) {
  final delta = _bearingDelta(start, end);
  return (start + delta * ratio + 360) % 360;
}

double? _interpolateNullable(double? start, double? end, double ratio) {
  if (start == null || end == null) return start ?? end;
  return start + (end - start) * ratio;
}
