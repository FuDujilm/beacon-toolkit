import 'package:flutter/material.dart';

class QsoLog {
  final String id;
  final TimeOfDay time;
  final String callsign;
  final String stationCallsign;
  final String country;
  final String band;
  final String mode;
  final String frequency;
  final String report;
  final String rstSent;
  final String rstReceived;
  final String grid;
  final String satName;
  final String propMode;
  final String notes;
  final String qslStatus;
  final String lotwStatus;
  final String cloudlogStatus;
  final String clublogStatus;
  final String qrzStatus;
  final DateTime date;
  final DateTime? clientUpdatedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  QsoLog({
    String? id,
    required this.time,
    required this.callsign,
    this.stationCallsign = '',
    required this.country,
    required this.band,
    required this.mode,
    required this.frequency,
    required this.report,
    String? rstSent,
    String? rstReceived,
    required this.grid,
    this.satName = '',
    this.propMode = '',
    this.notes = '',
    this.qslStatus = 'none',
    this.lotwStatus = 'none',
    this.cloudlogStatus = 'none',
    this.clublogStatus = 'none',
    this.qrzStatus = 'none',
    required this.date,
    DateTime? clientUpdatedAt,
    this.deletedAt,
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        rstSent = rstSent ?? report,
        rstReceived = rstReceived ?? report,
        clientUpdatedAt = clientUpdatedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  DateTime get dateTime {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  QsoLog copyWith({
    String? id,
    TimeOfDay? time,
    String? callsign,
    String? stationCallsign,
    String? country,
    String? band,
    String? mode,
    String? frequency,
    String? report,
    String? rstSent,
    String? rstReceived,
    String? grid,
    String? satName,
    String? propMode,
    String? notes,
    String? qslStatus,
    String? lotwStatus,
    String? cloudlogStatus,
    String? clublogStatus,
    String? qrzStatus,
    DateTime? date,
    DateTime? clientUpdatedAt,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QsoLog(
      id: id ?? this.id,
      time: time ?? this.time,
      callsign: callsign ?? this.callsign,
      stationCallsign: stationCallsign ?? this.stationCallsign,
      country: country ?? this.country,
      band: band ?? this.band,
      mode: mode ?? this.mode,
      frequency: frequency ?? this.frequency,
      report: report ?? this.report,
      rstSent: rstSent ?? this.rstSent,
      rstReceived: rstReceived ?? this.rstReceived,
      grid: grid ?? this.grid,
      satName: satName ?? this.satName,
      propMode: propMode ?? this.propMode,
      notes: notes ?? this.notes,
      qslStatus: qslStatus ?? this.qslStatus,
      lotwStatus: lotwStatus ?? this.lotwStatus,
      cloudlogStatus: cloudlogStatus ?? this.cloudlogStatus,
      clublogStatus: clublogStatus ?? this.clublogStatus,
      qrzStatus: qrzStatus ?? this.qrzStatus,
      date: date ?? this.date,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date_time': dateTime.toIso8601String(),
      'callsign': callsign,
      'station_callsign': stationCallsign,
      'country': country,
      'band': band,
      'mode': mode,
      'frequency': frequency,
      'report': report,
      'rst_sent': rstSent,
      'rst_received': rstReceived,
      'grid': grid,
      'sat_name': satName,
      'prop_mode': propMode,
      'notes': notes,
      'qsl_status': qslStatus,
      'lotw_status': lotwStatus,
      'cloudlog_status': cloudlogStatus,
      'clublog_status': clublogStatus,
      'qrz_status': qrzStatus,
      'client_updated_at': clientUpdatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toApiJson() {
    final json = <String, dynamic>{
      'date_time': dateTime.toUtc().toIso8601String(),
      'callsign': callsign,
      'station_callsign': _nullable(stationCallsign),
      'country': _nullable(country),
      'band': band,
      'mode': mode,
      'frequency': frequency,
      'report': _nullable(report),
      'rst_sent': _nullable(rstSent),
      'rst_received': _nullable(rstReceived),
      'grid': _nullable(grid),
      'sat_name': _nullable(satName),
      'prop_mode': _nullable(propMode),
      'notes': _nullable(notes),
      'client_updated_at':
          (clientUpdatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
    if (_looksLikeUuid(id)) {
      json['id'] = id;
    }
    return json;
  }

  factory QsoLog.fromMap(Map<String, dynamic> map) {
    final dateTime = DateTime.parse(map['date_time'] as String).toLocal();
    return QsoLog(
      id: map['id'] as String?,
      time: TimeOfDay(hour: dateTime.hour, minute: dateTime.minute),
      callsign: map['callsign'] as String? ?? '',
      stationCallsign: map['station_callsign'] as String? ?? '',
      country: map['country'] as String? ?? '',
      band: map['band'] as String? ?? '',
      mode: map['mode'] as String? ?? '',
      frequency: map['frequency'] as String? ?? '',
      report: map['report'] as String? ?? '',
      rstSent: map['rst_sent'] as String? ?? map['report'] as String? ?? '',
      rstReceived:
          map['rst_received'] as String? ?? map['report'] as String? ?? '',
      grid: map['grid'] as String? ?? '',
      satName: map['sat_name'] as String? ?? '',
      propMode: map['prop_mode'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      qslStatus: map['qsl_status'] as String? ?? 'none',
      lotwStatus: map['lotw_status'] as String? ?? 'none',
      cloudlogStatus: map['cloudlog_status'] as String? ?? 'none',
      clublogStatus: map['clublog_status'] as String? ?? 'none',
      qrzStatus: map['qrz_status'] as String? ?? 'none',
      date: DateTime(dateTime.year, dateTime.month, dateTime.day),
      clientUpdatedAt:
          DateTime.tryParse(map['client_updated_at'] as String? ?? ''),
      deletedAt: DateTime.tryParse(map['deleted_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory QsoLog.fromJson(Map<String, dynamic> json) => QsoLog.fromMap(json);

  static String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
