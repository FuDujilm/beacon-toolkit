import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../services/unit_converter_service.dart';
import 'radio_theme.dart';

class UnitConverterPage extends StatefulWidget {
  const UnitConverterPage({super.key});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage>
    with SingleTickerProviderStateMixin {
  final _service = const UnitConverterService();
  final Map<String, TextEditingController> _controllers = {};
  final _frequencyController = TextEditingController(text: '50');
  final _impedanceController = TextEditingController(text: '50');
  late final TabController _tabController;

  UnitConverterMode _mode = UnitConverterMode.frequency;
  String? _message;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _rebuildControllers();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    _frequencyController.dispose();
    _impedanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        title: const Text('单位换算'),
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _buildModeToggle(context),
                const SizedBox(height: 16),
                if (_mode == UnitConverterMode.fieldStrengthFluxDensity) ...[
                  _buildParameterRow(context),
                  const SizedBox(height: 18),
                ] else if (_mode == UnitConverterMode.powerVoltage) ...[
                  _buildImpedanceOnlyRow(context),
                  const SizedBox(height: 18),
                ],
                switch (_mode) {
                  UnitConverterMode.frequency => _buildFrequencyLayout(context),
                  UnitConverterMode.wavelength =>
                    _buildWavelengthLayout(context),
                  UnitConverterMode.powerVoltage =>
                    _buildPowerVoltageLayout(context),
                  UnitConverterMode.fieldStrengthFluxDensity =>
                    _buildFieldFluxLayout(context),
                },
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 18),
                _buildFormulaCard(context),
                const SizedBox(height: 16),
                Text(
                  '仅供参考，请遵守当地法规和主管部门要求。',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    final colors = radioThemeColors(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: TabBar(
            controller: _tabController,
            onTap: _onTabSelected,
            isScrollable: false,
            indicator: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: colors.accent,
            unselectedLabelColor: colors.text,
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            tabs: const [
              Tab(text: '频率'),
              Tab(text: '波长'),
              Tab(text: '电压功率'),
              Tab(text: '场强通量'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 680;
        if (stacked) {
          return Column(
            children: [
              _ParameterField(
                title: '频率',
                controller: _frequencyController,
                suffixText: 'MHz',
                onChanged: (_) => setState(() => _message = null),
              ),
              const SizedBox(height: 12),
              _ParameterField(
                title: '阻抗',
                controller: _impedanceController,
                suffixText: 'Ω',
                onChanged: (_) => setState(() => _message = null),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ParameterField(
                title: '频率',
                controller: _frequencyController,
                suffixText: 'MHz',
                onChanged: (_) => setState(() => _message = null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ParameterField(
                title: '阻抗',
                controller: _impedanceController,
                suffixText: 'Ω',
                onChanged: (_) => setState(() => _message = null),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImpedanceOnlyRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ParameterField(
            title: '阻抗',
            controller: _impedanceController,
            suffixText: 'Ω',
            onChanged: (_) => setState(() => _message = null),
          ),
        ),
      ],
    );
  }

  Widget _buildPowerVoltageLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '电压'),
        const SizedBox(height: 12),
        _buildUnitGrid(
          _service.voltageUnitsFor(),
          onChanged: _onPowerVoltageChanged,
        ),
        const SizedBox(height: 20),
        const _SectionTitle(title: '功率'),
        const SizedBox(height: 12),
        _buildUnitGrid(
          _service.powerUnitsFor(),
          onChanged: _onPowerVoltageChanged,
        ),
      ],
    );
  }

  Widget _buildFrequencyLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '频率'),
        const SizedBox(height: 12),
        _buildUnitGrid(
          _service.frequencyUnitsFor(),
          onChanged: _onFrequencyChanged,
        ),
      ],
    );
  }

  Widget _buildWavelengthLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '波长'),
        const SizedBox(height: 12),
        _buildUnitGrid(
          _service.wavelengthUnitsFor(),
          onChanged: _onWavelengthChanged,
        ),
      ],
    );
  }

  Widget _buildFieldFluxLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '场强'),
        const SizedBox(height: 12),
        _buildUnitGrid(
          _service.fieldStrengthUnitsFor(),
          onChanged: _onFieldFluxChanged,
        ),
        const SizedBox(height: 20),
        const _SectionTitle(title: '通量密度'),
        const SizedBox(height: 12),
        _buildUnitGrid(
          _service.fluxDensityUnitsFor(),
          onChanged: _onFieldFluxChanged,
        ),
        const SizedBox(height: 20),
        const _SectionTitle(title: '功率'),
        const SizedBox(height: 12),
        _buildUnitGrid(
          _service.powerUnitsFor(),
          onChanged: _onFieldFluxChanged,
        ),
      ],
    );
  }

  Widget _buildUnitGrid(
    List<UnitConverterUnit> units, {
    required ValueChanged<String> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 280 ? 2 : 1;
        final rows = <Widget>[];

        for (var index = 0; index < units.length; index += crossAxisCount) {
          final rowUnits = units.skip(index).take(crossAxisCount).toList();
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rowUnits.length; i++) ...[
                  Expanded(
                    child: _ValueInputField(
                      controller: _controllers[rowUnits[i].key]!,
                      unitLabel: rowUnits[i].label,
                      onChanged: (_) => onChanged(rowUnits[i].key),
                    ),
                  ),
                  if (i != rowUnits.length - 1) const SizedBox(width: 12),
                ],
                if (rowUnits.length < crossAxisCount)
                  const Expanded(child: SizedBox()),
              ],
            ),
          );
          if (index + crossAxisCount < units.length) {
            rows.add(const SizedBox(height: 12));
          }
        }

        return Column(children: rows);
      },
    );
  }

  Widget _buildFormulaCard(BuildContext context) {
    final colors = radioThemeColors(context);
    final formulas = _mode == UnitConverterMode.powerVoltage
        ? const [
            r'P=\frac{V^2}{R}',
            r'V=\sqrt{P\cdot R}',
            r'\mathrm{dBV}=20\log_{10}(V),\ \mathrm{dBW}=10\log_{10}(P)',
          ]
        : _mode == UnitConverterMode.fieldStrengthFluxDensity
            ? const [
                r'S=\frac{E^2}{120\pi}',
                r'P_r=S\cdot A_e,\ A_e=\frac{\lambda^2}{4\pi}\cdot\frac{R}{50}',
                r'\lambda=\frac{c}{f}',
              ]
            : const [
                r'\lambda=\frac{c}{f}',
                r'f=\frac{c}{\lambda}',
              ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '公式',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          for (final formula in formulas) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                formula,
                textStyle: TextStyle(color: colors.text, fontSize: 17),
              ),
            ),
            if (formula != formulas.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  void _switchMode(UnitConverterMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _message = null;
      _rebuildControllers();
    });
  }

  void _onTabSelected(int index) {
    final mode = switch (index) {
      0 => UnitConverterMode.frequency,
      1 => UnitConverterMode.wavelength,
      2 => UnitConverterMode.powerVoltage,
      _ => UnitConverterMode.fieldStrengthFluxDensity,
    };
    _switchMode(mode);
  }

  void _rebuildControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    if (_mode == UnitConverterMode.powerVoltage) {
      final result = _service.convertPowerVoltage(
        sourceUnitKey: 'v',
        inputValue: 13.8,
        impedanceOhms: 50,
      );
      for (final item in [...result.voltageValues, ...result.powerValues]) {
        _controllers[item.unit.key] = TextEditingController(text: item.value);
      }
      return;
    }

    if (_mode == UnitConverterMode.frequency) {
      final result = _service.convertFrequency(
        sourceUnitKey: 'mhz',
        inputValue: 145.5,
      );
      for (final item in result.values) {
        _controllers[item.unit.key] = TextEditingController(text: item.value);
      }
      return;
    }

    if (_mode == UnitConverterMode.wavelength) {
      final result = _service.convertWavelength(
        sourceUnitKey: 'm',
        inputValue: 2,
      );
      for (final item in result.values) {
        _controllers[item.unit.key] = TextEditingController(text: item.value);
      }
      return;
    }

    final result = _service.convertFieldStrengthFluxDensity(
      sourceUnitKey: 'vpm',
      inputValue: 1,
      frequencyMHz: 50,
      impedanceOhms: 50,
    );
    for (final item in [
      ...result.fieldStrengthValues,
      ...result.fluxDensityValues,
      ...result.powerValues
    ]) {
      _controllers[item.unit.key] = TextEditingController(text: item.value);
    }
  }

  void _onFrequencyChanged(String sourceUnitKey) {
    if (_syncing) return;
    final parsed = _parseInput(_controllers[sourceUnitKey]?.text ?? '');
    if (parsed == null) return;

    final result = _service.convertFrequency(
      sourceUnitKey: sourceUnitKey,
      inputValue: parsed,
    );

    _syncControllers(result.values, sourceUnitKey: sourceUnitKey);
  }

  void _onWavelengthChanged(String sourceUnitKey) {
    if (_syncing) return;
    final parsed = _parseInput(_controllers[sourceUnitKey]?.text ?? '');
    if (parsed == null) return;

    final result = _service.convertWavelength(
      sourceUnitKey: sourceUnitKey,
      inputValue: parsed,
    );

    _syncControllers(result.values, sourceUnitKey: sourceUnitKey);
  }

  void _onPowerVoltageChanged(String sourceUnitKey) {
    if (_syncing) return;
    final parsed = _parseInput(_controllers[sourceUnitKey]?.text ?? '');
    if (parsed == null) return;

    final impedance = _parsePositiveController(
      _impedanceController,
      errorMessage: '阻抗必须是大于 0 的数字',
    );
    if (impedance == null) return;

    final result = _service.convertPowerVoltage(
      sourceUnitKey: sourceUnitKey,
      inputValue: parsed,
      impedanceOhms: impedance,
    );

    _syncControllers(
      [...result.voltageValues, ...result.powerValues],
      sourceUnitKey: sourceUnitKey,
    );
  }

  void _onFieldFluxChanged(String sourceUnitKey) {
    if (_syncing) return;
    final parsed = _parseInput(_controllers[sourceUnitKey]?.text ?? '');
    if (parsed == null) return;

    final frequencyMHz = _parsePositiveController(
      _frequencyController,
      errorMessage: '频率必须是大于 0 的数字',
    );
    if (frequencyMHz == null) return;

    final impedance = _parsePositiveController(
      _impedanceController,
      errorMessage: '阻抗必须是大于 0 的数字',
    );
    if (impedance == null) return;

    final result = _service.convertFieldStrengthFluxDensity(
      sourceUnitKey: sourceUnitKey,
      inputValue: parsed,
      frequencyMHz: frequencyMHz,
      impedanceOhms: impedance,
    );

    _syncControllers(
      [
        ...result.fieldStrengthValues,
        ...result.fluxDensityValues,
        ...result.powerValues,
      ],
      sourceUnitKey: sourceUnitKey,
    );
  }

  double? _parseInput(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      setState(() => _message = '请输入有效数字');
      return null;
    }
    final input = double.tryParse(trimmed);
    if (input == null) {
      setState(() => _message = '请输入有效数字');
      return null;
    }
    if (input <= 0) {
      setState(() => _message = '输入值必须大于 0');
      return null;
    }
    return input;
  }

  double? _parsePositiveController(
    TextEditingController controller, {
    required String errorMessage,
  }) {
    final value = double.tryParse(controller.text.trim());
    if (value == null || value <= 0) {
      setState(() => _message = errorMessage);
      return null;
    }
    return value;
  }

  void _syncControllers(
    List<UnitConverterValue> values, {
    required String sourceUnitKey,
  }) {
    _syncing = true;
    for (final item in values) {
      if (item.unit.key == sourceUnitKey) continue;
      final controller = _controllers[item.unit.key];
      if (controller == null) continue;
      controller.value = TextEditingValue(
        text: item.value,
        selection: TextSelection.collapsed(offset: item.value.length),
      );
    }
    _syncing = false;
    setState(() => _message = null);
  }
}

class _ParameterField extends StatelessWidget {
  final String title;
  final String suffixText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _ParameterField({
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
        Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            signed: false,
            decimal: true,
          ),
          decoration: InputDecoration(
            suffixText: suffixText,
            isDense: true,
            filled: true,
            fillColor: colors.panel,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Center(
      child: Text(
        title,
        style: TextStyle(
          color: colors.text,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ValueInputField extends StatelessWidget {
  final TextEditingController controller;
  final String unitLabel;
  final ValueChanged<String> onChanged;

  const _ValueInputField({
    required this.controller,
    required this.unitLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: colors.panel,
              suffixText: unitLabel,
              suffixStyle: TextStyle(
                color: colors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            style: TextStyle(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
