import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/app_theme_settings.dart';
import '../models/discovery.dart';
import '../models/frequency_allocation.dart';
import '../models/qso_log.dart';
import '../models/radio_profile.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();

  factory LocalDatabaseService() => _instance;

  LocalDatabaseService._internal();

  Database? _database;
  bool _qsoSchemaChecked = false;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}${Platform.pathSeparator}beacon_local.db';

    _database = await openDatabase(
      path,
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE qso_logs (
            id TEXT PRIMARY KEY,
            date_time TEXT NOT NULL,
            callsign TEXT NOT NULL,
            station_callsign TEXT NOT NULL DEFAULT '',
            country TEXT NOT NULL,
            band TEXT NOT NULL,
            mode TEXT NOT NULL,
            frequency TEXT NOT NULL,
            report TEXT NOT NULL,
            rst_sent TEXT NOT NULL DEFAULT '',
            rst_received TEXT NOT NULL DEFAULT '',
            grid TEXT NOT NULL,
            sat_name TEXT NOT NULL DEFAULT '',
            prop_mode TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            qso_confirm_status TEXT NOT NULL DEFAULT 'none',
            qsl_status TEXT NOT NULL DEFAULT 'none',
            lotw_status TEXT NOT NULL DEFAULT 'none',
            cloudlog_status TEXT NOT NULL DEFAULT 'none',
            clublog_status TEXT NOT NULL DEFAULT 'none',
            qrz_status TEXT NOT NULL DEFAULT 'none',
            client_updated_at TEXT,
            deleted_at TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_qso_logs_date_time ON qso_logs(date_time)',
        );
        await _createAppSettingsTable(db);
        await _createSatelliteTables(db);
        await _createFrequencyAllocationTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createAppSettingsTable(db);
        }
        if (oldVersion < 3) {
          await _createSatelliteTables(db);
        }
        if (oldVersion < 4) {
          await _addColumnIfMissing(
            db,
            'satellite_catalog',
            'image_url',
            'TEXT',
          );
        }
        if (oldVersion < 5) {
          await _addColumnIfMissing(
            db,
            'satellite_status_summaries',
            'report_label',
            'TEXT',
          );
          await _addColumnIfMissing(
            db,
            'satellite_status_summaries',
            'status_level',
            'TEXT',
          );
          await _addColumnIfMissing(
            db,
            'satellite_status_summaries',
            'is_positive',
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 6) {
          await _createFrequencyAllocationTables(db);
        }
        if (oldVersion < 7) {
          await _migrateQsoManagementFields(db);
        }
        if (oldVersion < 8) {
          await _migrateQsoManagementFields(db);
        }
      },
    );

    return _database!;
  }

  Future<void> _createAppSettingsTable(Database db) {
    return db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSatelliteTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS satellite_catalog (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        display_name TEXT,
        norad_cat_id INTEGER,
        satnogs_id TEXT,
        callsign TEXT,
        aliases TEXT NOT NULL DEFAULT '[]',
        status TEXT,
        countries TEXT,
        operator TEXT,
        website TEXT,
        image_url TEXT,
        amsat_name TEXT,
        amsat_display_name TEXT,
        amsat_report_count INTEGER,
        amsat_latest_reported_at TEXT,
        source_updated_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_satellite_catalog_name ON satellite_catalog(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_satellite_catalog_norad ON satellite_catalog(norad_cat_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS satellite_transponders (
        satellite_id TEXT NOT NULL,
        description TEXT NOT NULL,
        type TEXT NOT NULL,
        mode TEXT NOT NULL,
        uplink_low INTEGER,
        downlink_low INTEGER,
        alive INTEGER NOT NULL,
        status TEXT NOT NULL,
        updated_at TEXT,
        PRIMARY KEY (satellite_id, description, mode)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS satellite_status_summaries (
        satellite_id TEXT NOT NULL,
        amsat_name TEXT NOT NULL,
        satellite_display_name TEXT,
        report TEXT NOT NULL,
        report_label TEXT,
        status_level TEXT,
        is_positive INTEGER NOT NULL DEFAULT 0,
        report_count INTEGER NOT NULL,
        latest_reported_at TEXT,
        updated_at TEXT,
        PRIMARY KEY (satellite_id, amsat_name, report)
      )
    ''');
  }

  Future<void> _createFrequencyAllocationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS frequency_allocations (
        region TEXT NOT NULL,
        lower_mhz REAL NOT NULL,
        upper_mhz REAL NOT NULL,
        unit TEXT NOT NULL,
        services TEXT NOT NULL,
        footnotes TEXT NOT NULL,
        source TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        PRIMARY KEY (region, lower_mhz, upper_mhz, sort_order)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_frequency_allocations_range ON frequency_allocations(region, lower_mhz, upper_mhz)',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _migrateQsoManagementFields(Database db) async {
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'station_callsign',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'rst_sent',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'rst_received',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'sat_name',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'prop_mode',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'notes',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'qso_confirm_status',
      "TEXT NOT NULL DEFAULT 'none'",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'qsl_status',
      "TEXT NOT NULL DEFAULT 'none'",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'lotw_status',
      "TEXT NOT NULL DEFAULT 'none'",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'cloudlog_status',
      "TEXT NOT NULL DEFAULT 'none'",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'clublog_status',
      "TEXT NOT NULL DEFAULT 'none'",
    );
    await _addColumnIfMissing(
      db,
      'qso_logs',
      'qrz_status',
      "TEXT NOT NULL DEFAULT 'none'",
    );
    await _addColumnIfMissing(db, 'qso_logs', 'client_updated_at', 'TEXT');
    await _addColumnIfMissing(db, 'qso_logs', 'deleted_at', 'TEXT');
    await _addColumnIfMissing(db, 'qso_logs', 'updated_at', 'TEXT');
    await db.execute('''
      UPDATE qso_logs
      SET rst_sent = CASE WHEN rst_sent = '' THEN report ELSE rst_sent END,
          rst_received = CASE WHEN rst_received = '' THEN report ELSE rst_received END,
          client_updated_at = COALESCE(client_updated_at, created_at)
    ''');
  }

  Future<void> _ensureQsoSchema(Database db) async {
    if (_qsoSchemaChecked) return;
    await _migrateQsoManagementFields(db);
    _qsoSchemaChecked = true;
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
  }

  Future<List<FrequencyAllocation>> getFrequencyAllocations({
    String region = 'CN',
    String? service,
    String? query,
  }) async {
    final db = await database;
    final where = <String>['region = ?'];
    final args = <Object?>[region];
    if (service != null && service.trim().isNotEmpty) {
      where.add('services LIKE ?');
      args.add('%${service.trim()}%');
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add('(services LIKE ? OR footnotes LIKE ?)');
      args.add('%${query.trim()}%');
      args.add('%${query.trim()}%');
    }
    final rows = await db.query(
      'frequency_allocations',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'sort_order ASC',
    );
    return rows.map(_frequencyAllocationFromRow).toList();
  }

  Future<void> replaceFrequencyAllocations(
    List<FrequencyAllocation> allocations,
  ) async {
    final db = await database;
    final region = allocations.isEmpty ? null : allocations.first.region;
    await db.transaction((txn) async {
      if (region == null) {
        await txn.delete('frequency_allocations');
      } else {
        await txn.delete(
          'frequency_allocations',
          where: 'region = ?',
          whereArgs: [region],
        );
      }
      for (final item in allocations) {
        await txn.insert(
          'frequency_allocations',
          item.toLocalMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'app_settings',
        {
          'key': region == null
              ? 'frequency_allocations_synced_at'
              : 'frequency_allocations_synced_at_$region',
          'value': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  FrequencyAllocation _frequencyAllocationFromRow(Map<String, Object?> row) {
    return FrequencyAllocation(
      region: row['region'] as String? ?? 'CN',
      lowerMhz: (row['lower_mhz'] as num?)?.toDouble() ?? 0,
      upperMhz: (row['upper_mhz'] as num?)?.toDouble() ?? 0,
      unit: row['unit'] as String? ?? 'MHz',
      services: (row['services'] as String? ?? '')
          .split('\n')
          .where((item) => item.isNotEmpty)
          .toList(),
      footnotes: (row['footnotes'] as String? ?? '')
          .split('\n')
          .where((item) => item.isNotEmpty)
          .toList(),
      source: row['source'] as String? ?? '',
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }

  Future<List<SatelliteCatalogItem>> getCachedSatelliteCatalog({
    String? query,
    int offset = 0,
    int limit = 200,
  }) async {
    final db = await database;
    final normalized = query?.trim();
    final rows = await db.query(
      'satellite_catalog',
      where: normalized == null || normalized.isEmpty
          ? null
          : 'name LIKE ? OR display_name LIKE ? OR callsign LIKE ? OR CAST(norad_cat_id AS TEXT) LIKE ?',
      whereArgs: normalized == null || normalized.isEmpty
          ? null
          : List.filled(4, '%$normalized%'),
      orderBy: "CASE WHEN status = 'alive' THEN 0 ELSE 1 END, name ASC",
      limit: limit,
      offset: offset,
    );
    return rows.map(_satelliteCatalogFromRow).toList();
  }

  Future<SatelliteCatalogItem?> getCachedSatelliteById(String id) async {
    final db = await database;
    final rows = await db.query(
      'satellite_catalog',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _satelliteCatalogFromRow(rows.first);
  }

  Future<SatelliteCatalogItem?> getCachedSatelliteByNameOrNorad({
    required String name,
    int? noradCatId,
  }) async {
    final db = await database;
    var rows = await db.query(
      'satellite_catalog',
      where:
          '(? IS NOT NULL AND norad_cat_id = ?) OR name LIKE ? OR display_name LIKE ?',
      whereArgs: [noradCatId, noradCatId, '%$name%', '%$name%'],
      limit: 1,
    );
    if (rows.isEmpty) {
      final normalized = name
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'[_\-\[\]/()]'), ' ')
          .trim();
      if (normalized.isNotEmpty && normalized != name) {
        rows = await db.query(
          'satellite_catalog',
          where: 'name LIKE ? OR display_name LIKE ? OR aliases LIKE ?',
          whereArgs: [
            '%$normalized%',
            '%$normalized%',
            '%$normalized%',
          ],
          limit: 1,
        );
      }
    }
    return rows.isEmpty ? null : _satelliteCatalogFromRow(rows.first);
  }

  Future<void> cacheSatelliteCatalog(List<SatelliteCatalogItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in items) {
        final id = item.id;
        if (id == null || id.isEmpty) continue;
        await txn.insert(
          'satellite_catalog',
          {
            'id': id,
            'name': item.name,
            'display_name': item.displayName,
            'norad_cat_id': item.noradCatId,
            'satnogs_id': item.satnogsId,
            'callsign': item.callsign,
            'aliases': item.aliases.join('\n'),
            'status': item.status,
            'countries': item.countries,
            'operator': item.operatorName,
            'website': item.website,
            'image_url': item.imageUrl,
            'amsat_name': item.amsatName,
            'amsat_display_name': item.amsatDisplayName,
            'amsat_report_count': item.amsatReportCount,
            'amsat_latest_reported_at':
                item.amsatLatestReportedAt?.toIso8601String(),
            'source_updated_at': item.sourceUpdatedAt?.toIso8601String(),
            'updated_at': item.updatedAt?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> cacheSatelliteDetail({
    required String satelliteId,
    required List<SatelliteTransponder> transponders,
    required List<SatelliteStatusSummary> statusSummaries,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'satellite_transponders',
        where: 'satellite_id = ?',
        whereArgs: [satelliteId],
      );
      for (final item in transponders) {
        await txn.insert(
          'satellite_transponders',
          {
            'satellite_id': satelliteId,
            'description': item.description,
            'type': item.type,
            'mode': item.mode,
            'uplink_low': item.uplinkLow,
            'downlink_low': item.downlinkLow,
            'alive': item.alive ? 1 : 0,
            'status': item.status,
            'updated_at': item.updatedAt?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.delete(
        'satellite_status_summaries',
        where: 'satellite_id = ?',
        whereArgs: [satelliteId],
      );
      for (final item in statusSummaries) {
        await txn.insert(
          'satellite_status_summaries',
          item.toLocalMap(satelliteId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<SatelliteTransponder>> getCachedSatelliteTransponders(
    String satelliteId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'satellite_transponders',
      where: 'satellite_id = ?',
      whereArgs: [satelliteId],
    );
    return rows
        .map((row) => SatelliteTransponder(
              description: row['description'] as String? ?? '卫星频率',
              type: row['type'] as String? ?? 'beacon-api',
              mode: row['mode'] as String? ?? '',
              uplinkLow: row['uplink_low'] as int?,
              downlinkLow: row['downlink_low'] as int?,
              alive: row['alive'] == 1,
              status: row['status'] as String? ?? 'unknown',
              updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
            ))
        .toList();
  }

  Future<List<SatelliteStatusSummary>> getCachedSatelliteStatusSummaries(
    String satelliteId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'satellite_status_summaries',
      where: 'satellite_id = ?',
      whereArgs: [satelliteId],
    );
    return rows
        .map((row) => SatelliteStatusSummary(
              amsatName: row['amsat_name'] as String? ?? '',
              satelliteDisplayName: row['satellite_display_name'] as String?,
              report: row['report'] as String? ?? 'unknown',
              reportLabel: row['report_label'] as String? ?? '',
              statusLevel: row['status_level'] as String? ?? 'unknown',
              isPositive: row['is_positive'] == 1,
              reportCount: row['report_count'] as int? ?? 0,
              latestReportedAt:
                  DateTime.tryParse(row['latest_reported_at'] as String? ?? ''),
              updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
            ))
        .toList();
  }

  SatelliteCatalogItem _satelliteCatalogFromRow(Map<String, Object?> row) {
    return SatelliteCatalogItem(
      id: row['id'] as String?,
      name: row['name'] as String? ?? '',
      displayName: row['display_name'] as String?,
      noradCatId: row['norad_cat_id'] as int?,
      satnogsId: row['satnogs_id'] as String?,
      callsign: row['callsign'] as String?,
      aliases: (row['aliases'] as String? ?? '')
          .split('\n')
          .where((item) => item.isNotEmpty)
          .toList(),
      status: row['status'] as String?,
      countries: row['countries'] as String?,
      operatorName: row['operator'] as String?,
      website: row['website'] as String?,
      imageUrl: row['image_url'] as String?,
      amsatName: row['amsat_name'] as String?,
      amsatDisplayName: row['amsat_display_name'] as String?,
      amsatReportCount: row['amsat_report_count'] as int?,
      amsatLatestReportedAt:
          DateTime.tryParse(row['amsat_latest_reported_at'] as String? ?? ''),
      sourceUpdatedAt:
          DateTime.tryParse(row['source_updated_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      tleSource: 'beacon-api cache',
    );
  }

  Future<List<QsoLog>> getQsoLogs() async {
    final db = await database;
    await _ensureQsoSchema(db);
    final rows = await db.query('qso_logs', orderBy: 'date_time DESC');
    return rows.map(QsoLog.fromMap).toList();
  }

  Future<void> insertQsoLog(QsoLog log) async {
    final db = await database;
    await _ensureQsoSchema(db);
    await db.insert(
      'qso_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteQsoLog(String id) async {
    final db = await database;
    await db.delete('qso_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceQsoLogs(List<QsoLog> logs) async {
    final db = await database;
    await _ensureQsoSchema(db);
    await db.transaction((txn) async {
      await txn.delete('qso_logs');
      for (final log in logs) {
        await txn.insert(
          'qso_logs',
          log.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<Map<String, dynamic>> exportData() async {
    final qsoLogs = await getQsoLogs();
    final theme = await getThemeSettings();
    final radioProfile = await getRadioProfile();
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'theme': {
        'mode': theme.modeKey,
        'colorSchemeKey': theme.colorSchemeKey,
        'customSeedColor': theme.customSeedColor,
      },
      'radioProfile': radioProfile.toJson(),
      'qsoLogs': qsoLogs.map((log) => log.toJson()).toList(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final rawLogs = data['qsoLogs'];
    if (rawLogs is! List) {
      throw const FormatException('导入文件缺少 qsoLogs 数据');
    }

    final logs = rawLogs
        .map((item) => QsoLog.fromJson(item as Map<String, dynamic>))
        .toList();
    await replaceQsoLogs(logs);

    final theme = data['theme'];
    if (theme is Map<String, dynamic>) {
      await saveThemeSettings(
        AppThemeSettings(
          mode: AppThemeSettings.modeFromKey(theme['mode'] as String?),
          colorSchemeKey: theme['colorSchemeKey'] as String? ?? 'beacon',
          customSeedColor: theme['customSeedColor'] as int?,
        ),
      );
    }

    final radioProfile = data['radioProfile'];
    if (radioProfile is Map<String, dynamic>) {
      await saveRadioProfile(RadioProfile.fromJson(radioProfile));
    }
  }

  Future<RadioProfile> getRadioProfile() async {
    final db = await database;
    final rows = await db.query('app_settings');
    final map = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };

    return RadioProfile(
      callsign: map['radio_callsign'] ?? RadioProfile.defaults.callsign,
      qth: map['radio_qth'] ?? RadioProfile.defaults.qth,
      grid: map['radio_grid'] ?? RadioProfile.defaults.grid,
      latitude: double.tryParse(map['radio_latitude'] ?? ''),
      longitude: double.tryParse(map['radio_longitude'] ?? ''),
      altitudeMeters: double.tryParse(map['radio_altitude_meters'] ?? '') ?? 0,
      licenseClass:
          map['radio_license_class'] ?? RadioProfile.defaults.licenseClass,
      licenseExpiry:
          map['radio_license_expiry'] ?? RadioProfile.defaults.licenseExpiry,
    );
  }

  Future<void> saveRadioProfile(RadioProfile profile) async {
    final db = await database;
    await db.transaction((txn) async {
      final entries = {
        'radio_callsign': profile.callsign,
        'radio_qth': profile.qth,
        'radio_grid': profile.grid,
        'radio_latitude': profile.latitude?.toString() ?? '',
        'radio_longitude': profile.longitude?.toString() ?? '',
        'radio_altitude_meters': profile.altitudeMeters.toString(),
        'radio_license_class': profile.licenseClass,
        'radio_license_expiry': profile.licenseExpiry,
      };

      for (final entry in entries.entries) {
        await txn.insert(
          'app_settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<AppThemeSettings> getThemeSettings() async {
    final db = await database;
    final rows = await db.query('app_settings');
    final map = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };

    return AppThemeSettings(
      mode: AppThemeSettings.modeFromKey(map['theme_mode']),
      colorSchemeKey: map['theme_color_scheme'] ?? 'beacon',
      customSeedColor: int.tryParse(map['theme_custom_seed_color'] ?? ''),
    );
  }

  Future<void> saveThemeSettings(AppThemeSettings settings) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'app_settings',
        {'key': 'theme_mode', 'value': settings.modeKey},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': 'theme_color_scheme', 'value': settings.colorSchemeKey},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (settings.customSeedColor == null) {
        await txn.delete(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['theme_custom_seed_color'],
        );
      } else {
        await txn.insert(
          'app_settings',
          {
            'key': 'theme_custom_seed_color',
            'value': settings.customSeedColor.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
