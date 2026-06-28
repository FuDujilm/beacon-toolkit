import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/eme_degradation.dart';
import '../../models/sepc_daily_report.dart';
import '../../models/sepc_fof2.dart';
import '../../models/sepc_ionosphere.dart';
import '../../models/sepc_k_index.dart';
import '../../models/sepc_long_term_forecast.dart';
import '../../models/sepc_solar_events.dart';
import '../../models/sepc_tec_map.dart';
import '../../models/solar_activity.dart';
import '../../services/eme_degradation_service.dart';
import '../../services/local_database_service.dart';
import '../../services/sepc_daily_report_service.dart';
import '../../services/sepc_fof2_service.dart';
import '../../services/sepc_ionosphere_service.dart';
import '../../services/sepc_k_index_service.dart';
import '../../services/sepc_long_term_forecast_service.dart';
import '../../services/sepc_solar_event_service.dart';
import '../../services/sepc_tec_map_service.dart';
import '../../services/llm_service.dart';
import '../../services/solar_activity_service.dart';
import 'radio_theme.dart';

enum _PropagationSection {
  source,
  solarImages,
  dailyReport,
  threeDayForecast,
  kIndex,
  longTermForecast,
  solarEvents,
  emeDegradation,
  fof2,
  ionosphere,
  tecMap,
  metrics,
  hfConditions,
  vhfConditions,
  details,
}

const Set<_PropagationSection> _defaultPropagationSections = {
  _PropagationSection.solarImages,
  _PropagationSection.threeDayForecast,
  _PropagationSection.kIndex,
  _PropagationSection.longTermForecast,
  _PropagationSection.solarEvents,
  _PropagationSection.emeDegradation,
  _PropagationSection.hfConditions,
};

const List<_PropagationSection> _allPropagationSections = [
  _PropagationSection.source,
  _PropagationSection.solarImages,
  _PropagationSection.dailyReport,
  _PropagationSection.threeDayForecast,
  _PropagationSection.kIndex,
  _PropagationSection.longTermForecast,
  _PropagationSection.solarEvents,
  _PropagationSection.emeDegradation,
  _PropagationSection.fof2,
  _PropagationSection.ionosphere,
  _PropagationSection.tecMap,
  _PropagationSection.metrics,
  _PropagationSection.hfConditions,
  _PropagationSection.vhfConditions,
  _PropagationSection.details,
];

const String _visibleSectionsSettingKey = 'propagation_visible_sections';

const String _propagationSystemPrompt = '''
你是业余无线电传播预测助手。用户会提供一个 JSON，包含当前传播预测页面汇总的 SEPC、HamQSL、foF2、K指数、TEC、耀斑/SID 等数据。

必须只返回一个 JSON 对象，禁止 Markdown、代码块、解释性前后缀。JSON schema:
{
  "summary": "一句话总览，不超过 40 个汉字",
  "level": "good|fair|poor|alert",
  "tabs": [
    {
      "id": "overview|hf|vhf|risk|actions|sources",
      "title": "标签名，2-5 个汉字",
      "items": [
        {
          "label": "短标签，2-8 个汉字",
          "value": "结论或数值，不超过 24 个汉字",
          "detail": "说明原因和操作建议，不超过 80 个汉字",
          "level": "good|fair|poor|alert"
        }
      ]
    }
  ],
  "disclaimer": "仅供参考，请遵守当地法规和主管部门要求。"
}

最小样例：
{
  "summary": "短波整体一般，VHF 可短时尝试",
  "level": "fair",
  "tabs": [
    {"id":"overview","title":"总览","items":[{"label":"总评","value":"一般","detail":"地磁扰动不强，但电离层参数仍需复查。","level":"fair"}]},
    {"id":"hf","title":"短波","items":[{"label":"低波段","value":"夜间优先","detail":"若 foF2 偏低，白天高波段可用窗口缩短。","level":"fair"}]},
    {"id":"actions","title":"建议","items":[{"label":"复查","value":"1-3 小时","detail":"太阳耀斑或 Kp 快速变化时应重新刷新数据。","level":"good"}]}
  ],
  "disclaimer": "仅供参考，请遵守当地法规和主管部门要求。"
}

业务要求：
1. 面向业余无线电操作者，直接说明短波、VHF、地磁扰动、太阳耀斑/SID 对通联的影响。
2. 给出可执行建议：适合尝试的波段、需要避开的风险、何时复查数据。
3. 明确标注主要依据的数据源，例如 SEPC 或 HamQSL；当数据源冲突时说明以中国 SEPC 数据优先，国际数据作为参考。
4. 不要宣称任何频率一定合法，不要给出官方许可结论。
5. tabs 至少包含 总览、短波、风险、建议、来源；最多 6 个标签，每个标签最多 4 条 items。
''';

class PropagationForecastPage extends StatefulWidget {
  const PropagationForecastPage({super.key});

  @override
  State<PropagationForecastPage> createState() =>
      _PropagationForecastPageState();
}

class _PropagationForecastPageState extends State<PropagationForecastPage> {
  final _solarService = SolarActivityService();
  final _sepcService = SepcDailyReportService();
  final _fof2Service = SepcFof2Service();
  final _kIndexService = SepcKIndexService();
  final _ionosphereService = SepcIonosphereService();
  final _tecMapService = SepcTecMapService();
  final _longTermForecastService = SepcLongTermForecastService();
  final _solarEventService = SepcSolarEventService();
  final _emeService = EmeDegradationService();
  final _llmService = LlmService();
  final _databaseService = LocalDatabaseService();

  SolarActivity? _activity;
  SepcDailyReport? _sepcReport;
  SepcFof2Report? _fof2Report;
  SepcKIndexReport? _kIndexReport;
  SepcIonosphereImage? _ionosphereImage;
  SepcTecMapReport? _tecMapReport;
  List<SepcLongTermForecast> _longTermForecasts = const [];
  SepcSolarFlareReport? _solarFlareReport;
  SepcSidReport? _sidReport;
  EmeDegradationReport? _emeReport;
  Object? _error;
  Object? _sepcError;
  Object? _fof2Error;
  Object? _kIndexError;
  Object? _ionosphereError;
  Object? _tecMapError;
  Object? _longTermForecastError;
  Object? _solarFlareError;
  Object? _sidError;
  bool _loading = true;
  bool _refreshing = false;
  bool _llmLoading = false;
  _PropagationAiReport? _llmResult;
  String? _llmError;
  SepcIonosphereStation _ionosphereStation = SepcIonosphereService.stations[1];
  SepcIonosphereProduct _ionosphereProduct =
      SepcIonosphereProduct.scintillation;
  DateTime _ionosphereDate = DateTime.now();
  SepcFof2Station _fof2Station = SepcFof2Service.stations.first;
  Set<_PropagationSection> _visibleSections =
      Set<_PropagationSection>.of(_defaultPropagationSections);

  @override
  void initState() {
    super.initState();
    _emeReport = _emeService.calculate();
    _loadVisibleSections();
    _load();
  }

  Future<void> _loadVisibleSections() async {
    final raw = await _databaseService.getSetting(_visibleSectionsSettingKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final sections = decoded
          .map((item) => _sectionFromName(item.toString()))
          .whereType<_PropagationSection>()
          .toSet();
      if (sections.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _visibleSections = sections;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _saveVisibleSections(Set<_PropagationSection> sections) async {
    await _databaseService.saveSetting(
      _visibleSectionsSettingKey,
      jsonEncode([for (final section in sections) section.name]),
    );
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = !refresh;
      _refreshing = refresh;
      _error = null;
      _sepcError = null;
      _fof2Error = null;
      _kIndexError = null;
      _ionosphereError = null;
      _tecMapError = null;
      _longTermForecastError = null;
      _solarFlareError = null;
      _sidError = null;
      _emeReport = _emeService.calculate();
    });
    try {
      final results = await Future.wait<Object?>([
        _solarService.fetchSolarActivity(),
        _loadSepcReportResult(),
        _loadFof2Result(),
        _loadKIndexResult(),
        _loadIonosphereResult(),
        _loadTecMapResult(),
        _loadLongTermForecastResult(),
        _loadSolarFlareResult(),
        _loadSidResult(),
      ]);
      final activity = results[0] as SolarActivity;
      final sepcResult = results[1];
      final fof2Result = results[2];
      final kIndexResult = results[3];
      final ionosphereResult = results[4];
      final tecMapResult = results[5];
      final longTermForecastResult = results[6];
      final solarFlareResult = results[7];
      final sidResult = results[8];
      if (!mounted) return;
      setState(() {
        _activity = activity;
        if (sepcResult is SepcDailyReport) {
          _sepcReport = sepcResult;
        } else if (sepcResult != null) {
          _sepcError = sepcResult;
        }
        if (fof2Result is SepcFof2Report) {
          _fof2Report = fof2Result;
        } else if (fof2Result != null) {
          _fof2Error = fof2Result;
        }
        if (kIndexResult is SepcKIndexReport) {
          _kIndexReport = kIndexResult;
        } else if (kIndexResult != null) {
          _kIndexError = kIndexResult;
        }
        if (ionosphereResult is SepcIonosphereImage) {
          _ionosphereImage = ionosphereResult;
        } else if (ionosphereResult != null) {
          _ionosphereError = ionosphereResult;
        }
        if (tecMapResult is SepcTecMapReport) {
          _tecMapReport = tecMapResult;
        } else if (tecMapResult != null) {
          _tecMapError = tecMapResult;
        }
        if (longTermForecastResult is List<SepcLongTermForecast>) {
          _longTermForecasts = longTermForecastResult;
        } else if (longTermForecastResult != null) {
          _longTermForecastError = longTermForecastResult;
        }
        if (solarFlareResult is SepcSolarFlareReport) {
          _solarFlareReport = solarFlareResult;
        } else if (solarFlareResult != null) {
          _solarFlareError = solarFlareResult;
        }
        if (sidResult is SepcSidReport) {
          _sidReport = sidResult;
        } else if (sidResult != null) {
          _sidError = sidResult;
        }
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<Object?> _loadKIndexResult() async {
    try {
      return await _kIndexService.fetchRecent(days: 3);
    } catch (e) {
      return e;
    }
  }

  Future<Object?> _loadSepcReportResult() async {
    try {
      return await _sepcService.fetchDailyReport();
    } catch (e) {
      return e;
    }
  }

  Future<Object?> _loadFof2Result() async {
    try {
      return await _fof2Service.fetchRecent(station: _fof2Station);
    } catch (e) {
      return e;
    }
  }

  Future<Object?> _loadIonosphereResult() async {
    try {
      return await _ionosphereService.fetchImage(
        station: _ionosphereStation,
        product: _ionosphereProduct,
        date: _ionosphereDate,
      );
    } catch (e) {
      return e;
    }
  }

  Future<Object?> _loadTecMapResult() async {
    try {
      return await _tecMapService.fetchLatest();
    } catch (e) {
      return e;
    }
  }

  Future<Object?> _loadLongTermForecastResult() async {
    try {
      return await _longTermForecastService.fetchAll();
    } catch (e) {
      return e;
    }
  }

  Future<Object?> _loadSolarFlareResult() async {
    try {
      return await _solarEventService.fetchSolarFlares();
    } catch (e) {
      return e;
    }
  }

  Future<Object?> _loadSidResult() async {
    try {
      return await _solarEventService.fetchSidEvents();
    } catch (e) {
      return e;
    }
  }

  Future<void> _updateIonosphere({
    SepcIonosphereStation? station,
    SepcIonosphereProduct? product,
    DateTime? date,
  }) async {
    setState(() {
      _ionosphereStation = station ?? _ionosphereStation;
      _ionosphereProduct = product ?? _ionosphereProduct;
      _ionosphereDate = date ?? _ionosphereDate;
      _ionosphereError = null;
      _ionosphereImage = null;
    });
    final result = await _loadIonosphereResult();
    if (!mounted) return;
    setState(() {
      if (result is SepcIonosphereImage) {
        _ionosphereImage = result;
      } else if (result != null) {
        _ionosphereError = result;
      }
    });
  }

  Future<void> _updateFof2(SepcFof2Station station) async {
    setState(() {
      _fof2Station = station;
      _fof2Report = null;
      _fof2Error = null;
    });
    final result = await _loadFof2Result();
    if (!mounted) return;
    setState(() {
      if (result is SepcFof2Report) {
        _fof2Report = result;
      } else if (result != null) {
        _fof2Error = result;
      }
    });
  }

  Future<void> _analyzeWithLlm() async {
    final activity = _activity;
    if (activity == null) return;
    setState(() {
      _llmLoading = true;
      _llmError = null;
    });
    try {
      final result = await _llmService.complete(
        systemPrompt: _propagationSystemPrompt,
        userPrompt: jsonEncode(_buildPropagationPayload(activity)),
      );
      if (!mounted) return;
      setState(() {
        _llmResult = _PropagationAiReport.parse(result);
        _llmLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _llmError = e is FormatException ? e.message : e.toString();
        _llmLoading = false;
      });
    }
  }

  Map<String, dynamic> _buildPropagationPayload(SolarActivity activity) {
    return {
      'page': '传播预测',
      'generatedAt': DateTime.now().toIso8601String(),
      'hamqsl': {
        'sourceName': activity.sourceName,
        'sourceUrl': activity.sourceUrl,
        'updated': activity.updated,
        'solarFlux': activity.solarFlux,
        'aIndex': activity.aIndex,
        'kIndex': activity.kIndex,
        'xray': activity.xray,
        'sunspots': activity.sunspots,
        'solarWind': activity.solarWind,
        'magneticField': activity.magneticField,
        'geomagneticField': activity.geomagneticField,
        'signalNoise': activity.signalNoise,
        'foF2': activity.fof2,
        'mufFactor': activity.mufFactor,
        'muf': activity.muf,
        'hfConditions': [
          for (final item in activity.hfConditions)
            {
              'band': item.band,
              'time': item.time,
              'condition': item.condition,
            },
        ],
        'vhfConditions': [
          for (final item in activity.vhfConditions)
            {
              'name': item.name,
              'location': item.location,
              'condition': item.condition,
            },
        ],
      },
      if (_sepcReport != null)
        'sepcDailyReport': {
          'sourceName': _sepcReport!.sourceName,
          'sourceUrl': _sepcReport!.sourceUrl,
          'title': _sepcReport!.title,
          'summary': _sepcReport!.summary,
          'forecast': _sepcReport!.forecast,
          'kp': _sepcReport!.kp,
          'f107': _sepcReport!.f107,
          'sunspots': _sepcReport!.sunspots,
          'solarWindSpeed': _sepcReport!.solarWindSpeed,
          'issuedAt': _sepcReport!.issuedAt,
          'forecaster': _sepcReport!.forecaster,
          'solarImageCount': _sepcReport!.imageBase64List.length,
        },
      if (_kIndexReport != null)
        'sepcKIndex': {
          'sourceName': _kIndexReport!.sourceName,
          'sourceUrl': _kIndexReport!.sourceUrl,
          'latestValue': _kIndexReport!.latestValue,
          'series': [
            for (final series in _kIndexReport!.series)
              {
                'name': series.name,
                'latestPoints': [
                  for (final point
                      in series.points.reversed.take(8).toList().reversed)
                    {'time': point.time, 'value': point.value},
                ],
              },
          ],
        },
      if (_longTermForecasts.isNotEmpty)
        'sepcLongTermForecasts': [
          for (final forecast in _longTermForecasts)
            {
              'kind': forecast.kind.name,
              'sourceName': forecast.sourceName,
              'sourceUrl': forecast.sourceUrl,
              'latestPredicted': {
                'dateLabel': forecast.latestPredictedPoint?.dateLabel,
                'value': forecast.latestPredictedPoint?.predicted,
              },
            },
        ],
      if (_solarFlareReport != null)
        'solarFlareEvents': [
          for (final event in _solarFlareReport!.events.take(8))
            {
              'startTime': event.startTime.toIso8601String(),
              'endTime': event.endTime.toIso8601String(),
              'level': event.level,
              'rotation': event.rotation,
            },
        ],
      if (_sidReport != null)
        'sidEvents': [
          for (final event in _sidReport!.events.take(8))
            {
              'peakTime': event.peakTime.toIso8601String(),
              'level': event.level,
              'description': event.description,
            },
        ],
      if (_emeReport != null)
        'emeDegradation': {
          'sourceName': _emeReport!.sourceName,
          'calculatedAt': _emeReport!.calculatedAt.toIso8601String(),
          'moonDistanceKm': _emeReport!.moonDistanceKm,
          'referenceDistanceKm': _emeReport!.referenceDistanceKm,
          'rangeDegradationDb': _emeReport!.rangeDegradationDb,
          'skyNoiseDegradationDb': _emeReport!.skyNoiseDegradationDb,
          'skyTemperatureK': _emeReport!.skyTemperatureK,
          'skyNoiseMinK': _emeReport!.skyNoiseMinK,
          'systemNoiseTemperatureK': _emeReport!.systemNoiseTemperatureK,
          'frequencyMhz': _emeReport!.frequencyMhz,
          'galacticLongitudeDeg': _emeReport!.galacticLongitudeDeg,
          'galacticLatitudeDeg': _emeReport!.galacticLatitudeDeg,
          'skyNoiseModel': _emeReport!.skyNoiseModel,
          'totalDegradationDb': _emeReport!.totalDegradationDb,
          'level': _emeLevelEnglishLabel(_emeReport!.level),
          'levelLabel': _emeLevelLabel(_emeReport!.level),
          'note': '当前使用月地距离项与低分辨率银河背景天空噪声近似项；后续可替换 Haslam 408 MHz 降采样天空图。',
        },
      if (_fof2Report != null)
        'sepcFof2': {
          'sourceName': _fof2Report!.sourceName,
          'sourceUrl': _fof2Report!.sourceUrl,
          'station': _fof2Report!.station.name,
          'latest': {
            'time': _fof2Report!.latestPoint?.time.toIso8601String(),
            'valueMHz': _fof2Report!.latestPoint?.value,
          },
        },
      if (_ionosphereImage != null)
        'sepcIonosphere': {
          'sourceName': _ionosphereImage!.sourceName,
          'sourceUrl': _ionosphereImage!.sourceUrl,
          'station': _ionosphereImage!.station.name,
          'product': _ionosphereImage!.product.name,
          'date': _ionosphereImage!.date.toIso8601String(),
        },
      if (_tecMapReport != null)
        'sepcTecMap': {
          'sourceName': _tecMapReport!.sourceName,
          'sourceUrl': _tecMapReport!.sourceUrl,
          'products': [
            for (final image in _tecMapReport!.images)
              {'product': image.product.name, 'title': image.title},
          ],
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        title: const Text('传播预测'),
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        actions: [
          IconButton(
            tooltip: 'AI 解读',
            onPressed: _llmLoading ? null : _analyzeWithLlm,
            icon: _llmLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: '筛选展示',
            onPressed: _openSectionFilter,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _refreshing ? null : () => _load(refresh: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = _buildContent(context);
          if (constraints.maxWidth < 860) return content;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: content,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSectionFilter() async {
    final next = await showModalBottomSheet<Set<_PropagationSection>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _SectionFilterSheet(selected: _visibleSections);
      },
    );
    if (next == null || !mounted) return;
    setState(() {
      _visibleSections = next;
    });
    await _saveVisibleSections(next);
  }

  List<Widget> _section(
    _PropagationSection section,
    Widget child, {
    bool topGap = true,
  }) {
    if (!_visibleSections.contains(section)) return const [];
    return [
      if (topGap) const SizedBox(height: 12),
      child,
    ];
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _activity == null) {
      return _ErrorView(
        message: _errorMessage(_error!),
        onRetry: () => _load(refresh: true),
      );
    }

    final activity = _activity;
    if (activity == null) {
      return _ErrorView(message: '暂无太阳活动数据', onRetry: () => _load());
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          _OverviewCard(activity: activity, sepcReport: _sepcReport),
          if (_llmResult != null || _llmError != null) ...[
            const SizedBox(height: 12),
            _LlmResultPanel(
              result: _llmResult,
              error: _llmError,
              onDismiss: () => setState(() {
                _llmResult = null;
                _llmError = null;
              }),
            ),
          ],
          ..._section(
            _PropagationSection.source,
            _SourceCard(activity: activity),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _MessagePanel(message: _errorMessage(_error!), error: true),
          ],
          ..._section(
            _PropagationSection.solarImages,
            _SepcSolarImagePanel(report: _sepcReport),
          ),
          ..._section(
            _PropagationSection.dailyReport,
            _SepcDailyReportPanel(
              report: _sepcReport,
              error: _sepcError == null ? null : _errorMessage(_sepcError!),
              onOpenSource: () => launchUrl(
                Uri.parse(SepcDailyReportService.sourceUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          ..._section(
            _PropagationSection.threeDayForecast,
            _SepcForecastPanel(
              report: _sepcReport,
              error: _sepcError == null ? null : _errorMessage(_sepcError!),
            ),
          ),
          ..._section(
            _PropagationSection.kIndex,
            _KIndexTrendPanel(
              report: _kIndexReport,
              error: _kIndexError == null ? null : _errorMessage(_kIndexError!),
            ),
          ),
          ..._section(
            _PropagationSection.longTermForecast,
            _LongTermForecastPanel(
              forecasts: _longTermForecasts,
              error: _longTermForecastError == null
                  ? null
                  : _errorMessage(_longTermForecastError!),
              onRetry: () => _load(refresh: true),
            ),
          ),
          ..._section(
            _PropagationSection.solarEvents,
            _SolarEventPanel(
              flareReport: _solarFlareReport,
              flareError: _solarFlareError == null
                  ? null
                  : _errorMessage(_solarFlareError!),
              sidReport: _sidReport,
              sidError: _sidError == null ? null : _errorMessage(_sidError!),
              onRetry: () => _load(refresh: true),
            ),
          ),
          ..._section(
            _PropagationSection.emeDegradation,
            _EmeDegradationPanel(report: _emeReport),
          ),
          ..._section(
            _PropagationSection.fof2,
            _Fof2Panel(
              report: _fof2Report,
              error: _fof2Error == null ? null : _errorMessage(_fof2Error!),
              station: _fof2Station,
              onStationChanged: _updateFof2,
              onRetry: () => _updateFof2(_fof2Station),
            ),
          ),
          ..._section(
            _PropagationSection.ionosphere,
            _IonospherePanel(
              image: _ionosphereImage,
              error: _ionosphereError == null
                  ? null
                  : _errorMessage(_ionosphereError!),
              station: _ionosphereStation,
              product: _ionosphereProduct,
              date: _ionosphereDate,
              onStationChanged: (station) =>
                  _updateIonosphere(station: station),
              onProductChanged: (product) =>
                  _updateIonosphere(product: product),
              onDateChanged: (date) => _updateIonosphere(date: date),
              onRetry: () => _updateIonosphere(),
            ),
          ),
          ..._section(
            _PropagationSection.tecMap,
            _TecMapPanel(
              report: _tecMapReport,
              error: _tecMapError == null ? null : _errorMessage(_tecMapError!),
              onRetry: () => _load(refresh: true),
            ),
          ),
          ..._section(
            _PropagationSection.metrics,
            _MetricGrid(activity: activity),
          ),
          ..._section(
            _PropagationSection.hfConditions,
            _HfConditionPanel(conditions: activity.hfConditions),
          ),
          ..._section(
            _PropagationSection.vhfConditions,
            _VhfConditionPanel(conditions: activity.vhfConditions),
          ),
          ..._section(
            _PropagationSection.details,
            _DetailPanel(activity: activity),
          ),
          const SizedBox(height: 12),
          const _MessagePanel(
            message: '仅供参考，请遵守当地法规和主管部门要求。',
            error: false,
          ),
        ],
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is FormatException) return error.message;
    return error.toString();
  }
}

class _OverviewCard extends StatelessWidget {
  final SolarActivity activity;
  final SepcDailyReport? sepcReport;

  const _OverviewCard({
    required this.activity,
    required this.sepcReport,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = radioThemeColors(context);
    final report = sepcReport;
    final kp = report?.kp.isNotEmpty == true ? report!.kp : activity.kIndex;
    final f107 =
        report?.f107.isNotEmpty == true ? report!.f107 : activity.solarFlux;
    final geomagnetic = report == null ? activity.geomagneticField : 'SEPC 预测';
    final sourceLabel = report == null ? 'HamQSL 国际参考' : report.sourceName;
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xffffb23e).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: Color(0xffffa000),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '空间环境概览',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '数据源：$sourceLabel',
                      style: TextStyle(color: scheme.primary),
                    ),
                    Text(
                      'F10.7 ${_value(f107)} · Kp ${_value(kp)} · ${_value(geomagnetic)}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(label: '短波', value: activity.hfSummary),
              if (report?.sunspots.isNotEmpty == true)
                _StatusChip(label: '黑子', value: report!.sunspots),
              if (report?.solarWindSpeed.isNotEmpty == true)
                _StatusChip(
                    label: '太阳风', value: '${report!.solarWindSpeed} km/s'),
              _StatusChip(label: 'X 射线', value: _value(activity.xray)),
              _StatusChip(label: '国际噪声', value: _value(activity.signalNoise)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LlmResultPanel extends StatelessWidget {
  final _PropagationAiReport? result;
  final String? error;
  final VoidCallback onDismiss;

  const _LlmResultPanel({
    required this.result,
    required this.error,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = error != null;
    final color = hasError ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasError
            ? scheme.errorContainer.withValues(alpha: 0.60)
            : scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasError ? Icons.error_outline : Icons.auto_awesome,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasError ? 'AI 解读不可用' : 'AI 传播解读',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasError)
            Text(
              error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.55,
                    color: scheme.onErrorContainer,
                  ),
            )
          else if (result != null)
            _PropagationAiReportView(report: result!),
        ],
      ),
    );
  }
}

class _PropagationAiReportView extends StatelessWidget {
  final _PropagationAiReport report;

  const _PropagationAiReportView({required this.report});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = report.tabs.isEmpty
        ? [
            _PropagationAiTab(
              id: 'overview',
              title: '总览',
              items: [
                _PropagationAiItem(
                  label: '解读',
                  value: report.summary,
                  detail: report.disclaimer,
                  level: report.level,
                ),
              ],
            ),
          ]
        : report.tabs;
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _AiLevelChip(level: report.level),
              Text(
                report.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: [for (final tab in tabs) Tab(text: tab.title)],
          ),
          SizedBox(
            height: _aiTabHeight(tabs),
            child: TabBarView(
              children: [
                for (final tab in tabs) _PropagationAiTabView(tab: tab),
              ],
            ),
          ),
          if (report.disclaimer.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              report.disclaimer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  double _aiTabHeight(List<_PropagationAiTab> tabs) {
    final maxItems = tabs
        .map((tab) => tab.items.length)
        .fold<int>(1, (max, count) => count > max ? count : max);
    return (maxItems * 86 + 16).clamp(132, 360).toDouble();
  }
}

class _PropagationAiTabView extends StatelessWidget {
  final _PropagationAiTab tab;

  const _PropagationAiTabView({required this.tab});

  @override
  Widget build(BuildContext context) {
    if (tab.items.isEmpty) {
      return const Center(child: Text('暂无解读'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 12),
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = tab.items[index];
        return _PropagationAiItemTile(item: item);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: tab.items.length,
    );
  }
}

class _PropagationAiItemTile extends StatelessWidget {
  final _PropagationAiItem item;

  const _PropagationAiItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _aiLevelColor(context, item.level);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      item.value,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (item.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.detail,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiLevelChip extends StatelessWidget {
  final String level;

  const _AiLevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _aiLevelColor(context, level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _aiLevelLabel(level),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Color _aiLevelColor(BuildContext context, String level) {
  final scheme = Theme.of(context).colorScheme;
  return switch (level) {
    'good' => Colors.green,
    'poor' => Colors.orange,
    'alert' => scheme.error,
    _ => scheme.primary,
  };
}

String _aiLevelLabel(String level) {
  return switch (level) {
    'good' => '良好',
    'poor' => '较差',
    'alert' => '警惕',
    _ => '一般',
  };
}

class _PropagationAiReport {
  final String summary;
  final String level;
  final List<_PropagationAiTab> tabs;
  final String disclaimer;

  const _PropagationAiReport({
    required this.summary,
    required this.level,
    required this.tabs,
    required this.disclaimer,
  });

  factory _PropagationAiReport.parse(String raw) {
    final trimmed = raw.trim();
    try {
      final decoded = jsonDecode(_extractJsonObject(trimmed));
      if (decoded is Map<String, dynamic>) {
        return _PropagationAiReport.fromJson(decoded);
      }
    } catch (_) {
      // Fall through to raw output rendering.
    }
    return _PropagationAiReport(
      summary: 'AI 返回了非结构化内容',
      level: 'fair',
      tabs: [
        _PropagationAiTab(
          id: 'raw',
          title: '原文',
          items: [
            _PropagationAiItem(
              label: '原始输出',
              value: '未按 JSON 返回',
              detail: trimmed,
              level: 'fair',
            ),
          ],
        ),
      ],
      disclaimer: '仅供参考，请遵守当地法规和主管部门要求。',
    );
  }

  factory _PropagationAiReport.fromJson(Map<String, dynamic> json) {
    final tabsJson = json['tabs'];
    final tabs = tabsJson is List
        ? tabsJson
            .whereType<Map>()
            .map((item) => _PropagationAiTab.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where((tab) => tab.title.isNotEmpty)
            .take(6)
            .toList()
        : <_PropagationAiTab>[];
    return _PropagationAiReport(
      summary: _shortText(json['summary'], fallback: '暂无概要', maxLength: 60),
      level: _normalizeAiLevel(json['level']),
      tabs: tabs,
      disclaimer: _shortText(
        json['disclaimer'],
        fallback: '仅供参考，请遵守当地法规和主管部门要求。',
        maxLength: 80,
      ),
    );
  }

  static String _extractJsonObject(String raw) {
    var text = raw;
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
          .replaceFirst(RegExp(r'\s*```$', multiLine: true), '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }
}

class _PropagationAiTab {
  final String id;
  final String title;
  final List<_PropagationAiItem> items;

  const _PropagationAiTab({
    required this.id,
    required this.title,
    required this.items,
  });

  factory _PropagationAiTab.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'];
    final items = itemsJson is List
        ? itemsJson
            .whereType<Map>()
            .map((item) => _PropagationAiItem.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.label.isNotEmpty)
            .take(4)
            .toList()
        : <_PropagationAiItem>[];
    return _PropagationAiTab(
      id: _shortText(json['id'], fallback: 'tab', maxLength: 20),
      title: _shortText(json['title'], fallback: '解读', maxLength: 8),
      items: items,
    );
  }
}

class _PropagationAiItem {
  final String label;
  final String value;
  final String detail;
  final String level;

  const _PropagationAiItem({
    required this.label,
    required this.value,
    required this.detail,
    required this.level,
  });

  factory _PropagationAiItem.fromJson(Map<String, dynamic> json) {
    return _PropagationAiItem(
      label: _shortText(json['label'], fallback: '结论', maxLength: 12),
      value: _shortText(json['value'], fallback: '参考', maxLength: 40),
      detail: _shortText(json['detail'], fallback: '', maxLength: 120),
      level: _normalizeAiLevel(json['level']),
    );
  }
}

String _shortText(
  Object? value, {
  required String fallback,
  required int maxLength,
}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return fallback;
  return text.length <= maxLength ? text : '${text.substring(0, maxLength)}...';
}

String _normalizeAiLevel(Object? value) {
  final text = value?.toString().trim().toLowerCase();
  if (text == 'good' || text == 'poor' || text == 'alert') return text!;
  return 'fair';
}

class _SectionFilterSheet extends StatefulWidget {
  final Set<_PropagationSection> selected;

  const _SectionFilterSheet({required this.selected});

  @override
  State<_SectionFilterSheet> createState() => _SectionFilterSheetState();
}

class _SectionFilterSheetState extends State<_SectionFilterSheet> {
  late Set<_PropagationSection> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<_PropagationSection>.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '筛选展示',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selected = Set<_PropagationSection>.of(
                          _defaultPropagationSections);
                    });
                  },
                  child: const Text('常用'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selected = Set<_PropagationSection>.of(
                        _allPropagationSections,
                      );
                    });
                  },
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selected = _allPropagationSections
                          .where((section) => !_selected.contains(section))
                          .toSet();
                    });
                  },
                  child: const Text('反选'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '默认展示常用传播数据，其它数据可按需打开。',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final section in _allPropagationSections)
                    CheckboxListTile(
                      value: _selected.contains(section),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(section);
                          } else {
                            _selected.remove(section);
                          }
                        });
                      },
                      title: Text(_sectionLabel(section)),
                      subtitle: Text(_sectionDescription(section)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('应用'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final SolarActivity activity;

  const _SourceCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = activity.sourceName.isEmpty ? 'HamQSL' : activity.sourceName;
    final sourceUrl = activity.sourceUrl.isEmpty
        ? SolarActivityService.sourceUrl
        : activity.sourceUrl;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.dataset_linked_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '国际参考数据：$name / HamQSL Solar XML',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '更新时间：${_value(activity.updated)}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(sourceUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开数据源'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SepcDailyReportPanel extends StatelessWidget {
  final SepcDailyReport? report;
  final String? error;
  final VoidCallback onOpenSource;

  const _SepcDailyReportPanel({
    required this.report,
    required this.error,
    required this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final report = this.report;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.article_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  report?.title ?? '过去24小时空间环境综述',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (report != null) ...[
            Text(
              report.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.55,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: '数据源', value: report.sourceName),
                if (report.issuedAt.isNotEmpty)
                  _MetaChip(label: '发布时间', value: report.issuedAt),
                if (report.forecaster.isNotEmpty)
                  _MetaChip(label: '预报员', value: report.forecaster),
              ],
            ),
          ] else
            _MessagePanel(
              message: error ?? 'SEPC 综述暂不可用',
              error: true,
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpenSource,
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开 SEPC 日报'),
          ),
        ],
      ),
    );
  }
}

class _SepcSolarImagePanel extends StatelessWidget {
  final SepcDailyReport? report;

  const _SepcSolarImagePanel({required this.report});

  @override
  Widget build(BuildContext context) {
    final images = report?.imageBase64List ?? const <String>[];
    return _Panel(
      title: '太阳照片',
      icon: Icons.image_outlined,
      child: images.isEmpty
          ? const Text('暂无太阳照片')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SepcImageStrip(images: images),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (report?.sourceName.isNotEmpty == true)
                      _MetaChip(label: '数据源', value: report!.sourceName),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SepcForecastPanel extends StatelessWidget {
  final SepcDailyReport? report;
  final String? error;

  const _SepcForecastPanel({
    required this.report,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    final forecast = report?.forecast.trim() ?? '';
    return _Panel(
      title: '未来三天空间环境预报',
      icon: Icons.online_prediction_outlined,
      child: report == null || forecast.isEmpty
          ? _MessagePanel(
              message: error ?? 'SEPC 未来三天预报暂不可用',
              error: true,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forecast,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(label: '数据源', value: report.sourceName),
                    if (report.issuedAt.isNotEmpty)
                      _MetaChip(label: '发布时间', value: report.issuedAt),
                    if (report.forecaster.isNotEmpty)
                      _MetaChip(label: '预报员', value: report.forecaster),
                  ],
                ),
              ],
            ),
    );
  }
}

class _KIndexTrendPanel extends StatelessWidget {
  final SepcKIndexReport? report;
  final String? error;

  const _KIndexTrendPanel({
    required this.report,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    final scheme = Theme.of(context).colorScheme;
    final series = report?._preferredSeries;
    final points =
        series?.points.where((point) => point.value != null).toList();
    return _Panel(
      title: '地磁 K 指数趋势',
      icon: Icons.show_chart,
      child: report == null ||
              series == null ||
              points == null ||
              points.isEmpty
          ? _MessagePanel(
              message: error ?? 'SEPC K 指数趋势暂不可用',
              error: true,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(label: '数据源', value: report.sourceName),
                    _MetaChip(label: '序列', value: series.name),
                    if (report.latestValue != null)
                      _MetaChip(
                          label: '最新值', value: 'Kp=${report.latestValue}'),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: 9,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final point = points[group.x.toInt()];
                            return BarTooltipItem(
                              '${point.time}\nKp=${point.value}',
                              TextStyle(
                                color: scheme.onInverseSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            );
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 3,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: scheme.outlineVariant,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 3,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 ||
                                  value == 3 ||
                                  value == 6 ||
                                  value == 9) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              final interval =
                                  (points.length / 4).ceil().clamp(1, 8);
                              if (index % interval != 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: SizedBox(
                                  width: 42,
                                  child: Text(
                                    _shortKIndexTime(points[index].time),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 10,
                                      height: 1.05,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var index = 0; index < points.length; index++)
                          BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: points[index].value!.toDouble(),
                                width: 8,
                                borderRadius: BorderRadius.circular(3),
                                color: _kpColor(points[index].value!, scheme),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LongTermForecastPanel extends StatelessWidget {
  final List<SepcLongTermForecast> forecasts;
  final String? error;
  final VoidCallback onRetry;

  const _LongTermForecastPanel({
    required this.forecasts,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final usable = forecasts
        .where((item) =>
            item.points.any((point) => point.observed != null) ||
            item.points.any((point) => point.predicted != null))
        .toList();
    return _Panel(
      title: '未来27天 F10.7 / Ap',
      icon: Icons.timeline_outlined,
      child: usable.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MessagePanel(
                  message: error ?? '正在加载 SEPC 未来27天预报',
                  error: error != null,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(label: '数据源', value: usable.first.sourceName),
                    const _MetaChip(label: '范围', value: '未来27天'),
                    for (final item in usable)
                      if (item.latestPredictedPoint != null)
                        _MetaChip(
                          label: _forecastKindLabel(item.kind),
                          value:
                              '${item.latestPredictedPoint!.dateLabel} ${_formatNumber(item.latestPredictedPoint!.predicted)}',
                        ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final item in usable) ...[
                  _ForecastLineChart(forecast: item),
                  if (item != usable.last) const SizedBox(height: 14),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(SepcLongTermForecastService.f107PageUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('F10.7 来源'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(SepcLongTermForecastService.apPageUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ap 来源'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ForecastLineChart extends StatelessWidget {
  final SepcLongTermForecast forecast;

  const _ForecastLineChart({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = forecast.points;
    final observedSpots = <FlSpot>[
      for (var index = 0; index < points.length; index++)
        if (points[index].observed != null)
          FlSpot(index.toDouble(), points[index].observed!),
    ];
    final predictedSpots = <FlSpot>[
      for (var index = 0; index < points.length; index++)
        if (points[index].predicted != null)
          FlSpot(index.toDouble(), points[index].predicted!),
    ];
    final values = [
      ...observedSpots.map((spot) => spot.y),
      ...predictedSpots.map((spot) => spot.y),
    ];
    final minValue = forecast.minY ?? values.reduce((a, b) => a < b ? a : b);
    final maxValue = forecast.maxY ?? values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxValue - minValue) * 0.12).clamp(2, 20).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _forecastKindTitle(forecast.kind),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: minValue - padding,
              maxY: maxValue + padding,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (items) {
                    return items.map((item) {
                      final index = item.x.toInt().clamp(0, points.length - 1);
                      final name = item.barIndex == 0 ? '实测' : '预测';
                      return LineTooltipItem(
                        '${points[index].dateLabel}\n$name ${_formatNumber(item.y)}',
                        TextStyle(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: scheme.outlineVariant,
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (value) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (value, meta) => Text(
                      _formatNumber(value),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final interval = (points.length / 5).ceil().clamp(1, 12);
                      if (index % interval != 0 && index != points.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SizedBox(
                          width: 38,
                          child: Text(
                            points[index].dateLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: observedSpots,
                  isCurved: false,
                  color: scheme.error,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: predictedSpots,
                  isCurved: false,
                  color: scheme.primary,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _LegendDot(label: '实测', color: scheme.error),
            _LegendDot(label: '预测', color: scheme.primary),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _Fof2Panel extends StatelessWidget {
  final SepcFof2Report? report;
  final String? error;
  final SepcFof2Station station;
  final ValueChanged<SepcFof2Station> onStationChanged;
  final VoidCallback onRetry;

  const _Fof2Panel({
    required this.report,
    required this.error,
    required this.station,
    required this.onStationChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    return _Panel(
      title: '电离层临界频率 foF2',
      icon: Icons.multiline_chart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<SepcFof2Station>(
                  initialValue: station,
                  decoration: const InputDecoration(
                    labelText: '台站',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final item in SepcFof2Service.stations)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onStationChanged(value);
                  },
                ),
              ),
              if (report?.latestPoint != null)
                _MetaChip(
                  label: '最新 foF2',
                  value: '${_formatNumber(report!.latestPoint!.value)} MHz',
                ),
              if (report != null)
                _MetaChip(label: '数据源', value: report.sourceName),
            ],
          ),
          const SizedBox(height: 12),
          if (report == null || report.points.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MessagePanel(
                  message: error ?? '正在加载 SEPC foF2 数据',
                  error: error != null,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            )
          else ...[
            _Fof2LineChart(report: report),
            const SizedBox(height: 10),
            Text(
              'foF2 为 F2 层临界频率，是判断短波可用频率的重要参考。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(report.sourceUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('打开 SEPC foF2 页面'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SolarEventPanel extends StatelessWidget {
  final SepcSolarFlareReport? flareReport;
  final String? flareError;
  final SepcSidReport? sidReport;
  final String? sidError;
  final VoidCallback onRetry;

  const _SolarEventPanel({
    required this.flareReport,
    required this.flareError,
    required this.sidReport,
    required this.sidError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final flareEvents = flareReport?.events.take(6).toList() ?? const [];
    final sidEvents = sidReport?.events.take(5).toList() ?? const [];
    return _Panel(
      title: '太阳耀斑与电离层骚扰',
      icon: Icons.flash_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (flareReport != null)
                _MetaChip(label: '耀斑源', value: flareReport!.sourceName),
              if (sidReport != null)
                _MetaChip(label: 'SID源', value: sidReport!.sourceName),
              const _MetaChip(label: '用途', value: '短波吸收/中断参考'),
            ],
          ),
          const SizedBox(height: 12),
          const _SubsectionTitle(
            icon: Icons.timeline_outlined,
            label: 'X 射线耀斑事件',
          ),
          const SizedBox(height: 8),
          if (flareEvents.isEmpty)
            _SoftMessagePanel(
              icon: Icons.check_circle_outline,
              message: flareError == null
                  ? '暂无近期 X 射线耀斑事件'
                  : 'X 射线耀斑事件暂不可用：$flareError',
            )
          else
            Column(
              children: [
                for (final event in flareEvents)
                  _SolarFlareEventRow(event: event),
              ],
            ),
          const SizedBox(height: 14),
          const _SubsectionTitle(
            icon: Icons.waves_outlined,
            label: '电离层突然骚扰 SID',
          ),
          const SizedBox(height: 8),
          if (sidEvents.isEmpty)
            _SoftMessagePanel(
              icon: Icons.info_outline,
              message:
                  sidError == null ? '暂无近期电离层突然骚扰事件' : 'SID 事件暂不可用：$sidError',
            )
          else
            Column(
              children: [
                for (final event in sidEvents) _SidEventRow(event: event),
              ],
            ),
          if (flareError != null || sidError != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试事件数据'),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(SepcSolarEventService.sxrSourceUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('打开耀斑页面'),
              ),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(SepcSolarEventService.sidSourceUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('打开 SID 页面'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SolarFlareEventRow extends StatelessWidget {
  final SepcSolarFlareEvent event;

  const _SolarFlareEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _flareColor(event.level, scheme);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              event.level,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatMonthDayHour(event.startTime)} - ${_formatHourMinute(event.endTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '持续 ${_formatDuration(event.duration)} · CR${event.rotation}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidEventRow extends StatelessWidget {
  final SepcSidEvent event;

  const _SidEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _flareColor(event.level, scheme);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '峰值时间 ${_formatMonthDayHour(event.peakTime)} UTC',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '查看 SID 影响图',
            onPressed: () => launchUrl(
              Uri.parse(event.mapUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
    );
  }
}

class _Fof2LineChart extends StatelessWidget {
  final SepcFof2Report report;

  const _Fof2LineChart({required this.report});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = _downsampleFof2(report.points, maxPoints: 260);
    final spots = <FlSpot>[
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), points[index].value),
    ];
    final values = spots.map((spot) => spot.y).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxValue - minValue) * 0.15).clamp(0.6, 3).toDouble();
    return SizedBox(
      height: 210,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: (minValue - padding).clamp(0, 30).toDouble(),
          maxY: (maxValue + padding).clamp(1, 30).toDouble(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (items) {
                return items.map((item) {
                  final index = item.x.toInt().clamp(0, points.length - 1);
                  final point = points[index];
                  return LineTooltipItem(
                    '${_formatMonthDayHour(point.time)}\nfoF2 ${_formatNumber(point.value)} MHz',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.outlineVariant,
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Text(
                  _formatNumber(value),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final interval = (points.length / 5).ceil().clamp(1, 64);
                  if (index % interval != 0 && index != points.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 42,
                      child: Text(
                        _formatMonthDay(points[index].time),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: scheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmeDegradationPanel extends StatelessWidget {
  final EmeDegradationReport? report;

  const _EmeDegradationPanel({required this.report});

  @override
  Widget build(BuildContext context) {
    final report = this.report ?? EmeDegradationService().calculate();
    final scheme = Theme.of(context).colorScheme;
    final levelColor = _emeLevelColor(report.level, scheme);
    return _Panel(
      title: 'EME 月面反射退化',
      icon: Icons.nights_stay_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: '数据源', value: report.sourceName),
              _MetaChip(label: 'EME', value: _emeLevelLabel(report.level)),
              _MetaChip(
                label: '月地距离',
                value: '${report.moonDistanceKm.round()} km',
              ),
              _MetaChip(
                label: '退化',
                value: '${_formatNumber(report.totalDegradationDb)} dB',
              ),
              if (report.frequencyMhz != null)
                _MetaChip(
                  label: '频率',
                  value: '${_formatNumber(report.frequencyMhz)} MHz',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _EmeMetricCard(
                  label: '条件',
                  value: _emeLevelLabel(report.level),
                  description:
                      '${_emeLevelEnglishLabel(report.level)} · ${_formatNumber(report.totalDegradationDb)} dB',
                  accentColor: levelColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EmeMetricCard(
                  label: '距离项',
                  value: '${_formatNumber(report.rangeDegradationDb)} dB',
                  description: '双程路径损耗变化',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _EmeMetricCard(
                  label: '天空噪声项',
                  value: '${_formatNumber(report.skyNoiseDegradationDb)} dB',
                  description: report.skyTemperatureK == null
                      ? '银河背景估算'
                      : '${report.skyTemperatureK!.round()} K',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '当前为模型估算，包含月地距离导致的 EME 双程路径损耗退化，并叠加低分辨率银河背景天空噪声近似项。后续可替换为 Haslam 408 MHz 降采样天空图。适用于判断月面反射通信条件趋势，不代表普通短波传播。',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (report.galacticLatitudeDeg != null) ...[
            const SizedBox(height: 8),
            Text(
              '月亮方向银河纬度 ${_formatNumber(report.galacticLatitudeDeg)}° · Tsys ${_formatNumber(report.systemNoiseTemperatureK)} K',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmeMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  final Color? accentColor;

  const _EmeMetricCard({
    required this.label,
    required this.value,
    required this.description,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accentColor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color == null ? scheme.surface : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color ?? scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _IonospherePanel extends StatelessWidget {
  final SepcIonosphereImage? image;
  final String? error;
  final SepcIonosphereStation station;
  final SepcIonosphereProduct product;
  final DateTime date;
  final ValueChanged<SepcIonosphereStation> onStationChanged;
  final ValueChanged<SepcIonosphereProduct> onProductChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onRetry;

  const _IonospherePanel({
    required this.image,
    required this.error,
    required this.station,
    required this.product,
    required this.date,
    required this.onStationChanged,
    required this.onProductChanged,
    required this.onDateChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Panel(
      title: 'SEPC 电离层闪烁 / TEC',
      icon: Icons.blur_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<SepcIonosphereStation>(
                  initialValue: station,
                  decoration: const InputDecoration(
                    labelText: '台站',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final item in SepcIonosphereService.stations)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onStationChanged(value);
                  },
                ),
              ),
              SegmentedButton<SepcIonosphereProduct>(
                segments: const [
                  ButtonSegment(
                    value: SepcIonosphereProduct.scintillation,
                    icon: Icon(Icons.scatter_plot_outlined),
                    label: Text('闪烁'),
                  ),
                  ButtonSegment(
                    value: SepcIonosphereProduct.tec,
                    icon: Icon(Icons.map_outlined),
                    label: Text('TEC'),
                  ),
                ],
                selected: {product},
                onSelectionChanged: (values) {
                  if (values.isNotEmpty) onProductChanged(values.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.outlined(
                tooltip: '前一天',
                onPressed: () =>
                    onDateChanged(date.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    _formatDate(date),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: '后一天',
                onPressed: _isSameDate(date, DateTime.now())
                    ? null
                    : () => onDateChanged(date.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (image == null)
            _MessagePanel(
              message: error ?? '正在加载 SEPC 电离层产品',
              error: error != null,
            )
          else
            _IonosphereImageView(image: image!),
          if (error != null && image == null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ],
      ),
    );
  }
}

class _IonosphereImageView extends StatelessWidget {
  final SepcIonosphereImage image;

  const _IonosphereImageView({required this.image});

  Future<void> _saveImage(BuildContext context) async {
    await _saveNetworkImage(
      context: context,
      imageUrl: image.imageUrl,
      filename:
          'sepc_ionosphere_${image.station.code}_${image.product.name}_${_compactDate(image.date)}.png',
    );
  }

  void _openPreview(BuildContext context) {
    _openNetworkImagePreview(
      context: context,
      title:
          '${image.station.name} · ${_ionosphereProductLabel(image.product)} · ${_formatDate(image.date)}',
      imageUrl: image.imageUrl,
      onSave: () => _saveImage(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final productLabel = _ionosphereProductLabel(image.product);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaChip(label: '数据源', value: image.sourceName),
            _MetaChip(label: '产品', value: productLabel),
            _MetaChip(label: '台站', value: image.station.name),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '点击放大查看，长按图片保存',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final imageWidth = constraints.maxWidth;
            return GestureDetector(
              onTap: () => _openPreview(context),
              onLongPress: () => _saveImage(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  height: imageWidth * 450 / 680,
                  constraints: const BoxConstraints(minHeight: 180),
                  color: scheme.surfaceContainerHighest,
                  child: Image.network(
                    image.imageUrl,
                    fit: BoxFit.contain,
                    headers: const {'User-Agent': 'Mozilla/5.0'},
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(image.sourceUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('打开 SEPC 电离层页面'),
        ),
      ],
    );
  }
}

class _TecMapPanel extends StatelessWidget {
  final SepcTecMapReport? report;
  final String? error;
  final VoidCallback onRetry;

  const _TecMapPanel({
    required this.report,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    return _Panel(
      title: 'SEPC TEC 同化模型',
      icon: Icons.grid_on_outlined,
      child: report == null || report.images.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MessagePanel(
                  message: error ?? '正在加载 SEPC TEC 同化模型',
                  error: error != null,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(label: '数据源', value: report.sourceName),
                    const _MetaChip(label: '范围', value: '中国及周边区域'),
                    const _MetaChip(label: '更新', value: '约15分钟'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '点击图片放大查看，长按保存',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var index = 0;
                              index < report.images.length;
                              index++) ...[
                            if (index > 0) const SizedBox(width: 10),
                            Expanded(
                              child: _TecMapImageTile(
                                image: report.images[index],
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                    return Column(
                      children: [
                        for (final image in report.images) ...[
                          _TecMapImageTile(
                            image: image,
                          ),
                          if (image != report.images.last)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(report.sourceUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开 SEPC TEC 页面'),
                ),
              ],
            ),
    );
  }
}

class _TecMapImageTile extends StatelessWidget {
  final SepcTecMapImage image;

  const _TecMapImageTile({required this.image});

  Future<void> _saveImage(BuildContext context) async {
    await _saveNetworkImage(
      context: context,
      imageUrl: image.imageUrl,
      filename:
          'sepc_tec_map_${image.product.name}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
  }

  void _openPreview(BuildContext context) {
    _openNetworkImagePreview(
      context: context,
      title: image.title,
      imageUrl: image.imageUrl,
      onSave: () => _saveImage(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          image.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onTap: () => _openPreview(context),
              onLongPress: () => _saveImage(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  height: width * 420 / 650,
                  constraints: const BoxConstraints(minHeight: 170),
                  color: scheme.surfaceContainerHighest,
                  child: Image.network(
                    image.imageUrl,
                    fit: BoxFit.contain,
                    headers: const {'User-Agent': 'Mozilla/5.0'},
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SepcImageStrip extends StatelessWidget {
  final List<String> images;

  const _SepcImageStrip({required this.images});

  Future<void> _saveImage(BuildContext context, int index) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      final bytes = base64Decode(images[index]);
      if (bytes.isEmpty) throw const FormatException('图片数据为空');
      final directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final filename =
          'sepc_space_weather_${index + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${directory.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(bytes);
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('图片已保存到 ${file.path}')));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('保存图片失败: $e'), backgroundColor: errorColor),
      );
    }
  }

  void _openPreview(BuildContext context, int index) {
    final bytes = base64Decode(images[index]);
    showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Dialog.fullscreen(
          backgroundColor: scheme.surface,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          '太阳照片 ${index + 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: '保存图片',
                        onPressed: () => _saveImage(context, index),
                        icon: const Icon(Icons.download_outlined),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onLongPress: () => _saveImage(context, index),
                    child: InteractiveViewer(
                      minScale: 0.7,
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.swipe, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              '点击图片放大查看，长按保存',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openPreview(context, index),
                onLongPress: () => _saveImage(context, index),
                child: Container(
                  width: 144,
                  height: 144,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerHighest,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ClipOval(
                    child: Image.memory(
                      base64Decode(images[index]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '横向滑动查看更多',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label：$value',
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final SolarActivity activity;

  const _MetricGrid({required this.activity});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Metric('太阳通量', activity.solarFlux, 'SFI / F10.7'),
      _Metric('地磁 A 指数', activity.aIndex, '日尺度扰动'),
      _Metric('地磁 Kp', activity.kIndex, '三小时指数'),
      _Metric('太阳黑子', activity.sunspots, '黑子数'),
      _Metric('太阳风', activity.solarWind, 'km/s'),
      _Metric('行星际磁场', activity.magneticField, 'nT'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 112,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: items[index]),
        );
      },
    );
  }
}

class _HfConditionPanel extends StatelessWidget {
  final List<SolarBandCondition> conditions;

  const _HfConditionPanel({required this.conditions});

  @override
  Widget build(BuildContext context) {
    final day = conditions.where((item) => item.time == 'day').toList();
    final night = conditions.where((item) => item.time == 'night').toList();
    return _Panel(
      title: '短波传播条件',
      icon: Icons.public,
      child: Column(
        children: [
          _BandColumn(title: '白天', items: day),
          const SizedBox(height: 12),
          _BandColumn(title: '夜间', items: night),
        ],
      ),
    );
  }
}

class _VhfConditionPanel extends StatelessWidget {
  final List<SolarVhfCondition> conditions;

  const _VhfConditionPanel({required this.conditions});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '甚高频现象',
      icon: Icons.radar_outlined,
      child: conditions.isEmpty
          ? const Text('暂无甚高频报告')
          : Column(
              children: [
                for (final item in conditions)
                  _ConditionRow(
                    title: '${_locationLabel(item.location)} · ${item.name}',
                    value: item.condition,
                  ),
              ],
            ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final SolarActivity activity;

  const _DetailPanel({required this.activity});

  @override
  Widget build(BuildContext context) {
    final details = [
      _Metric('夜间 K 指数', activity.kIndexNt, '夜间报告'),
      _Metric('极光', activity.aurora, '极光指数'),
      _Metric('质子通量', activity.protonFlux, '高能质子'),
      _Metric('电子通量', activity.electronFlux, '高能电子'),
      _Metric('氦线', activity.heliumLine, '太阳谱线'),
      _Metric('归一化', activity.normalization, '参考值'),
      _Metric('纬度', activity.latDegree, '影响范围'),
      _Metric('foF2', activity.fof2, '临界频率'),
      _Metric('MUF 因子', activity.mufFactor, '最高可用频率'),
    ];
    return _Panel(
      title: '更多太阳活动数据',
      icon: Icons.table_chart_outlined,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in details)
            _DetailChip(label: item.label, value: item.value),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BandColumn extends StatelessWidget {
  final String title;
  final List<SolarBandCondition> items;

  const _BandColumn({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('暂无报告')
        else
          for (final item in items)
            _ConditionRow(title: item.band, value: item.condition),
      ],
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final String title;
  final String value;

  const _ConditionRow({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _conditionColor(value, scheme);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _conditionLabel(value),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            _value(metric.value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(
            metric.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatusChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text('$label $value'),
      backgroundColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        color: scheme.onPrimaryContainer,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide.none,
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;

  const _DetailChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _value(value),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubsectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SubsectionTitle({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final String message;
  final bool error;

  const _MessagePanel({
    required this.message,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: error ? scheme.onErrorContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SoftMessagePanel extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SoftMessagePanel({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 46),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final String description;

  const _Metric(this.label, this.value, this.description);
}

Color _conditionColor(String value, ColorScheme scheme) {
  final normalized = value.toLowerCase();
  if (normalized.contains('good') || normalized.contains('open')) {
    return Colors.green;
  }
  if (normalized.contains('fair')) {
    return Colors.orange;
  }
  if (normalized.contains('poor') || normalized.contains('closed')) {
    return scheme.error;
  }
  return scheme.primary;
}

String _conditionLabel(String value) {
  switch (value.toLowerCase()) {
    case 'good':
      return '良好';
    case 'fair':
      return '一般';
    case 'poor':
      return '较差';
    case 'band closed':
      return '关闭';
    default:
      return _value(value);
  }
}

String _locationLabel(String value) {
  switch (value) {
    case 'northern_hemi':
      return '北半球';
    case 'north_america':
      return '北美';
    case 'europe':
      return '欧洲';
    case 'europe_6m':
      return '欧洲 6m';
    case 'europe_4m':
      return '欧洲 4m';
    default:
      return value.replaceAll('_', ' ');
  }
}

String _shortKIndexTime(String value) {
  final parts = value.split(' ');
  if (parts.length < 2) return value;
  final date = parts.first.split('/');
  final time = parts.last;
  if (date.length < 3) return time;
  return '${date[1]}/${date[2]}\n${time.substring(0, 2)}时';
}

String _formatDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _compactDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year$month$day';
}

String _formatMonthDay(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month-$day';
}

String _formatMonthDayHour(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}

String _formatHourMinute(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDuration(Duration value) {
  if (value.inMinutes < 1) return '小于1分钟';
  if (value.inHours < 1) return '${value.inMinutes}分钟';
  final minutes = value.inMinutes.remainder(60);
  if (minutes == 0) return '${value.inHours}小时';
  return '${value.inHours}小时$minutes分钟';
}

List<SepcFof2Point> _downsampleFof2(
  List<SepcFof2Point> points, {
  required int maxPoints,
}) {
  if (points.length <= maxPoints) return points;
  final step = points.length / maxPoints;
  return [
    for (var index = 0; index < maxPoints; index++)
      points[(index * step).floor().clamp(0, points.length - 1)],
  ];
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

Future<void> _saveNetworkImage({
  required BuildContext context,
  required String imageUrl,
  required String filename,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final errorColor = Theme.of(context).colorScheme.error;
  try {
    final request = await HttpClient().getUrl(Uri.parse(imageUrl));
    request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw FormatException('图片下载返回 HTTP ${response.statusCode}');
    }
    final bytes = await consolidateHttpClientResponseBytes(response);
    final directory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes);
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('图片已保存到 ${file.path}')));
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('保存图片失败: $e'), backgroundColor: errorColor),
    );
  }
}

void _openNetworkImagePreview({
  required BuildContext context,
  required String title,
  required String imageUrl,
  required VoidCallback onSave,
}) {
  showDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Dialog.fullscreen(
        backgroundColor: scheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                    IconButton(
                      tooltip: '保存图片',
                      onPressed: onSave,
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onLongPress: onSave,
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 5,
                    child: Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        headers: const {'User-Agent': 'Mozilla/5.0'},
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _ionosphereProductLabel(SepcIonosphereProduct product) {
  return product == SepcIonosphereProduct.scintillation ? '电离层闪烁' : 'TEC';
}

String _forecastKindLabel(SepcForecastKind kind) {
  return kind == SepcForecastKind.f107 ? 'F10.7' : 'Ap';
}

String _forecastKindTitle(SepcForecastKind kind) {
  return kind == SepcForecastKind.f107 ? '未来27天 F10.7 太阳射电流量' : '未来27天 Ap 地磁指数';
}

String _sectionLabel(_PropagationSection section) {
  switch (section) {
    case _PropagationSection.source:
      return '国际参考数据';
    case _PropagationSection.solarImages:
      return '太阳照片';
    case _PropagationSection.dailyReport:
      return '过去24小时综述';
    case _PropagationSection.threeDayForecast:
      return '未来三天预报';
    case _PropagationSection.kIndex:
      return '地磁 K 指数趋势';
    case _PropagationSection.longTermForecast:
      return '未来27天 F10.7 / Ap';
    case _PropagationSection.solarEvents:
      return '耀斑与 SID';
    case _PropagationSection.emeDegradation:
      return 'EME 月面反射退化';
    case _PropagationSection.fof2:
      return 'foF2 临界频率';
    case _PropagationSection.ionosphere:
      return '电离层闪烁 / TEC';
    case _PropagationSection.tecMap:
      return 'TEC 同化模型';
    case _PropagationSection.metrics:
      return '太阳活动指标';
    case _PropagationSection.hfConditions:
      return '短波传播条件';
    case _PropagationSection.vhfConditions:
      return '甚高频现象';
    case _PropagationSection.details:
      return '更多太阳活动数据';
  }
}

String _sectionDescription(_PropagationSection section) {
  switch (section) {
    case _PropagationSection.source:
      return 'HamQSL 国际参考源';
    case _PropagationSection.solarImages:
      return '太阳图像横向预览';
    case _PropagationSection.dailyReport:
      return '空间环境日报文本';
    case _PropagationSection.threeDayForecast:
      return '中国空间环境未来三天';
    case _PropagationSection.kIndex:
      return '地磁扰动短期趋势';
    case _PropagationSection.longTermForecast:
      return '太阳射电流量与 Ap 预报';
    case _PropagationSection.solarEvents:
      return '耀斑事件和电离层突然骚扰';
    case _PropagationSection.emeDegradation:
      return '月地距离项模型估算';
    case _PropagationSection.fof2:
      return '电离层 F2 层临界频率';
    case _PropagationSection.ionosphere:
      return '台站图像产品';
    case _PropagationSection.tecMap:
      return '中国区域 TEC 图像';
    case _PropagationSection.metrics:
      return 'SFI、Kp、太阳风等指标';
    case _PropagationSection.hfConditions:
      return '白天和夜间短波条件';
    case _PropagationSection.vhfConditions:
      return 'VHF 传播现象参考';
    case _PropagationSection.details:
      return 'HamQSL 更多字段';
  }
}

_PropagationSection? _sectionFromName(String name) {
  for (final section in _PropagationSection.values) {
    if (section.name == name) return section;
  }
  return null;
}

String _formatNumber(double? value) {
  if (value == null) return '无报告';
  if ((value - value.round()).abs() < 0.05) return value.round().toString();
  return value.toStringAsFixed(1);
}

Color _kpColor(int value, ColorScheme scheme) {
  if (value >= 7) return scheme.error;
  if (value >= 5) return Colors.orange;
  if (value >= 4) return Colors.amber.shade700;
  return Colors.green;
}

Color _flareColor(String level, ColorScheme scheme) {
  final normalized = level.trim().toUpperCase();
  if (normalized.startsWith('X')) return scheme.error;
  if (normalized.startsWith('M')) return Colors.orange;
  if (normalized.startsWith('C')) return Colors.amber.shade700;
  return scheme.primary;
}

String _emeLevelLabel(EmeDegradationLevel level) {
  switch (level) {
    case EmeDegradationLevel.good:
      return '良好';
    case EmeDegradationLevel.fair:
      return '一般';
    case EmeDegradationLevel.poor:
      return '较差';
    case EmeDegradationLevel.veryPoor:
      return '很差';
  }
}

String _emeLevelEnglishLabel(EmeDegradationLevel level) {
  switch (level) {
    case EmeDegradationLevel.good:
      return 'Good';
    case EmeDegradationLevel.fair:
      return 'Fair';
    case EmeDegradationLevel.poor:
      return 'Poor';
    case EmeDegradationLevel.veryPoor:
      return 'Very Poor';
  }
}

Color _emeLevelColor(EmeDegradationLevel level, ColorScheme scheme) {
  switch (level) {
    case EmeDegradationLevel.good:
      return Colors.green;
    case EmeDegradationLevel.fair:
      return Colors.amber.shade700;
    case EmeDegradationLevel.poor:
      return Colors.orange;
    case EmeDegradationLevel.veryPoor:
      return scheme.error;
  }
}

String _value(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.toLowerCase() == 'norpt') {
    return '无报告';
  }
  return normalized;
}

extension on SepcKIndexReport {
  SepcKIndexSeries? get _preferredSeries {
    if (series.isEmpty) return null;
    return series.firstWhere(
      (item) => item.points.any((point) => point.value != null),
      orElse: () => series.first,
    );
  }
}
