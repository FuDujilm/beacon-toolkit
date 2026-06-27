import 'dart:async';
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
import '../../services/satellite_observer_service.dart';
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
      tleSourceUrls: widget.tleSourceUrls,
      satelliteName: widget.satelliteName,
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
                  _PhoneAimCard(pass: nextPass),
                  const SizedBox(height: 16),
                  _PassRadarCard(pass: nextPass),
                  const SizedBox(height: 16),
                ],
                _TransponderPanel(transponders: detail.transponders),
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

class _PhoneAimCard extends StatefulWidget {
  final SatellitePass pass;

  const _PhoneAimCard({required this.pass});

  @override
  State<_PhoneAimCard> createState() => _PhoneAimCardState();
}

class _PhoneAimCardState extends State<_PhoneAimCard> {
  final _observerService = SatelliteObserverService();
  StreamSubscription<DeviceAimState>? _subscription;
  DeviceAimState? _aim;
  Object? _sensorError;

  @override
  void initState() {
    super.initState();
    _subscription = _observerService.deviceAimStream.listen(
      (aim) {
        if (mounted) setState(() => _aim = aim);
      },
      onError: (error) {
        if (mounted) setState(() => _sensorError = error);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final targetAzimuth = widget.pass.currentAzimuth ??
        ((widget.pass.aosAzimuth + widget.pass.losAzimuth) / 2) % 360;
    final targetElevation =
        widget.pass.currentElevation ?? widget.pass.maxElevation;
    final azimuthDelta =
        _aim == null ? null : _bearingDelta(_aim!.heading, targetAzimuth);
    final elevationDelta =
        _aim == null ? null : targetElevation - _aim!.elevation;
    final locked = azimuthDelta != null &&
        elevationDelta != null &&
        azimuthDelta.abs() <= 8 &&
        elevationDelta.abs() <= 6;
    return _DetailPanel(
      title: '手机对星',
      icon: Icons.phone_iphone,
      child: Container(
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final radar = SizedBox(
              width: compact ? 220 : 240,
              height: compact ? 220 : 240,
              child: CustomPaint(
                painter: _PhoneAimPainter(
                  targetAzimuth: targetAzimuth,
                  phoneHeading: _aim?.heading,
                  locked: locked,
                  scheme: scheme,
                ),
              ),
            );
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings_input_antenna, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        locked
                            ? '已对准卫星方向'
                            : _aim == null
                                ? '正在搜索卫星方向'
                                : _aimInstruction(
                                    azimuthDelta!, elevationDelta!),
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _sensorError != null
                      ? '无法读取传感器，当前仅显示目标方向。'
                      : _aim == null
                          ? '请将手机朝向绿色扇区'
                          : locked
                              ? '传感器正常'
                              : '请按提示微调手机方向',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const Divider(height: 26),
                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${targetAzimuth.toStringAsFixed(0)}°',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: ' / ',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: '${targetElevation.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            color: Color(0xFF2FAD37),
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AimMetric(
                          '当前方位',
                          _aim == null
                              ? '--'
                              : '${_aim!.heading.toStringAsFixed(0)}°',
                        ),
                      ),
                      _MetricDivider(color: scheme.outlineVariant),
                      Expanded(
                        child: _AimMetric(
                          '当前仰角',
                          _aim == null
                              ? '--'
                              : '${_aim!.elevation.toStringAsFixed(0)}°',
                        ),
                      ),
                      _MetricDivider(color: scheme.outlineVariant),
                      Expanded(
                        child: _AimMetric(
                          '误差',
                          azimuthDelta == null || elevationDelta == null
                              ? '--'
                              : '${max(azimuthDelta.abs(), elevationDelta.abs()).toStringAsFixed(0)}°',
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.explore),
                        label: const Text('校准罗盘'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.my_location),
                        label: const Text('开始实时对星'),
                      ),
                    ),
                  ],
                ),
              ],
            );
            if (compact) {
              return Column(
                children: [
                  radar,
                  const SizedBox(height: 18),
                  info,
                ],
              );
            }
            return Row(
              children: [
                radar,
                const SizedBox(width: 24),
                Expanded(child: info),
              ],
            );
          },
        ),
      ),
    );
  }

  String _aimInstruction(double azimuthDelta, double elevationDelta) {
    final horizontal = azimuthDelta.abs() <= 8
        ? '方向保持'
        : azimuthDelta > 0
            ? '向右 ${azimuthDelta.abs().toStringAsFixed(0)}°'
            : '向左 ${azimuthDelta.abs().toStringAsFixed(0)}°';
    final vertical = elevationDelta.abs() <= 6
        ? '仰角保持'
        : elevationDelta > 0
            ? '抬高 ${elevationDelta.abs().toStringAsFixed(0)}°'
            : '压低 ${elevationDelta.abs().toStringAsFixed(0)}°';
    return '$horizontal · $vertical';
  }
}

class _PhoneAimPainter extends CustomPainter {
  final double targetAzimuth;
  final double? phoneHeading;
  final bool locked;
  final ColorScheme scheme;

  const _PhoneAimPainter({
    required this.targetAzimuth,
    required this.phoneHeading,
    required this.locked,
    required this.scheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 28;
    final outerRadius = radius - 2;
    final angle = (targetAzimuth - 90) * pi / 180;
    const sweep = 62 * pi / 180;

    final backgroundPaint = Paint()
      ..color = scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2D7BE8);
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outlineVariant.withValues(alpha: 0.7);
    final sectorPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        outerRadius,
        [
          const Color(0xFF4CAF50).withValues(alpha: 0.42),
          const Color(0xFF4CAF50).withValues(alpha: 0.88),
        ],
      );

    canvas.drawCircle(center, outerRadius, backgroundPaint);
    canvas.drawCircle(center, outerRadius, gridPaint);

    final sectorPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: outerRadius - 14),
        angle - sweep / 2,
        sweep,
        false,
      )
      ..close();
    canvas.drawPath(sectorPath, sectorPaint);

    final sectorEdgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF2F9E44).withValues(alpha: 0.82);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius - 14),
      angle - sweep / 2,
      sweep,
      false,
      sectorEdgePaint,
    );
    canvas.drawCircle(center, outerRadius, outerRingPaint);

    _drawDirectionLabel(canvas, center, outerRadius, 'N', -90);
    _drawDirectionLabel(canvas, center, outerRadius, 'E', 0);
    _drawDirectionLabel(canvas, center, outerRadius, 'S', 90);
    _drawDirectionLabel(canvas, center, outerRadius, 'W', 180);

    final targetPoint = Offset(
      center.dx + cos(angle) * (outerRadius - 24),
      center.dy + sin(angle) * (outerRadius - 24),
    );
    canvas.drawCircle(
      targetPoint,
      17,
      Paint()..color = scheme.surfaceContainerLowest,
    );
    canvas.drawCircle(
      targetPoint,
      15,
      Paint()..color = const Color(0xFF43A047),
    );
    _drawTargetIcon(canvas, targetPoint, scheme.surfaceContainerLowest);

    if (phoneHeading != null && !locked) {
      final phoneAngle = (phoneHeading! - 90) * pi / 180;
      final phonePoint = Offset(
        center.dx + cos(phoneAngle) * (outerRadius - 18),
        center.dy + sin(phoneAngle) * (outerRadius - 18),
      );
      canvas.drawLine(
        center,
        phonePoint,
        Paint()
          ..color = scheme.onSurface.withValues(alpha: 0.55)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    final centerPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(60, 60),
        const [Color(0xFF0E4C93), Color(0xFF2E78D7)],
      );
    canvas.drawCircle(center, outerRadius * 0.28, centerPaint);
  }

  void _drawDirectionLabel(
    Canvas canvas,
    Offset center,
    double radius,
    String label,
    double degrees,
  ) {
    final angle = degrees * pi / 180;
    final point = Offset(
      center.dx + cos(angle) * (radius + 18),
      center.dy + sin(angle) * (radius + 18),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final labelRect = Rect.fromCenter(
      center: point,
      width: painter.width + 10,
      height: painter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(999)),
      Paint()..color = scheme.surface.withValues(alpha: 0.62),
    );
    painter.paint(
      canvas,
      Offset(
        point.dx - painter.width / 2,
        point.dy - painter.height / 2,
      ),
    );
  }

  void _drawTargetIcon(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, 5, paint);
    canvas.drawLine(
      Offset(center.dx, center.dy - 10),
      Offset(center.dx, center.dy - 5),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + 5),
      Offset(center.dx, center.dy + 10),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - 10, center.dy),
      Offset(center.dx - 5, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 5, center.dy),
      Offset(center.dx + 10, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PhoneAimPainter oldDelegate) {
    return oldDelegate.targetAzimuth != targetAzimuth ||
        oldDelegate.phoneHeading != phoneHeading ||
        oldDelegate.locked != locked ||
        oldDelegate.scheme != scheme;
  }
}

class _AimMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _AimMetric(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color ?? scheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  final Color color;

  const _MetricDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 58, color: color);
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

double _bearingDelta(double heading, double target) {
  return (target - heading + 540) % 360 - 180;
}
