import 'dart:convert';

import '../models/home_tool_entry.dart';
import 'local_database_service.dart';

class HomeToolPreferencesService {
  static const settingKey = 'home_common_tool_ids';
  static const maxHomeTools = 8;

  final LocalDatabaseService _databaseService;

  HomeToolPreferencesService({LocalDatabaseService? databaseService})
      : _databaseService = databaseService ?? LocalDatabaseService();

  Future<List<String>> getSelectedToolIds() async {
    final raw = await _databaseService.getSetting(settingKey);
    if (raw == null || raw.trim().isEmpty) {
      return List<String>.from(defaultHomeToolIds);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return sanitizeToolIds(decoded.whereType<String>().toList());
      }
    } catch (_) {
      // Fall back to defaults when old or damaged settings cannot be parsed.
    }

    return List<String>.from(defaultHomeToolIds);
  }

  Future<void> saveSelectedToolIds(List<String> ids) async {
    final sanitized = sanitizeToolIds(ids);
    await _databaseService.saveSetting(settingKey, jsonEncode(sanitized));
  }

  Future<void> reset() async {
    await _databaseService.deleteSetting(settingKey);
  }

  List<String> sanitizeToolIds(List<String> ids) {
    final availableIds = homeToolEntries.map((tool) => tool.id).toSet();
    final result = <String>[];
    for (final id in ids) {
      if (availableIds.contains(id) &&
          !result.contains(id) &&
          result.length < maxHomeTools) {
        result.add(id);
      }
    }
    if (result.isEmpty) {
      result.addAll(defaultHomeToolIds);
    }
    return result;
  }
}
