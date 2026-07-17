import 'package:flutter/material.dart';

import '../../services/transmission_line_calculator_service.dart';
import 'radio_theme.dart';

class TransmissionLineCalculatorPage extends StatelessWidget {
  const TransmissionLineCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('传输线'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _IntroCard(
            text: '把传输线计算拆成独立工具页，避免在手机上用 tab 挤压内容。',
          ),
          const SizedBox(height: 14),
          _ToolTile(
            title: '同轴损耗',
            subtitle: '按线缆型号、频率、长度和负载 SWR 估算馈线损耗',
            icon: Icons.show_chart,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoaxLossCalculatorPage()),
            ),
          ),
          const SizedBox(height: 10),
          _ToolTile(
            title: 'SWR / 回波损耗',
            subtitle: 'SWR、回波损耗、反射系数、反射功率与失配损耗互看',
            icon: Icons.compare_arrows,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SwrReturnLossCalculatorPage(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ToolTile(
            title: '电气长度换算',
            subtitle: '物理长度与电气长度双向换算，支持速度因子',
            icon: Icons.straighten,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ElectricalLengthCalculatorPage(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ToolTile(
            title: '四分之一波阻抗变换',
            subtitle: '计算 λ/4 变换段所需特性阻抗和物理长度',
            icon: Icons.tune,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const QuarterWaveTransformerCalculatorPage(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ToolTile(
            title: '同轴扼流圈匝数',
            subtitle: '按频率、目标扼流阻抗和磁环 AL 值估算最少匝数',
            icon: Icons.all_inclusive,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CoaxChokeTurnsCalculatorPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '仅供参考，请遵守当地法规和主管部门要求。',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class CoaxLossCalculatorPage extends StatefulWidget {
  const CoaxLossCalculatorPage({super.key});

  @override
  State<CoaxLossCalculatorPage> createState() => _CoaxLossCalculatorPageState();
}

class _CoaxLossCalculatorPageState extends State<CoaxLossCalculatorPage> {
  final _service = const TransmissionLineCalculatorService();
  final _frequencyController = TextEditingController(text: '145');
  final _lengthController = TextEditingController(text: '20');
  final _swrController = TextEditingController(text: '1.5');
  late final List<CoaxCablePreset> _presets;
  CoaxCablePreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _presets = _service.presets();
    _selectedPreset = _presets.first;
  }

  @override
  void dispose() {
    _frequencyController.dispose();
    _lengthController.dispose();
    _swrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    CoaxLossResult? result;
    String? message;

    try {
      final frequency = _parse(_frequencyController.text);
      final length = _parse(_lengthController.text);
      final swr = _parse(_swrController.text);
      if (frequency == null || length == null || swr == null) {
        message = '请输入有效数字';
      } else {
        result = _service.calculateCoaxLoss(
          preset: _selectedPreset!,
          frequencyMHz: frequency,
          lengthMeters: length,
          swr: swr,
        );
      }
    } catch (error) {
      message = _formatError(error);
    }

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('同轴损耗'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _IntroCard(
            text: '线缆损耗基于常见规格点插值估算，适合工程预估，不替代厂家数据表。',
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '输入参数',
            child: Column(
              children: [
                DropdownButtonFormField<CoaxCablePreset>(
                  initialValue: _selectedPreset,
                  decoration: _inputDecoration(
                    context,
                    label: '线缆类型',
                  ),
                  items: _presets
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text(
                            '${preset.label}  VF ${preset.velocityFactor}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _selectedPreset = value),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '频率',
                  unit: 'MHz',
                  controller: _frequencyController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '长度',
                  unit: 'm',
                  controller: _lengthController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '负载 SWR',
                  unit: '',
                  controller: _swrController,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ResultSection(
            title: '结果',
            message: message,
            rows: result == null
                ? null
                : [
                    (
                      '线缆衰减',
                      '${_format(result.attenuationDbPer100m)} dB / 100m'
                    ),
                    ('匹配损耗', '${_format(result.matchedLossDb)} dB'),
                    ('SWR 附加损耗', '${_format(result.additionalSwrLossDb)} dB'),
                    ('总损耗', '${_format(result.totalLossDb)} dB'),
                    ('到达负载功率', '${_format(result.deliveredPowerPercent)} %'),
                  ],
          ),
          const SizedBox(height: 12),
          Text(
            '仅供参考，请遵守当地法规和主管部门要求。',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class SwrReturnLossCalculatorPage extends StatefulWidget {
  const SwrReturnLossCalculatorPage({super.key});

  @override
  State<SwrReturnLossCalculatorPage> createState() =>
      _SwrReturnLossCalculatorPageState();
}

class _SwrReturnLossCalculatorPageState
    extends State<SwrReturnLossCalculatorPage> {
  final _service = const TransmissionLineCalculatorService();
  final _inputController = TextEditingController(text: '1.5');
  _SwrInputMode _inputMode = _SwrInputMode.swr;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    SwrMetricsResult? result;
    String? message;

    try {
      final input = _parse(_inputController.text);
      if (input == null) {
        message = '请输入有效数字';
      } else {
        result = switch (_inputMode) {
          _SwrInputMode.swr => _service.fromSwr(input),
          _SwrInputMode.returnLoss => _service.fromReturnLoss(input),
        };
      }
    } catch (error) {
      message = _formatError(error);
    }

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('SWR / 回波损耗'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _SectionCard(
            title: '输入参数',
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<_SwrInputMode>(
                    segments: const [
                      ButtonSegment(
                        value: _SwrInputMode.swr,
                        label: Text('SWR'),
                      ),
                      ButtonSegment(
                        value: _SwrInputMode.returnLoss,
                        label: Text('回损'),
                      ),
                    ],
                    selected: {_inputMode},
                    onSelectionChanged: (selection) {
                      setState(() => _inputMode = selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: _inputMode == _SwrInputMode.swr ? 'SWR' : '回波损耗',
                  unit: _inputMode == _SwrInputMode.swr ? '' : 'dB',
                  controller: _inputController,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ResultSection(
            title: '结果',
            message: message,
            rows: result == null
                ? null
                : [
                    ('SWR', _format(result.swr)),
                    ('回波损耗', _formatInfiniteDb(result.returnLossDb)),
                    ('反射系数', _format(result.reflectionCoefficient)),
                    ('反射功率', '${_format(result.reflectedPowerPercent)} %'),
                    ('失配损耗', '${_format(result.mismatchLossDb)} dB'),
                  ],
          ),
          const SizedBox(height: 12),
          Text(
            '仅供参考，请遵守当地法规和主管部门要求。',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class ElectricalLengthCalculatorPage extends StatefulWidget {
  const ElectricalLengthCalculatorPage({super.key});

  @override
  State<ElectricalLengthCalculatorPage> createState() =>
      _ElectricalLengthCalculatorPageState();
}

class _ElectricalLengthCalculatorPageState
    extends State<ElectricalLengthCalculatorPage> {
  final _service = const TransmissionLineCalculatorService();
  final _frequencyController = TextEditingController(text: '145');
  final _valueController = TextEditingController(text: '5');
  final _velocityFactorController = TextEditingController(text: '0.66');
  _LengthMode _lengthMode = _LengthMode.physicalToElectrical;

  @override
  void dispose() {
    _frequencyController.dispose();
    _valueController.dispose();
    _velocityFactorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    Object? result;
    String? message;

    try {
      final frequency = _parse(_frequencyController.text);
      final input = _parse(_valueController.text);
      final vf = _parse(_velocityFactorController.text);
      if (frequency == null || input == null || vf == null) {
        message = '请输入有效数字';
      } else {
        result = switch (_lengthMode) {
          _LengthMode.physicalToElectrical =>
            _service.physicalToElectricalLength(
              frequencyMHz: frequency,
              physicalLengthMeters: input,
              velocityFactor: vf,
            ),
          _LengthMode.electricalToPhysical =>
            _service.electricalToPhysicalLength(
              frequencyMHz: frequency,
              electricalDegrees: input,
              velocityFactor: vf,
            ),
        };
      }
    } catch (error) {
      message = _formatError(error);
    }

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('电气长度换算'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _SectionCard(
            title: '输入参数',
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<_LengthMode>(
                    segments: const [
                      ButtonSegment(
                        value: _LengthMode.physicalToElectrical,
                        label: Text('物理→电气'),
                      ),
                      ButtonSegment(
                        value: _LengthMode.electricalToPhysical,
                        label: Text('电气→物理'),
                      ),
                    ],
                    selected: {_lengthMode},
                    onSelectionChanged: (selection) {
                      setState(() => _lengthMode = selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '频率',
                  unit: 'MHz',
                  controller: _frequencyController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: _lengthMode == _LengthMode.physicalToElectrical
                      ? '物理长度'
                      : '电气长度',
                  unit: _lengthMode == _LengthMode.physicalToElectrical
                      ? 'm'
                      : '°',
                  controller: _valueController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '速度因子',
                  unit: '',
                  controller: _velocityFactorController,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ResultSection(
            title: '结果',
            message: message,
            rows: result == null
                ? null
                : result is PhysicalToElectricalLengthResult
                    ? [
                        ('线内波长', '${_format(result.wavelengthMeters)} m'),
                        ('电气长度', '${_format(result.electricalDegrees)} °'),
                        ('线长波数', '${_format(result.wavelengths)} λ'),
                      ]
                    : [
                        (
                          '线内波长',
                          '${_format((result as ElectricalToPhysicalLengthResult).wavelengthMeters)} m',
                        ),
                        ('物理长度', '${_format(result.physicalLengthMeters)} m'),
                        ('线长波数', '${_format(result.wavelengths)} λ'),
                      ],
          ),
          const SizedBox(height: 12),
          Text(
            '仅供参考，请遵守当地法规和主管部门要求。',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class QuarterWaveTransformerCalculatorPage extends StatefulWidget {
  const QuarterWaveTransformerCalculatorPage({super.key});

  @override
  State<QuarterWaveTransformerCalculatorPage> createState() =>
      _QuarterWaveTransformerCalculatorPageState();
}

class _QuarterWaveTransformerCalculatorPageState
    extends State<QuarterWaveTransformerCalculatorPage> {
  final _service = const TransmissionLineCalculatorService();
  final _sourceController = TextEditingController(text: '50');
  final _loadController = TextEditingController(text: '75');
  final _frequencyController = TextEditingController(text: '145');
  final _velocityFactorController = TextEditingController(text: '0.66');

  @override
  void dispose() {
    _sourceController.dispose();
    _loadController.dispose();
    _frequencyController.dispose();
    _velocityFactorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    QuarterWaveTransformerResult? result;
    String? message;

    try {
      final source = _parse(_sourceController.text);
      final load = _parse(_loadController.text);
      final frequency = _parse(_frequencyController.text);
      final vf = _parse(_velocityFactorController.text);
      if (source == null || load == null || frequency == null || vf == null) {
        message = '请输入有效数字';
      } else {
        result = _service.quarterWaveTransformer(
          sourceImpedanceOhms: source,
          loadImpedanceOhms: load,
          frequencyMHz: frequency,
          velocityFactor: vf,
        );
      }
    } catch (error) {
      message = _formatError(error);
    }

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('四分之一波阻抗变换'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _SectionCard(
            title: '输入参数',
            child: Column(
              children: [
                _QuickInput(
                  title: '源阻抗',
                  unit: 'Ω',
                  controller: _sourceController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '负载阻抗',
                  unit: 'Ω',
                  controller: _loadController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '频率',
                  unit: 'MHz',
                  controller: _frequencyController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '速度因子',
                  unit: '',
                  controller: _velocityFactorController,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ResultSection(
            title: '结果',
            message: message,
            rows: result == null
                ? null
                : [
                    (
                      '所需特性阻抗',
                      '${_format(result.requiredCharacteristicImpedanceOhms)} Ω',
                    ),
                    ('物理长度', '${_format(result.physicalLengthMeters)} m'),
                    ('电气长度', '${_format(result.electricalLengthDegrees)} °'),
                  ],
          ),
          const SizedBox(height: 12),
          Text(
            '仅供参考，请遵守当地法规和主管部门要求。',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class CoaxChokeTurnsCalculatorPage extends StatefulWidget {
  const CoaxChokeTurnsCalculatorPage({super.key});

  @override
  State<CoaxChokeTurnsCalculatorPage> createState() =>
      _CoaxChokeTurnsCalculatorPageState();
}

class _CoaxChokeTurnsCalculatorPageState
    extends State<CoaxChokeTurnsCalculatorPage> {
  final _service = const TransmissionLineCalculatorService();
  final _frequencyController = TextEditingController(text: '14.2');
  final _targetImpedanceController = TextEditingController(text: '1000');
  late final List<FerriteCorePreset> _presets;
  FerriteCorePreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _presets = _service.ferriteCorePresets();
    _selectedPreset = _presets.first;
  }

  @override
  void dispose() {
    _frequencyController.dispose();
    _targetImpedanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    ChokeTurnsResult? result;
    String? message;

    try {
      final frequency = _parse(_frequencyController.text);
      final targetImpedance = _parse(_targetImpedanceController.text);
      if (frequency == null || targetImpedance == null) {
        message = '请输入有效数字';
      } else {
        result = _service.chokeMinimumTurns(
          core: _selectedPreset!,
          frequencyMHz: frequency,
          targetChokingImpedanceOhms: targetImpedance,
        );
      }
    } catch (error) {
      message = _formatError(error);
    }

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('同轴扼流圈匝数'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _IntroCard(
            text:
                '按磁环 AL 值估算 1:1 电流型扼流圈所需最少匝数。这里按感抗目标估算，适合前期选型，不替代实测阻抗曲线。',
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '输入参数',
            child: Column(
              children: [
                DropdownButtonFormField<FerriteCorePreset>(
                  initialValue: _selectedPreset,
                  decoration: _inputDecoration(
                    context,
                    label: '磁环型号',
                  ),
                  items: _presets
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text(
                            '${preset.label}  AL ${preset.alNanohenriesPerTurnSquared.toStringAsFixed(0)} nH/T²',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _selectedPreset = value),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '建议频段：${_selectedPreset?.recommendedRange ?? '--'}',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '频率',
                  unit: 'MHz',
                  controller: _frequencyController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _QuickInput(
                  title: '目标扼流阻抗',
                  unit: 'Ω',
                  controller: _targetImpedanceController,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ResultSection(
            title: '结果',
            message: message,
            rows: result == null
                ? null
                : [
                    ('理论最小匝数', _format(result.exactTurns)),
                    ('建议整匝数', '${result.minimumWholeTurns} 匝'),
                    ('对应电感', '${_format(result.inductanceMicrohenries)} μH'),
                    ('对应感抗', '${_format(result.resultingReactanceOhms)} Ω'),
                  ],
          ),
          const SizedBox(height: 12),
          Text(
            '仅供参考，请遵守当地法规和主管部门要求。',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String text;

  const _IntroCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        text,
        style: TextStyle(color: colors.muted, height: 1.5),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? trailingLabel;
  final bool enabled;

  const _ToolTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailingLabel,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Material(
      color: colors.panel,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.panelAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (trailingLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: enabled
                        ? Colors.green.withValues(alpha: 0.12)
                        : colors.panelAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: enabled
                          ? Colors.green.withValues(alpha: 0.35)
                          : colors.border,
                    ),
                  ),
                  child: Text(
                    trailingLabel!,
                    style: TextStyle(
                      color: enabled ? Colors.green : colors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String title;
  final String? message;
  final List<(String, String)>? rows;

  const _ResultSection({
    required this.title,
    required this.message,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return _SectionCard(
      title: title,
      child: rows == null
          ? Text(
              message ?? '请输入有效参数',
              style: TextStyle(color: colors.muted),
            )
          : _ResultGrid(rows: rows!),
    );
  }
}

class _QuickInput extends StatelessWidget {
  final String title;
  final String unit;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _QuickInput({
    required this.title,
    required this.unit,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: radioThemeColors(context).text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          decoration: _inputDecoration(
            context,
            suffixText: unit.isEmpty ? null : unit,
          ),
        ),
      ],
    );
  }
}

class _ResultGrid extends StatelessWidget {
  final List<(String, String)> rows;

  const _ResultGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.panelAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  rows[i].$2,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (i != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  String? label,
  String? suffixText,
}) {
  final colors = radioThemeColors(context);
  return InputDecoration(
    labelText: label,
    suffixText: suffixText,
    isDense: true,
    filled: true,
    fillColor: colors.panelAlt,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

double? _parse(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}

String _format(double value) {
  if (value.isInfinite) return '∞';
  final absolute = value.abs();
  if (absolute >= 1000) return value.toStringAsFixed(2);
  if (absolute >= 100) return value.toStringAsFixed(3);
  if (absolute >= 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(6);
}

String _formatInfiniteDb(double value) {
  if (value.isInfinite) return '∞ dB';
  return '${_format(value)} dB';
}

String _formatError(Object error) {
  return error.toString().replaceFirst('Invalid argument(s): ', '');
}

enum _SwrInputMode { swr, returnLoss }

enum _LengthMode { physicalToElectrical, electricalToPhysical }
