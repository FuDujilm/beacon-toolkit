import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../services/intermodulation_service.dart';
import '../../services/mirror_frequency_service.dart';
import 'radio_theme.dart';

class OtherCalculatorsPage extends StatelessWidget {
  const OtherCalculatorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('其他计算器'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _CalculatorTile(
            title: '镜像频率计算器',
            subtitle: '根据信号频率、中频和注入方式计算本振与镜像频率',
            icon: Icons.compare_arrows,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MirrorFrequencyCalculatorPage(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _CalculatorTile(
            title: '互调计算器',
            subtitle: '计算双频三阶与五阶互调产物',
            icon: Icons.timeline,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IntermodulationCalculatorPage(),
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

class MirrorFrequencyCalculatorPage extends StatefulWidget {
  const MirrorFrequencyCalculatorPage({super.key});

  @override
  State<MirrorFrequencyCalculatorPage> createState() =>
      _MirrorFrequencyCalculatorPageState();
}

class _MirrorFrequencyCalculatorPageState
    extends State<MirrorFrequencyCalculatorPage> {
  final _service = const MirrorFrequencyService();
  final _signalController = TextEditingController(text: '145.500');
  final _intermediateController = TextEditingController(text: '10.700');
  bool _highSideInjection = true;
  String? _message;

  @override
  void dispose() {
    _signalController.dispose();
    _intermediateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    final result = _buildResult();

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('镜像频率计算器'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输入参数',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _LabeledInput(
                  title: '信号频率',
                  suffixText: 'MHz',
                  controller: _signalController,
                  onChanged: (_) => setState(() => _message = null),
                ),
                const SizedBox(height: 12),
                _LabeledInput(
                  title: '中频',
                  suffixText: 'MHz',
                  controller: _intermediateController,
                  onChanged: (_) => setState(() => _message = null),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('高侧注入'),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('低侧注入'),
                    ),
                  ],
                  selected: {_highSideInjection},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _highSideInjection = selection.first;
                      _message = null;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '结果',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                if (result == null)
                  Text(
                    _message ?? '请输入有效参数',
                    style: TextStyle(color: colors.muted),
                  )
                else ...[
                  _ResultRow(
                    label: '本振频率',
                    value: '${_format(result.localOscillatorMHz)} MHz',
                  ),
                  const SizedBox(height: 10),
                  _ResultRow(
                    label: '镜像频率',
                    value: '${_format(result.imageFrequencyMHz)} MHz',
                  ),
                  const SizedBox(height: 10),
                  _ResultRow(
                    label: '注入方式',
                    value: result.highSideInjection ? '高侧注入' : '低侧注入',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '公式',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _FormulaLine(
                  tex: r'f_{LO}=f_{RF}+f_{IF}',
                  color: colors.text,
                ),
                const SizedBox(height: 8),
                _FormulaLine(
                  tex: r'f_{image}=f_{RF}+2f_{IF}',
                  color: colors.text,
                ),
                const SizedBox(height: 12),
                _FormulaLine(
                  tex: r'f_{LO}=f_{RF}-f_{IF}',
                  color: colors.text,
                ),
                const SizedBox(height: 8),
                _FormulaLine(
                  tex: r'f_{image}=f_{RF}-2f_{IF}',
                  color: colors.text,
                ),
              ],
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

  MirrorFrequencyResult? _buildResult() {
    final signal = double.tryParse(_signalController.text.trim());
    final intermediate = double.tryParse(_intermediateController.text.trim());
    if (signal == null || intermediate == null) {
      _message = '请输入有效数字';
      return null;
    }
    if (signal <= 0 || intermediate <= 0) {
      _message = '频率必须大于 0';
      return null;
    }
    if (!_highSideInjection && signal <= intermediate) {
      _message = '低侧注入时，信号频率必须大于中频';
      return null;
    }
    _message = null;
    return _service.calculate(
      signalFrequencyMHz: signal,
      intermediateFrequencyMHz: intermediate,
      highSideInjection: _highSideInjection,
    );
  }

  String _format(double value) {
    final absolute = value.abs();
    if (absolute >= 1000) return value.toStringAsFixed(3);
    if (absolute >= 1) return value.toStringAsFixed(4);
    return value.toStringAsFixed(6);
  }
}

class IntermodulationCalculatorPage extends StatefulWidget {
  const IntermodulationCalculatorPage({super.key});

  @override
  State<IntermodulationCalculatorPage> createState() =>
      _IntermodulationCalculatorPageState();
}

class _IntermodulationCalculatorPageState
    extends State<IntermodulationCalculatorPage> {
  final _service = const IntermodulationService();
  final _newFrequencyController = TextEditingController();
  final List<double> _frequencies = [145.5, 146.1];
  bool _includeThirdOrder = true;
  bool _includeFifthOrder = true;
  _FocusMode _focusMode = _FocusMode.range;
  double? _focusLowerMHz;
  double? _focusUpperMHz;
  double? _focusCenterMHz;
  double? _focusBandwidthMHz;
  String? _message;

  @override
  void dispose() {
    _newFrequencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    final result = _buildResult();

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('互调计算器'),
        actions: [
          TextButton(
            onPressed: _openSettings,
            child: const Text('设置'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输入参数',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _LabeledInput(
                  title: '新增频率',
                  suffixText: 'MHz',
                  controller: _newFrequencyController,
                  onChanged: (_) => setState(() => _message = null),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addFrequency,
                        icon: const Icon(Icons.add),
                        label: const Text('添加频率'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final frequency in _frequencies)
                      InputChip(
                        label: Text('${_format(frequency)} MHz'),
                        deleteButtonTooltipMessage: '删除频率',
                        onDeleted: _frequencies.length <= 2
                            ? null
                            : () => setState(() {
                                  _frequencies.remove(frequency);
                                  _message = null;
                                }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    value: _includeThirdOrder,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('计算三阶互调'),
                    onChanged: (value) {
                      setState(() {
                        _includeThirdOrder = value ?? false;
                        _message = null;
                      });
                    },
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    value: _includeFifthOrder,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('计算五阶互调'),
                    onChanged: (value) {
                      setState(() {
                        _includeFifthOrder = value ?? false;
                        _message = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '互调产物',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                if (result == null)
                  Text(
                    _message ?? '请输入有效参数',
                    style: TextStyle(color: colors.muted),
                  )
                else ...[
                  if (_activeFocusRange != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '当前仅显示 ${_format(_activeFocusRange!.lowerMHz)} - ${_format(_activeFocusRange!.upperMHz)} MHz 范围内的互调产物',
                        style: TextStyle(color: colors.muted),
                      ),
                    ),
                  _IntermodulationTable(
                    products: result.products,
                    formatter: _format,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '公式',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _FormulaLine(
                  tex: r'f_{IM3}=2f_1\pm f_2,\ 2f_2\pm f_1',
                  color: colors.text,
                ),
                const SizedBox(height: 8),
                _FormulaLine(
                  tex: r'f_{IM5}=3f_1\pm2f_2,\ 3f_2\pm2f_1',
                  color: colors.text,
                ),
                const SizedBox(height: 14),
                Text(
                  '什么是互调：当两个或多个强信号同时进入非线性器件时，会产生原始频率之外的新频率分量。'
                  '这些产物可能正好落入接收频段，形成假信号、压制弱信号，常见于共站、前端过载、合路和功放非线性场景。',
                  style: TextStyle(
                    color: colors.muted,
                    height: 1.5,
                  ),
                ),
              ],
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

  IntermodulationResult? _buildResult() {
    if (_frequencies.length < 2) {
      _message = '至少需要两个频率';
      return null;
    }
    if (!_includeThirdOrder && !_includeFifthOrder) {
      _message = '请至少选择一个阶次';
      return null;
    }
    _message = null;
    return _service.calculate(
      inputFrequenciesMHz: _frequencies,
      includeThirdOrder: _includeThirdOrder,
      includeFifthOrder: _includeFifthOrder,
      focusRange: _activeFocusRange,
    );
  }

  IntermodulationFocusRange? get _activeFocusRange {
    if (_focusMode == _FocusMode.range) {
      if (_focusLowerMHz == null || _focusUpperMHz == null) return null;
      return IntermodulationFocusRange(
        lowerMHz: _focusLowerMHz!,
        upperMHz: _focusUpperMHz!,
      );
    }
    if (_focusCenterMHz == null || _focusBandwidthMHz == null) return null;
    final halfBandwidth = _focusBandwidthMHz! / 2;
    return IntermodulationFocusRange(
      lowerMHz: _focusCenterMHz! - halfBandwidth,
      upperMHz: _focusCenterMHz! + halfBandwidth,
    );
  }

  void _addFrequency() {
    final value = double.tryParse(_newFrequencyController.text.trim());
    if (value == null) {
      setState(() => _message = '请输入有效数字');
      return;
    }
    if (value <= 0) {
      setState(() => _message = '频率必须大于 0');
      return;
    }
    if (_frequencies.contains(value)) {
      setState(() => _message = '该频率已存在');
      return;
    }
    setState(() {
      _frequencies.add(value);
      _newFrequencyController.clear();
      _message = null;
    });
  }

  Future<void> _openSettings() async {
    final result =
        await Navigator.of(context).push<_IntermodulationSettingsResult>(
      MaterialPageRoute(
        builder: (_) => _IntermodulationSettingsPage(
          initialMode: _focusMode,
          initialLowerMHz: _focusLowerMHz,
          initialUpperMHz: _focusUpperMHz,
          initialCenterMHz: _focusCenterMHz,
          initialBandwidthMHz: _focusBandwidthMHz,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _focusMode = result.mode;
      _focusLowerMHz = result.lowerMHz;
      _focusUpperMHz = result.upperMHz;
      _focusCenterMHz = result.centerMHz;
      _focusBandwidthMHz = result.bandwidthMHz;
      _message = null;
    });
  }

  String _format(double value) {
    final absolute = value.abs();
    if (absolute >= 1000) return value.toStringAsFixed(3);
    if (absolute >= 1) return value.toStringAsFixed(4);
    return value.toStringAsFixed(6);
  }
}

enum _FocusMode { range, center }

class _IntermodulationSettingsResult {
  final _FocusMode mode;
  final double? lowerMHz;
  final double? upperMHz;
  final double? centerMHz;
  final double? bandwidthMHz;

  const _IntermodulationSettingsResult({
    required this.mode,
    this.lowerMHz,
    this.upperMHz,
    this.centerMHz,
    this.bandwidthMHz,
  });
}

class _IntermodulationSettingsPage extends StatefulWidget {
  final _FocusMode initialMode;
  final double? initialLowerMHz;
  final double? initialUpperMHz;
  final double? initialCenterMHz;
  final double? initialBandwidthMHz;

  const _IntermodulationSettingsPage({
    required this.initialMode,
    this.initialLowerMHz,
    this.initialUpperMHz,
    this.initialCenterMHz,
    this.initialBandwidthMHz,
  });

  @override
  State<_IntermodulationSettingsPage> createState() =>
      _IntermodulationSettingsPageState();
}

class _IntermodulationSettingsPageState
    extends State<_IntermodulationSettingsPage> {
  late _FocusMode _mode;
  late final TextEditingController _lowerController;
  late final TextEditingController _upperController;
  late final TextEditingController _centerController;
  late final TextEditingController _bandwidthController;
  String? _message;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _lowerController = TextEditingController(
      text: widget.initialLowerMHz?.toStringAsFixed(4) ?? '',
    );
    _upperController = TextEditingController(
      text: widget.initialUpperMHz?.toStringAsFixed(4) ?? '',
    );
    _centerController = TextEditingController(
      text: widget.initialCenterMHz?.toStringAsFixed(4) ?? '',
    );
    _bandwidthController = TextEditingController(
      text: widget.initialBandwidthMHz?.toStringAsFixed(4) ?? '',
    );
  }

  @override
  void dispose() {
    _lowerController.dispose();
    _upperController.dispose();
    _centerController.dispose();
    _bandwidthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '关注频率',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: RadioGroup<_FocusMode>(
                    groupValue: _mode,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _mode = value);
                    },
                    child: const Column(
                      children: [
                        RadioListTile<_FocusMode>(
                          value: _FocusMode.range,
                          title: Text('起止频率'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<_FocusMode>(
                          value: _FocusMode.center,
                          title: Text('中心频率'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_mode == _FocusMode.range) ...[
                  _LabeledInput(
                    title: '频率下限',
                    suffixText: 'MHz',
                    controller: _lowerController,
                    onChanged: (_) => setState(() => _message = null),
                  ),
                  const SizedBox(height: 12),
                  _LabeledInput(
                    title: '频率上限',
                    suffixText: 'MHz',
                    controller: _upperController,
                    onChanged: (_) => setState(() => _message = null),
                  ),
                ] else ...[
                  _LabeledInput(
                    title: '中心频率',
                    suffixText: 'MHz',
                    controller: _centerController,
                    onChanged: (_) => setState(() => _message = null),
                  ),
                  const SizedBox(height: 12),
                  _LabeledInput(
                    title: '带宽',
                    suffixText: 'MHz',
                    controller: _bandwidthController,
                    onChanged: (_) => setState(() => _message = null),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_mode == _FocusMode.range) {
      final lower = double.tryParse(_lowerController.text.trim());
      final upper = double.tryParse(_upperController.text.trim());
      if (lower == null || upper == null) {
        setState(() => _message = '请输入有效数字');
        return;
      }
      if (lower >= upper) {
        setState(() => _message = '频率上限必须大于下限');
        return;
      }
      Navigator.of(context).pop(
        _IntermodulationSettingsResult(
          mode: _mode,
          lowerMHz: lower,
          upperMHz: upper,
        ),
      );
      return;
    }

    final center = double.tryParse(_centerController.text.trim());
    final bandwidth = double.tryParse(_bandwidthController.text.trim());
    if (center == null || bandwidth == null) {
      setState(() => _message = '请输入有效数字');
      return;
    }
    if (bandwidth <= 0) {
      setState(() => _message = '带宽必须大于 0');
      return;
    }
    Navigator.of(context).pop(
      _IntermodulationSettingsResult(
        mode: _mode,
        centerMHz: center,
        bandwidthMHz: bandwidth,
      ),
    );
  }
}

class _IntermodulationTable extends StatelessWidget {
  final List<IntermodulationProduct> products;
  final String Function(double value) formatter;

  const _IntermodulationTable({
    required this.products,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('阶次')),
          DataColumn(label: Text('表达式')),
          DataColumn(label: Text('输入频率')),
          DataColumn(label: Text('产物')),
        ],
        rows: products.map((product) {
          return DataRow(
            cells: [
              DataCell(Text('${product.order}阶')),
              DataCell(Text(product.label)),
              DataCell(
                Text(
                  '${formatter(product.frequencyA)} / ${formatter(product.frequencyB)} MHz',
                  style: TextStyle(color: colors.muted),
                ),
              ),
              DataCell(Text('${formatter(product.frequencyMHz)} MHz')),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _CalculatorTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _CalculatorTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Material(
      color: colors.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.panelAlt,
                  borderRadius: BorderRadius.circular(10),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _LabeledInput extends StatelessWidget {
  final String title;
  final String suffixText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _LabeledInput({
    required this.title,
    required this.suffixText,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: suffixText,
            isDense: true,
            filled: true,
            fillColor: colors.panel,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colors.muted),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FormulaLine extends StatelessWidget {
  final String tex;
  final Color color;

  const _FormulaLine({
    required this.tex,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        tex,
        textStyle: TextStyle(
          color: color,
          fontSize: 20,
        ),
      ),
    );
  }
}
