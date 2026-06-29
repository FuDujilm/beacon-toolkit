import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/exam_result.dart';
import '../../models/practice_history.dart';
import '../../models/qso_log.dart';
import '../../services/exam_service.dart';
import '../../services/local_database_service.dart';
import '../../services/question_service.dart';
import '../../services/qso_management_service.dart';
import '../../services/user_settings_service.dart';

const _qsoColor = Color(0xff20d174);
const _studyColor = Color(0xff3889ff);
const _mixedColor = Color(0xffffb547);
const _qsoWarningColor = Color(0xffe84d4f);

class RadioLogPage extends StatefulWidget {
  const RadioLogPage({super.key});

  @override
  State<RadioLogPage> createState() => _RadioLogPageState();
}

class _RadioLogPageState extends State<RadioLogPage> {
  final _settingsService = UserSettingsService();
  final _questionService = QuestionService();
  final _examService = ExamService();
  final _databaseService = LocalDatabaseService();
  final _qsoManagementService = QsoManagementService();

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  int _selectedTab = 0;
  bool _isLoading = true;
  bool _studySyncWarning = false;
  Map<String, dynamic> _studyCalendar = {};
  List<PracticeSession> _practiceSessions = [];
  List<ExamResult> _examResults = [];
  List<QsoLog> _qsoLogs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _studySyncWarning = false;
    });
    final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final monthEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);

    var studySyncWarning = false;
    var studyMap = <String, dynamic>{};
    var practiceSessions = <PracticeSession>[];
    var examResults = <ExamResult>[];
    var qsoLogs = <QsoLog>[];

    try {
      qsoLogs = await _databaseService.getQsoLogs();
    } catch (error) {
      debugPrint('Failed to load local QSO logs: ${_friendlyLoadError(error)}');
    }

    try {
      final records = await _settingsService.getStudyCalendar(
        _dateKey(monthStart),
        _dateKey(monthEnd),
      );
      for (final record in records) {
        final date = record['date'];
        if (date != null) {
          studyMap[date.toString().split('T').first] = record;
        }
      }
    } catch (error) {
      studySyncWarning = true;
      debugPrint('Failed to sync study calendar: ${_friendlyLoadError(error)}');
    }

    try {
      practiceSessions = await _questionService.getPracticeSessions(limit: 60);
    } catch (error) {
      studySyncWarning = true;
      debugPrint(
          'Failed to sync practice history: ${_friendlyLoadError(error)}');
    }

    try {
      examResults = await _examService.getExamHistory();
    } catch (error) {
      studySyncWarning = true;
      debugPrint('Failed to sync exam history: ${_friendlyLoadError(error)}');
    }

    if (!mounted) return;
    setState(() {
      _studyCalendar = studyMap;
      _practiceSessions = practiceSessions;
      _examResults = examResults;
      _qsoLogs = qsoLogs;
      _studySyncWarning = studySyncWarning;
      _isLoading = false;
    });
  }

  String _friendlyLoadError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) return 'API $statusCode';
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'API 超时';
      }
      if (error.type == DioExceptionType.connectionError) return 'API 不可用';
    }
    final message = error.toString();
    final statusMatch = RegExp(r'status code of (\d{3})').firstMatch(message) ??
        RegExp(r'\bHTTP[ /](\d{3})\b', caseSensitive: false)
            .firstMatch(message) ??
        RegExp(r'\bAPI[ :](\d{3})\b', caseSensitive: false).firstMatch(message);
    if (statusMatch != null) return 'API ${statusMatch.group(1)}';
    if (message.contains('TimeoutException') ||
        message.toLowerCase().contains('timeout')) {
      return 'API 超时';
    }
    if (message.contains('SocketException') ||
        message.contains('Connection refused') ||
        message.contains('Failed host lookup') ||
        message.contains('Network is unreachable')) {
      return 'API 不可用';
    }
    final cleanMessage = message
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .replaceAll('\n', ' ');
    return cleanMessage.length > 40
        ? '${cleanMessage.substring(0, 40)}...'
        : cleanMessage;
  }

  Future<void> _openAddQsoSheet() async {
    final log = await showModalBottomSheet<QsoLog>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddQsoSheet(initialDate: _selectedDate),
    );

    if (log == null) return;
    await _databaseService.insertQsoLog(log);
    if (!mounted) return;
    setState(() {
      _qsoLogs = [log, ..._qsoLogs]
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      _selectedDate = log.date;
      _focusedMonth = DateTime(log.date.year, log.date.month);
      _selectedTab = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存 ${log.callsign} 的通联记录')),
    );
  }

  Future<void> _openEditQsoSheet(QsoLog existing) async {
    final updated = await showModalBottomSheet<QsoLog>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddQsoSheet(
        initialDate: existing.date,
        initialLog: existing,
      ),
    );

    if (updated == null) return;
    await _databaseService.insertQsoLog(updated);
    if (!mounted) return;
    setState(() {
      _qsoLogs = [
        for (final log in _qsoLogs)
          if (log.id == updated.id) updated else log,
      ]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      _selectedDate = updated.date;
      _focusedMonth = DateTime(updated.date.year, updated.date.month);
      _selectedTab = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已更新 ${updated.callsign} 的通联记录')),
    );
  }

  Future<void> _syncQsoLogs() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('正在同步通联日志...')));
    String? errorDateSummary;
    try {
      final localLogs = await _databaseService.getQsoLogs();
      final syncableLogs = localLogs.where(_isSyncableQsoLog).toList();
      final skippedIncomplete = localLogs.length - syncableLogs.length;
      errorDateSummary = _incompleteQsoDateSummary(localLogs);
      if (syncableLogs.isEmpty) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              errorDateSummary == null
                  ? '没有可同步的完整通联，请先补全呼号、频段、模式和频率'
                  : '$errorDateSummary 存在错误数据，请补全后再同步',
            ),
          ),
        );
        return;
      }
      final summary = await _qsoManagementService.syncLogs(syncableLogs);
      var cloudLogs = <QsoLog>[];
      try {
        cloudLogs = await _qsoManagementService.fetchCloudLogs();
      } catch (_) {
        cloudLogs = summary.items;
      }
      if (cloudLogs.isNotEmpty) {
        await _databaseService.replaceQsoLogs(cloudLogs);
      }
      await _loadLogs();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '同步完成：新增 ${summary.inserted}，更新 ${summary.updated}，'
            '跳过 ${summary.skipped + skippedIncomplete}'
            '${errorDateSummary == null ? '' : '；$errorDateSummary 存在错误数据未上传'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '同步失败：${_friendlySyncError(
              error,
              invalidDateSummary: errorDateSummary,
            )}',
          ),
        ),
      );
    }
  }

  bool _isSyncableQsoLog(QsoLog log) {
    return _qsoMissingRequiredFields(log).isEmpty;
  }

  String _friendlySyncError(Object error, {String? invalidDateSummary}) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 400 || statusCode == 422) {
        return invalidDateSummary == null
            ? '同步数据格式不兼容，请重试或重新保存该通联'
            : '$invalidDateSummary 存在错误数据，请补全后重试';
      }
      if (statusCode == 401 || statusCode == 403) {
        return '登录状态不可用，请重新登录后再试';
      }
    }
    return _friendlyLoadError(error);
  }

  String? _incompleteQsoDateSummary(List<QsoLog> logs) {
    final dates = logs
        .where((log) => !_isSyncableQsoLog(log))
        .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
        .toSet()
        .toList()
      ..sort();
    if (dates.isEmpty) return null;
    final shown = dates.take(3).map(_formatShortDate).join('、');
    final remaining = dates.length - 3;
    return remaining > 0 ? '$shown 等 $remaining 天' : shown;
  }

  Future<void> _importAdif() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final imported = await _qsoManagementService.importAdifFromFile();
      if (imported.isEmpty) return;
      final cloudLogs = await _qsoManagementService.fetchCloudLogs();
      await _databaseService.replaceQsoLogs(
        cloudLogs.isEmpty ? imported : cloudLogs,
      );
      await _loadLogs();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('已导入 ${imported.length} 条 ADIF 通联')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('ADIF 导入失败：${_friendlyLoadError(error)}')),
      );
    }
  }

  Future<void> _exportAdif() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await _qsoManagementService.exportAdifToDownloads();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('ADIF 已导出：$path')));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('ADIF 导出失败：${_friendlyLoadError(error)}')),
      );
    }
  }

  Future<void> _openQuickQsoDialog() async {
    final controller = TextEditingController(text: '20260721 so50 qso ba4qbq');
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('快速记录'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '通联描述',
            hintText: '例如 20260721 so50 qso ba4qbq',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('解析并保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;

    try {
      final parsed = await _qsoManagementService.quickParse(text);
      final date = parsed.date == null
          ? _selectedDate
          : DateTime.tryParse(parsed.date!) ?? _selectedDate;
      final now = TimeOfDay.now();
      final log = QsoLog(
        time: now,
        callsign: parsed.callsign ?? '',
        country: '',
        band: parsed.propMode == 'SAT' ? 'sat' : '20m',
        mode: parsed.propMode == 'SAT' ? 'FM' : 'FT8',
        frequency: '',
        report: '',
        grid: '',
        satName: parsed.satName ?? '',
        propMode: parsed.propMode ?? '',
        notes: text.trim(),
        date: DateTime(date.year, date.month, date.day),
      );
      if (log.callsign.isEmpty) {
        throw Exception('未识别到呼号');
      }
      await _databaseService.insertQsoLog(log);
      await _loadLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存快速通联：${log.callsign}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('快速解析失败：${_friendlyLoadError(error)}')),
      );
    }
  }

  Future<void> _openDynamicQslDialog() async {
    var verifierRequired = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('动态 QSL 收妥链接'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('需要验证码'),
                value: verifierRequired,
                onChanged: (value) =>
                    setDialogState(() => verifierRequired = value),
              ),
              const SizedBox(height: 8),
              Text(
                verifierRequired
                    ? '动态链接会保持固定，验证码由系统生成并短时有效。'
                    : '动态链接会展示当前用户待收妥的通联摘要，适合打印固定二维码。',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(verifierRequired),
              child: const Text('生成'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;

    try {
      final link = await _qsoManagementService.upsertDynamicQslLink(
        verifierRequired: result,
      );
      if (!mounted) return;
      _showQslLinkDialog('动态 QSL 链接', link);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：${_friendlyLoadError(error)}')),
      );
    }
  }

  Future<void> _openQsoActions(QsoLog log) async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑通联'),
              subtitle: const Text('修改呼号、日期、频率、模式和信号报告'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('生成静态 QSL 收妥二维码'),
              subtitle: const Text('每条通联一个独立链接'),
              onTap: () => Navigator.of(context).pop('static_qsl'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制通联摘要'),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text('删除通联', style: TextStyle(color: scheme.error)),
              subtitle: const Text('从本地删除，并尝试同步删除远端记录'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'copy') {
      final text =
          '${_formatDate(log.date)} ${_formatTime(log.time)} ${log.callsign} ${log.band} ${log.mode} ${log.frequency}';
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制通联摘要')),
      );
    }
    if (action == 'edit') {
      await _openEditQsoSheet(log);
    }
    if (action == 'static_qsl') {
      await _createStaticQslLink(log);
    }
    if (action == 'delete') {
      await _deleteQsoLog(log);
    }
  }

  Future<void> _deleteQsoLog(QsoLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除通联'),
        content: Text(
          '确定删除 ${log.callsign.isEmpty ? '这条' : log.callsign} 通联记录吗？此操作会先删除本地记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    var remoteDeleted = false;
    var remoteSkipped = false;
    Object? remoteError;
    if (_looksLikeUuid(log.id)) {
      try {
        await _qsoManagementService.deleteCloudLog(log.id);
        remoteDeleted = true;
      } catch (error) {
        remoteError = error;
      }
    } else {
      remoteSkipped = true;
    }

    await _databaseService.deleteQsoLog(log.id);
    if (!mounted) return;
    setState(() {
      _qsoLogs = _qsoLogs.where((item) => item.id != log.id).toList();
    });

    final message = remoteDeleted
        ? '已删除本地和远端通联'
        : remoteSkipped
            ? '已删除本地通联'
            : '已删除本地通联，远端删除失败：${_friendlyLoadError(remoteError!)}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  Future<void> _createStaticQslLink(QsoLog log) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cloudLog = await _ensureCloudQsoForQsl(log);
      final link = await _qsoManagementService.createStaticQslLink(cloudLog.id);
      final qslStatus = link.qslStatus?.trim();
      if (qslStatus != null && qslStatus.isNotEmpty) {
        final updatedLog = cloudLog.copyWith(
          qslStatus: qslStatus,
          updatedAt: DateTime.now(),
        );
        await _databaseService.insertQsoLog(updatedLog);
        if (mounted) {
          setState(() {
            _qsoLogs = [
              for (final item in _qsoLogs)
                if (item.id == updatedLog.id) updatedLog else item,
            ]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          });
        }
      }
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      _showQslLinkDialog('${cloudLog.callsign} QSL 链接', link);
    } catch (error) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('生成失败：${_friendlyQslError(error)}')),
      );
    }
  }

  Future<QsoLog> _ensureCloudQsoForQsl(QsoLog log) async {
    if (_looksLikeUuid(log.id)) return log;

    final missingFields = _qsoMissingRequiredFields(log);
    if (missingFields.isNotEmpty) {
      throw Exception(
        '${_formatShortDate(log.date)} 存在错误数据，请先补全 ${missingFields.join('、')}',
      );
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('正在同步当前通联以生成二维码...')),
    );

    final summary = await _qsoManagementService.syncLogs([log]);
    final cloudLog = summary.items.isNotEmpty ? summary.items.first : null;
    if (cloudLog == null || !_looksLikeUuid(cloudLog.id)) {
      throw Exception('未获取到云端通联编号');
    }

    try {
      final cloudLogs = await _qsoManagementService.fetchCloudLogs();
      if (cloudLogs.isNotEmpty) {
        await _databaseService.replaceQsoLogs(cloudLogs);
        if (mounted) {
          setState(() {
            _qsoLogs = cloudLogs
              ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          });
        }
      }
    } catch (_) {
      await _databaseService.deleteQsoLog(log.id);
      await _databaseService.insertQsoLog(cloudLog);
      if (mounted) {
        setState(() {
          _qsoLogs = [
            for (final item in _qsoLogs)
              if (item.id == log.id) cloudLog else item,
          ]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        });
      }
    }

    return cloudLog;
  }

  String _friendlyQslError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 400 || statusCode == 422) {
        return '通联还未同步到云端，请补全后重试';
      }
      if (statusCode == 401 || statusCode == 403) {
        return '登录状态不可用，请重新登录后再试';
      }
      if (statusCode == 404) {
        return '云端通联不存在，请先同步后再试';
      }
    }
    return _friendlyLoadError(error);
  }

  void _showQslLinkDialog(String title, QslLink link) {
    final value = link.url.isEmpty ? link.token : link.url;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (link.url.isNotEmpty)
                    Center(
                      child: QrImageView(
                        data: link.url,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _copyText(
                      messenger,
                      value,
                      closeDialog: false,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(
                        value,
                        softWrap: true,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  if (link.verifierRequired && link.verifierCode != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      '动态验证码',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      link.verifierCode!,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    if (link.verifierExpiresAt != null)
                      Text(
                        '${_timeFromDate(link.verifierExpiresAt!.toLocal())} 前有效',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _copyText(
                          messenger,
                          value,
                          navigator: navigator,
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('复制链接'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyText(
    ScaffoldMessengerState messenger,
    String value, {
    NavigatorState? navigator,
    bool closeDialog = true,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    if (closeDialog && navigator != null) {
      navigator.pop();
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已复制 QSL 链接')));
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + offset, 1);
      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final qsoCount = _qsoLogs.length;
    final studyCount = _practiceSessions.length + _examResults.length;

    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 2, bottom: 12),
        child: FloatingActionButton.extended(
          onPressed: _openAddQsoSheet,
          icon: const Icon(Icons.add),
          label: const Text('添加通联'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final horizontalPadding = isWide ? 24.0 : 18.0;
            final topPadding = isWide ? 32.0 : 42.0;
            final maxContentWidth = isWide ? 1180.0 : constraints.maxWidth;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                138,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: _buildResponsiveContent(
                      qsoCount: qsoCount,
                      studyCount: studyCount,
                      isWide: isWide,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResponsiveContent({
    required int qsoCount,
    required int studyCount,
    required bool isWide,
  }) {
    final hero = _HeroHeader(
      qsoCount: qsoCount,
      studyCount: studyCount,
      onSync: _syncQsoLogs,
      onQuickQso: _openQuickQsoDialog,
      onImportAdif: _importAdif,
      onExportAdif: _exportAdif,
      onDynamicQsl: _openDynamicQslDialog,
    );
    final calendar = _CalendarPanel(
      focusedMonth: _focusedMonth,
      selectedDate: _selectedDate,
      studyCalendar: _studyCalendar,
      qsoLogs: _qsoLogs,
      hasSyncWarning: _studySyncWarning,
      onMonthChanged: _changeMonth,
      onDateSelected: (date) => setState(() => _selectedDate = date),
    );
    final tabs = _SegmentedTabs(
      selectedIndex: _selectedTab,
      onChanged: (index) => setState(() => _selectedTab = index),
    );
    final recordWidgets = _isLoading
        ? <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 56),
              child: Center(child: CircularProgressIndicator()),
            ),
          ]
        : _buildSelectedTab();

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hero,
          const SizedBox(height: 12),
          calendar,
          const SizedBox(height: 12),
          tabs,
          const SizedBox(height: 12),
          ...recordWidgets,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: calendar),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tabs,
                  const SizedBox(height: 12),
                  ...recordWidgets,
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildSelectedTab() {
    final selectedLogs = _qsoLogs
        .where((log) => DateUtils.isSameDay(log.date, _selectedDate))
        .toList();
    final selectedSessions = _selectedPracticeSessions();
    final selectedExams = _selectedExamResults();

    return switch (_selectedTab) {
      0 => _buildQsoSection(selectedLogs),
      1 => _buildStudySection(selectedSessions, selectedExams),
      _ => _buildAllSection(selectedLogs, selectedSessions, selectedExams),
    };
  }

  List<PracticeSession> _selectedPracticeSessions() {
    return _practiceSessions
        .where((session) => DateUtils.isSameDay(
              session.lastAnsweredAt.toLocal(),
              _selectedDate,
            ))
        .toList();
  }

  List<ExamResult> _selectedExamResults() {
    return _examResults
        .where((exam) => DateUtils.isSameDay(
              exam.createdAt.toLocal(),
              _selectedDate,
            ))
        .toList();
  }

  List<Widget> _buildQsoSection(List<QsoLog> selectedLogs) {
    return [
      _DayHeader(
        date: _selectedDate,
        trailing: '${selectedLogs.length} 条通联',
      ),
      const SizedBox(height: 10),
      if (selectedLogs.isEmpty)
        const _EmptyStateCard(
          icon: Icons.radio,
          title: '当天暂无通联',
          subtitle: '点击右下角 + 添加通联记录呼号、频率、模式和信号报告。',
        )
      else
        ...selectedLogs.map(
          (log) => _QsoLogCard(
            log: log,
            onTap: () => _openQsoActions(log),
            onLongPress: () => _createStaticQslLink(log),
          ),
        ),
    ];
  }

  List<Widget> _buildStudySection(
    List<PracticeSession> selectedSessions,
    List<ExamResult> selectedExams,
  ) {
    return [
      _DayHeader(
        date: _selectedDate,
        trailing: '${selectedSessions.length + selectedExams.length} 条学习记录',
      ),
      const SizedBox(height: 10),
      if (_studySyncWarning) ...[
        const _InlineWarning(message: '练习历史暂未同步，请稍后重试'),
        const SizedBox(height: 10),
      ],
      if (selectedSessions.isEmpty && selectedExams.isEmpty)
        const _EmptyStateCard(
          icon: Icons.menu_book,
          title: '当天暂无学习历史',
          subtitle: '练习题库或完成模拟考试后，学习记录会出现在这里。',
        )
      else ...[
        ...selectedSessions.map((session) => _StudyLogCard(session: session)),
        ...selectedExams.map((exam) => _ExamLogCard(exam: exam)),
      ],
    ];
  }

  List<Widget> _buildAllSection(
    List<QsoLog> selectedLogs,
    List<PracticeSession> selectedSessions,
    List<ExamResult> selectedExams,
  ) {
    final entries = <({DateTime time, Widget child})>[
      for (final log in selectedLogs)
        (
          time: log.dateTime,
          child: _QsoLogCard(
            log: log,
            onTap: () => _openQsoActions(log),
            onLongPress: () => _createStaticQslLink(log),
          )
        ),
      for (final session in selectedSessions)
        (
          time: session.lastAnsweredAt.toLocal(),
          child: _StudyLogCard(session: session)
        ),
      for (final exam in selectedExams)
        (time: exam.createdAt.toLocal(), child: _ExamLogCard(exam: exam)),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return [
      _DayHeader(
        date: _selectedDate,
        trailing: '${entries.length} 条记录',
      ),
      const SizedBox(height: 10),
      if (_studySyncWarning) ...[
        const _InlineWarning(message: '练习历史暂未同步，请稍后重试'),
        const SizedBox(height: 10),
      ],
      if (entries.isEmpty)
        const _EmptyStateCard(
          icon: Icons.event_note,
          title: '当天暂无记录',
          subtitle: '当天的通联日志和学习记录会集中显示在这里。',
        )
      else
        ...entries.map((entry) => entry.child),
    ];
  }
}

class _HeroHeader extends StatelessWidget {
  final int qsoCount;
  final int studyCount;
  final VoidCallback onSync;
  final VoidCallback onQuickQso;
  final VoidCallback onImportAdif;
  final VoidCallback onExportAdif;
  final VoidCallback onDynamicQsl;

  const _HeroHeader({
    required this.qsoCount,
    required this.studyCount,
    required this.onSync,
    required this.onQuickQso,
    required this.onImportAdif,
    required this.onExportAdif,
    required this.onDynamicQsl,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '日志',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '通联管理',
                icon: Icon(
                  Icons.more_horiz,
                  color: scheme.onPrimaryContainer,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'sync':
                      onSync();
                      break;
                    case 'quick':
                      onQuickQso();
                      break;
                    case 'import':
                      onImportAdif();
                      break;
                    case 'export':
                      onExportAdif();
                      break;
                    case 'dynamic_qsl':
                      onDynamicQsl();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'sync',
                    child: ListTile(
                      leading: Icon(Icons.cloud_sync),
                      title: Text('同步 beacon-api'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'quick',
                    child: ListTile(
                      leading: Icon(Icons.flash_on),
                      title: Text('快速记录'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.upload_file),
                      title: Text('导入 ADIF / LoTW'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.download),
                      title: Text('导出 ADIF'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'dynamic_qsl',
                    child: ListTile(
                      leading: Icon(Icons.qr_code),
                      title: Text('动态 QSL 二维码'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '日历、学习历史和通联日志集中管理',
            style: TextStyle(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: '通联日志',
                  value: '$qsoCount',
                  icon: Icons.radio,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  label: '学习记录',
                  value: '$studyCount',
                  icon: Icons.history_edu,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<String, dynamic> studyCalendar;
  final List<QsoLog> qsoLogs;
  final bool hasSyncWarning;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarPanel({
    required this.focusedMonth,
    required this.selectedDate,
    required this.studyCalendar,
    required this.qsoLogs,
    required this.hasSyncWarning,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => onMonthChanged(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${focusedMonth.year}年 ${focusedMonth.month}月',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => onMonthChanged(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Row(
            children: [
              _WeekdayCell('日'),
              _WeekdayCell('一'),
              _WeekdayCell('二'),
              _WeekdayCell('三'),
              _WeekdayCell('四'),
              _WeekdayCell('五'),
              _WeekdayCell('六'),
            ],
          ),
          const SizedBox(height: 6),
          _CalendarGrid(
            focusedMonth: focusedMonth,
            selectedDate: selectedDate,
            studyCalendar: studyCalendar,
            qsoLogs: qsoLogs,
            onDateSelected: onDateSelected,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 13,
            runSpacing: 6,
            children: [
              const _LegendDot(color: _qsoColor, label: '通联'),
              const _LegendDot(color: _studyColor, label: '学习'),
              const _LegendDot(color: _mixedColor, label: '混合'),
              const _LegendDot(color: _qsoWarningColor, label: '待补全'),
              if (hasSyncWarning)
                _LegendDot(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
                  label: '未同步',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<String, dynamic> studyCalendar;
  final List<QsoLog> qsoLogs;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.studyCalendar,
    required this.qsoLogs,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final offset = firstDay.weekday % 7;
    final totalCells = ((daysInMonth + offset + 6) ~/ 7) * 7;
    final rows = totalCells ~/ 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 360 ? 3.0 : 5.0;
        return Column(
          children: [
            for (var row = 0; row < rows; row++) ...[
              Row(
                children: [
                  for (var column = 0; column < 7; column++) ...[
                    Expanded(
                      child: _CalendarDayCell(
                        index: row * 7 + column,
                        offset: offset,
                        daysInMonth: daysInMonth,
                        focusedMonth: focusedMonth,
                        selectedDate: selectedDate,
                        studyCalendar: studyCalendar,
                        qsoLogs: qsoLogs,
                        onDateSelected: onDateSelected,
                      ),
                    ),
                    if (column != 6) SizedBox(width: spacing),
                  ],
                ],
              ),
              if (row != rows - 1) SizedBox(height: spacing),
            ],
          ],
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int index;
  final int offset;
  final int daysInMonth;
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<String, dynamic> studyCalendar;
  final List<QsoLog> qsoLogs;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarDayCell({
    required this.index,
    required this.offset,
    required this.daysInMonth,
    required this.focusedMonth,
    required this.selectedDate,
    required this.studyCalendar,
    required this.qsoLogs,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (index < offset || index >= daysInMonth + offset) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox());
    }

    final scheme = Theme.of(context).colorScheme;
    final day = index - offset + 1;
    final date = DateTime(focusedMonth.year, focusedMonth.month, day);
    final selected = DateUtils.isSameDay(date, selectedDate);
    final key = _dateKey(date);
    final hasStudy = studyCalendar.containsKey(key);
    final dayQsoLogs =
        qsoLogs.where((log) => DateUtils.isSameDay(log.date, date)).toList();
    final hasQso = dayQsoLogs.isNotEmpty;
    final hasIncompleteQso = dayQsoLogs.any(
      (log) => _qsoMissingRequiredFields(log).isNotEmpty,
    );
    final markerColor = hasIncompleteQso
        ? _qsoWarningColor
        : hasStudy && hasQso
            ? _mixedColor
            : hasQso
                ? _qsoColor
                : _studyColor;

    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => onDateSelected(date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 0 : 0.7,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (hasQso || hasStudy)
                    _TinyDot(color: selected ? scheme.onPrimary : markerColor)
                  else
                    const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = ['通联', '学习', '全部'];
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? scheme.primary : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i == selectedIndex
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  final String message;

  const _InlineWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime date;
  final String trailing;

  const _DayHeader({
    required this.date,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${date.month}月${date.day}日 ${_weekdayName(date)}',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          trailing,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _QsoLogCard extends StatelessWidget {
  final QsoLog log;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _QsoLogCard({
    required this.log,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missingFields = _qsoMissingRequiredFields(log);
    final isIncomplete = missingFields.isNotEmpty;
    final incompletePrefix =
        log.notes.trim().isNotEmpty ? '快速解析记录待补全' : '通联记录待补全';
    final accentColor = isIncomplete ? _qsoWarningColor : _qsoColor;
    final modeText = log.mode.trim().isEmpty ? '待补全' : log.mode;
    final qslColor = _qslStatusColor(context, log.qslStatus);
    return _TimelineCard(
      accentColor: accentColor,
      leading: _formatTime(log.time),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  log.callsign.isEmpty ? '未识别呼号' : log.callsign,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _Pill(
                text: modeText,
                color: isIncomplete ? accentColor : _studyColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (log.country.isNotEmpty) log.country,
              log.band,
              if (log.frequency.isNotEmpty) log.frequency,
              if (log.satName.isNotEmpty) log.satName,
            ].join(' · '),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isIncomplete) _Pill(text: '待补全', color: accentColor),
              if (log.report.isNotEmpty)
                _Pill(
                  text: 'RST ${log.report}',
                  color: _qsoColor,
                ),
              if (log.grid.isNotEmpty)
                _Pill(text: log.grid, color: scheme.primary),
              _Pill(
                text: _qslStatusLabel(log.qslStatus),
                color: qslColor,
              ),
              if (log.lotwStatus != 'none')
                _Pill(text: 'LoTW ${log.lotwStatus}', color: scheme.secondary),
            ],
          ),
          if (isIncomplete) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note, color: accentColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$incompletePrefix：${missingFields.join('、')}。点击卡片编辑后可同步。',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StudyLogCard extends StatelessWidget {
  final PracticeSession session;

  const _StudyLogCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _TimelineCard(
      accentColor: _studyColor,
      leading: _timeFromDate(session.lastAnsweredAt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.modeName,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${session.libraryName ?? session.libraryCode ?? '题库'} · '
            '${session.correctCount}/${session.totalQuestions} 正确 · '
            '${session.accuracy.toStringAsFixed(1)}%',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ExamLogCard extends StatelessWidget {
  final ExamResult exam;

  const _ExamLogCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passed = exam.passed;
    return _TimelineCard(
      accentColor: passed ? _qsoColor : _mixedColor,
      leading: _timeFromDate(exam.createdAt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${exam.libraryCode ?? '题库'} 模拟考试',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _Pill(
                text: passed ? '已合格' : '未合格',
                color: passed ? _qsoColor : _mixedColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${exam.score} 分 · ${exam.correctCount}/${exam.totalQuestions} 正确'
            '${exam.timeSpent == null ? '' : ' · ${exam.timeSpent} 分钟'}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Color accentColor;
  final String leading;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _TimelineCard({
    required this.accentColor,
    required this.leading,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Text(
                    leading,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 4,
                    height: 54,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(child: child),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const _SurfaceCard({
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: child,
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SurfaceCard(
      child: Column(
        children: [
          Icon(icon, color: scheme.primary, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  final String text;

  const _WeekdayCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TinyDot(color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _TinyDot extends StatelessWidget {
  final Color color;

  const _TinyDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AddQsoSheet extends StatefulWidget {
  final DateTime initialDate;
  final QsoLog? initialLog;

  const _AddQsoSheet({
    required this.initialDate,
    this.initialLog,
  });

  @override
  State<_AddQsoSheet> createState() => _AddQsoSheetState();
}

class _AddQsoSheetState extends State<_AddQsoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _callsignController = TextEditingController();
  final _countryController = TextEditingController(text: '中国');
  final _frequencyController = TextEditingController(text: '14.074 MHz');
  final _reportController = TextEditingController(text: '59 / 59');
  final _gridController = TextEditingController();
  String _band = '20m';
  String _mode = 'FT8';
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final initialLog = widget.initialLog;
    if (initialLog != null) {
      _callsignController.text = initialLog.callsign;
      _countryController.text = initialLog.country;
      _frequencyController.text = initialLog.frequency;
      _reportController.text = initialLog.report;
      _gridController.text = initialLog.grid;
      _band = initialLog.band.isEmpty ? _band : initialLog.band;
      _mode = initialLog.mode.isEmpty ? _mode : initialLog.mode;
      _date = initialLog.date;
      _time = initialLog.time;
      return;
    }
    final now = DateTime.now();
    _date = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _callsignController.dispose();
    _countryController.dispose();
    _frequencyController.dispose();
    _reportController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final initialLog = widget.initialLog;
    Navigator.of(context).pop(
      QsoLog(
        id: initialLog?.id,
        time: _time,
        callsign: _callsignController.text.trim().toUpperCase(),
        country: _countryController.text.trim(),
        band: _band,
        mode: _mode,
        frequency: _frequencyController.text.trim(),
        report: _reportController.text.trim(),
        grid: _gridController.text.trim().toUpperCase(),
        stationCallsign: initialLog?.stationCallsign ?? '',
        satName: initialLog?.satName ?? '',
        propMode: initialLog?.propMode ?? '',
        notes: initialLog?.notes ?? '',
        qslStatus: initialLog?.qslStatus ?? 'none',
        lotwStatus: initialLog?.lotwStatus ?? 'none',
        cloudlogStatus: initialLog?.cloudlogStatus ?? 'none',
        clublogStatus: initialLog?.clublogStatus ?? 'none',
        qrzStatus: initialLog?.qrzStatus ?? 'none',
        date: _date,
        createdAt: initialLog?.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.initialLog == null ? '添加通联' : '编辑通联',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.initialLog == null
                    ? '记录呼号、频率、模式、RST 和网格定位，数据仅保存到本地。'
                    : '修改后会更新本地记录，下次同步时上传到 beacon-api。',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              _QsoTextField(
                controller: _callsignController,
                label: '呼号',
                hint: '例如 BG7ABC',
                icon: Icons.badge,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入呼号';
                  }
                  return null;
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: _QsoDropdown(
                      label: '频段',
                      value: _band,
                      values: _mergeDropdownValues(
                        _band,
                        const [
                          '160m',
                          '80m',
                          '40m',
                          '30m',
                          '20m',
                          '17m',
                          '15m',
                          '12m',
                          '10m',
                          '2m',
                          '70cm',
                        ],
                      ),
                      onChanged: (value) => setState(() => _band = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QsoDropdown(
                      label: '模式',
                      value: _mode,
                      values: _mergeDropdownValues(
                        _mode,
                        const ['SSB', 'CW', 'FT8', 'RTTY', 'FM', 'AM'],
                      ),
                      onChanged: (value) => setState(() => _mode = value),
                    ),
                  ),
                ],
              ),
              _QsoTextField(
                controller: _frequencyController,
                label: '频率',
                hint: '例如 14.074 MHz',
                icon: Icons.graphic_eq,
              ),
              Row(
                children: [
                  Expanded(
                    child: _QsoActionField(
                      label: '日期',
                      value: _formatDate(_date),
                      icon: Icons.calendar_month,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QsoActionField(
                      label: '时间',
                      value: _formatTime(_time),
                      icon: Icons.schedule,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _QsoTextField(
                      controller: _reportController,
                      label: 'RST',
                      hint: '例如 59 / 59',
                      icon: Icons.signal_cellular_alt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QsoTextField(
                      controller: _gridController,
                      label: 'Grid',
                      hint: '例如 OL63xx',
                      icon: Icons.public,
                    ),
                  ),
                ],
              ),
              _QsoTextField(
                controller: _countryController,
                label: '国家 / 地区',
                hint: '例如 中国',
                icon: Icons.flag,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save),
                  label: Text(widget.initialLog == null ? '保存通联' : '保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QsoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;

  const _QsoTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          hintText: hint,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _QsoDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _QsoDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _QsoActionField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _QsoActionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            labelText: label,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(value),
        ),
      ),
    );
  }
}

String _dateKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String _formatShortDate(DateTime date) {
  return '${date.month}月${date.day}日';
}

String _formatTime(TimeOfDay time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}

String _timeFromDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

List<String> _mergeDropdownValues(String value, List<String> defaults) {
  if (value.trim().isEmpty || defaults.contains(value)) return defaults;
  return [value, ...defaults];
}

List<String> _qsoMissingRequiredFields(QsoLog log) {
  final fields = <String>[];
  if (log.callsign.trim().isEmpty) fields.add('呼号');
  if (log.band.trim().isEmpty) fields.add('频段');
  if (log.mode.trim().isEmpty) fields.add('模式');
  if (log.frequency.trim().isEmpty) fields.add('频率');
  return fields;
}

String _qslStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'received':
    case 'confirmed':
      return 'QSL 已收妥';
    case 'pending':
    case 'requested':
    case 'sent':
      return 'QSL 待收妥';
    case 'failed':
    case 'error':
      return 'QSL 异常';
    case 'none':
    case '':
      return 'QSL 未发起';
    default:
      return 'QSL ${status.trim()}';
  }
}

Color _qslStatusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status.trim().toLowerCase()) {
    case 'received':
    case 'confirmed':
      return _qsoColor;
    case 'pending':
    case 'requested':
    case 'sent':
      return const Color(0xffd0831f);
    case 'failed':
    case 'error':
      return _qsoWarningColor;
    case 'none':
    case '':
      return scheme.onSurfaceVariant;
    default:
      return scheme.tertiary;
  }
}

String _weekdayName(DateTime date) {
  const names = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return names[date.weekday - 1];
}
