import 'dart:convert';

import 'local_database_service.dart';

class QsoQuickTemplate {
  final String id;
  final String name;
  final String uplinkFrequency;
  final String downlinkFrequency;
  final String mode;
  final String band;
  final String satName;
  final String propMode;

  const QsoQuickTemplate({
    required this.id,
    required this.name,
    required this.uplinkFrequency,
    required this.downlinkFrequency,
    required this.mode,
    required this.band,
    this.satName = '',
    this.propMode = '',
  });

  factory QsoQuickTemplate.so50() {
    return const QsoQuickTemplate(
      id: 'default_so50_fm',
      name: 'SO-50 FM',
      uplinkFrequency: '145.850 MHz',
      downlinkFrequency: '439.795 MHz',
      mode: 'FM',
      band: '70cm',
      satName: 'SO-50',
      propMode: 'SAT',
    );
  }

  factory QsoQuickTemplate.fromJson(Map<String, dynamic> json) {
    return QsoQuickTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      uplinkFrequency: json['uplink_frequency']?.toString() ??
          json['uplinkFrequency']?.toString() ??
          '',
      downlinkFrequency: json['downlink_frequency']?.toString() ??
          json['downlinkFrequency']?.toString() ??
          '',
      mode: json['mode']?.toString() ?? '',
      band: _normalizeBand(
        json['band']?.toString() ?? '',
        json['downlink_frequency']?.toString() ??
            json['downlinkFrequency']?.toString() ??
            '',
      ),
      satName:
          json['sat_name']?.toString() ?? json['satName']?.toString() ?? '',
      propMode:
          json['prop_mode']?.toString() ?? json['propMode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'uplink_frequency': uplinkFrequency,
      'downlink_frequency': downlinkFrequency,
      'mode': mode,
      'band': band,
      'sat_name': satName,
      'prop_mode': propMode,
    };
  }

  QsoQuickTemplate copyWith({
    String? id,
    String? name,
    String? uplinkFrequency,
    String? downlinkFrequency,
    String? mode,
    String? band,
    String? satName,
    String? propMode,
  }) {
    return QsoQuickTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      uplinkFrequency: uplinkFrequency ?? this.uplinkFrequency,
      downlinkFrequency: downlinkFrequency ?? this.downlinkFrequency,
      mode: mode ?? this.mode,
      band: band ?? this.band,
      satName: satName ?? this.satName,
      propMode: propMode ?? this.propMode,
    );
  }

  bool get isUsable {
    return id.trim().isNotEmpty &&
        name.trim().isNotEmpty &&
        mode.trim().isNotEmpty &&
        band.trim().isNotEmpty &&
        downlinkFrequency.trim().isNotEmpty;
  }
}

class QsoQuickTemplateService {
  static const settingKey = 'qso_quick_record_templates';

  final LocalDatabaseService _databaseService;

  QsoQuickTemplateService({LocalDatabaseService? databaseService})
      : _databaseService = databaseService ?? LocalDatabaseService();

  Future<List<QsoQuickTemplate>> getTemplates() async {
    final raw = await _databaseService.getSetting(settingKey);
    if (raw == null || raw.trim().isEmpty) {
      return defaultTemplates();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final templates = decoded
            .whereType<Map>()
            .map((item) => QsoQuickTemplate.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where((template) => template.isUsable)
            .toList();
        return templates;
      }
    } catch (_) {
      // Damaged settings fall back to the built-in satellite template.
    }

    return defaultTemplates();
  }

  Future<void> saveTemplates(List<QsoQuickTemplate> templates) async {
    final sanitized = sanitizeTemplates(templates);
    await _databaseService.saveSetting(
      settingKey,
      jsonEncode(sanitized.map((template) => template.toJson()).toList()),
    );
  }

  List<QsoQuickTemplate> defaultTemplates() {
    return [QsoQuickTemplate.so50()];
  }

  List<QsoQuickTemplate> sanitizeTemplates(List<QsoQuickTemplate> templates) {
    final result = <QsoQuickTemplate>[];
    final ids = <String>{};
    for (final template in templates) {
      final normalized = template.copyWith(
        id: template.id.trim().isEmpty
            ? DateTime.now().microsecondsSinceEpoch.toString()
            : template.id.trim(),
        name: template.name.trim(),
        uplinkFrequency: _normalizeFrequency(template.uplinkFrequency),
        downlinkFrequency: _normalizeFrequency(template.downlinkFrequency),
        mode: template.mode.trim().toUpperCase(),
        band: _normalizeBand(template.band, template.downlinkFrequency),
        satName: template.satName.trim().toUpperCase(),
        propMode: template.propMode.trim().toUpperCase(),
      );
      if (!normalized.isUsable || ids.contains(normalized.id)) continue;
      ids.add(normalized.id);
      result.add(normalized);
    }
    return result;
  }

  String _normalizeFrequency(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final compact = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    if (RegExp(r'(hz|khz|mhz|ghz)$', caseSensitive: false).hasMatch(compact)) {
      return compact.replaceAllMapped(
        RegExp(r'(hz|khz|mhz|ghz)$', caseSensitive: false),
        (match) => match.group(1)!.toUpperCase(),
      );
    }
    return '$compact MHz';
  }
}

String _normalizeBand(String value, String downlinkFrequency) {
  final trimmed = value.trim();
  if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'sat') {
    return trimmed;
  }
  return _bandFromFrequency(downlinkFrequency) ?? '';
}

String? _bandFromFrequency(String value) {
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(value);
  if (match == null) return null;
  final number = double.tryParse(match.group(1)!);
  if (number == null) return null;

  final lower = value.toLowerCase();
  final mhz = lower.contains('ghz')
      ? number * 1000
      : lower.contains('khz')
          ? number / 1000
          : lower.contains('hz') && !lower.contains('mhz')
              ? number / 1000000
              : number;

  if (mhz >= 1.8 && mhz < 2.0) return '160m';
  if (mhz >= 3.5 && mhz < 4.0) return '80m';
  if (mhz >= 7.0 && mhz < 7.3) return '40m';
  if (mhz >= 10.1 && mhz < 10.15) return '30m';
  if (mhz >= 14.0 && mhz < 14.35) return '20m';
  if (mhz >= 18.068 && mhz < 18.168) return '17m';
  if (mhz >= 21.0 && mhz < 21.45) return '15m';
  if (mhz >= 24.89 && mhz < 24.99) return '12m';
  if (mhz >= 28.0 && mhz < 29.7) return '10m';
  if (mhz >= 50.0 && mhz < 54.0) return '6m';
  if (mhz >= 144.0 && mhz < 148.0) return '2m';
  if (mhz >= 220.0 && mhz < 225.0) return '1.25m';
  if (mhz >= 420.0 && mhz < 450.0) return '70cm';
  if (mhz >= 902.0 && mhz < 928.0) return '33cm';
  if (mhz >= 1240.0 && mhz < 1300.0) return '23cm';
  return null;
}
