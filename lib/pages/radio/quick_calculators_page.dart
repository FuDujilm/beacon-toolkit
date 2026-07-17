import 'package:flutter/material.dart';

import '../../services/quick_radio_calculator_service.dart';
import 'radio_theme.dart';

class QuickCalculatorsPage extends StatefulWidget {
  const QuickCalculatorsPage({super.key});

  @override
  State<QuickCalculatorsPage> createState() => _QuickCalculatorsPageState();
}

class _QuickCalculatorsPageState extends State<QuickCalculatorsPage>
    with SingleTickerProviderStateMixin {
  final _service = const QuickRadioCalculatorService();
  final _ohmVoltageController = TextEditingController();
  final _ohmCurrentController = TextEditingController();
  final _ohmResistanceController = TextEditingController(text: '50');
  final _ohmPowerController = TextEditingController(text: '5');

  final _powerController = TextEditingController(text: '5');
  final _swrController = TextEditingController(text: '1.5');
  late final TabController _tabController;

  _PowerInputMode _powerInputMode = _PowerInputMode.watts;
  _SwrInputMode _swrInputMode = _SwrInputMode.swr;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _ohmVoltageController.dispose();
    _ohmCurrentController.dispose();
    _ohmResistanceController.dispose();
    _ohmPowerController.dispose();
    _powerController.dispose();
    _swrController.dispose();
    _tabController.dispose();
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
        title: const Text('快速计算'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _IntroCard(),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: '欧姆定律'),
                  Tab(text: '功率 dB'),
                  Tab(text: 'SWR 回损'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 620,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOhmsLawTab(),
                  _buildPowerDbTab(),
                  _buildSwrTab(),
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
      ),
    );
  }

  Widget _buildOhmsLawTab() {
    final colors = radioThemeColors(context);
    QuickOhmsLawResult? result;
    String? message;
    try {
      result = _service.solveOhmsLaw(
        voltage: _parse(_ohmVoltageController.text),
        current: _parse(_ohmCurrentController.text),
        resistance: _parse(_ohmResistanceController.text),
        power: _parse(_ohmPowerController.text),
      );
    } catch (_) {
      message = '请至少填写两个有效量';
    }

    return _Panel(
      child: ListView(
        children: [
          Text(
            '任意填写两个量，自动补齐其余量。',
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: 14),
          _QuickInput(
            title: '电压',
            unit: 'V',
            controller: _ohmVoltageController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          _QuickInput(
            title: '电流',
            unit: 'A',
            controller: _ohmCurrentController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          _QuickInput(
            title: '电阻',
            unit: 'Ω',
            controller: _ohmResistanceController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          _QuickInput(
            title: '功率',
            unit: 'W',
            controller: _ohmPowerController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(
            '结果',
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (result == null)
            Text(message!, style: TextStyle(color: colors.muted))
          else
            _ResultGrid(
              rows: [
                ('电压', '${_format(result.voltage)} V'),
                ('电流', '${_format(result.current)} A'),
                ('电阻', '${_format(result.resistance)} Ω'),
                ('功率', '${_format(result.power)} W'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPowerDbTab() {
    final colors = radioThemeColors(context);
    QuickPowerDbResult? result;
    String? message;
    try {
      final value = _parse(_powerController.text);
      if (value == null) {
        message = '请输入有效数字';
      } else {
        result = switch (_powerInputMode) {
          _PowerInputMode.watts => _service.fromWatts(value),
          _PowerInputMode.dbm => _service.fromDbm(value),
          _PowerInputMode.dbw => _service.fromDbw(value),
        };
      }
    } catch (error) {
      message = error.toString().replaceFirst('Invalid argument(s): ', '');
    }

    return _Panel(
      child: ListView(
        children: [
          SegmentedButton<_PowerInputMode>(
            segments: const [
              ButtonSegment(
                value: _PowerInputMode.watts,
                label: Text('W'),
              ),
              ButtonSegment(
                value: _PowerInputMode.dbm,
                label: Text('dBm'),
              ),
              ButtonSegment(
                value: _PowerInputMode.dbw,
                label: Text('dBW'),
              ),
            ],
            selected: {_powerInputMode},
            onSelectionChanged: (selection) {
              setState(() => _powerInputMode = selection.first);
            },
          ),
          const SizedBox(height: 14),
          _QuickInput(
            title: '输入值',
            unit: switch (_powerInputMode) {
              _PowerInputMode.watts => 'W',
              _PowerInputMode.dbm => 'dBm',
              _PowerInputMode.dbw => 'dBW',
            },
            controller: _powerController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(
            '结果',
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (result == null)
            Text(message ?? '请输入有效数字', style: TextStyle(color: colors.muted))
          else
            _ResultGrid(
              rows: [
                ('功率', '${_format(result.watts)} W'),
                ('dBm', _format(result.dBm)),
                ('dBW', _format(result.dBw)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSwrTab() {
    final colors = radioThemeColors(context);
    QuickSwrReturnLossResult? result;
    String? message;
    try {
      final value = _parse(_swrController.text);
      if (value == null) {
        message = '请输入有效数字';
      } else {
        result = switch (_swrInputMode) {
          _SwrInputMode.swr => _service.fromSwr(value),
          _SwrInputMode.returnLoss => _service.fromReturnLoss(value),
        };
      }
    } catch (error) {
      message = error.toString().replaceFirst('Invalid argument(s): ', '');
    }

    return _Panel(
      child: ListView(
        children: [
          SegmentedButton<_SwrInputMode>(
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
            selected: {_swrInputMode},
            onSelectionChanged: (selection) {
              setState(() => _swrInputMode = selection.first);
            },
          ),
          const SizedBox(height: 14),
          _QuickInput(
            title: _swrInputMode == _SwrInputMode.swr ? 'SWR' : '回波损耗',
            unit: _swrInputMode == _SwrInputMode.swr ? '' : 'dB',
            controller: _swrController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(
            '结果',
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (result == null)
            Text(message ?? '请输入有效数字', style: TextStyle(color: colors.muted))
          else
            _ResultGrid(
              rows: [
                ('SWR', _format(result.swr)),
                (
                  '回波损耗',
                  '${result.returnLossDb.isInfinite ? '∞' : _format(result.returnLossDb)} dB'
                ),
                ('反射系数', _format(result.reflectionCoefficient)),
              ],
            ),
        ],
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
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        '把最常用的几个结果压到一个页面里，适合临时估算、抄频点和现场快速核算。',
        style: TextStyle(color: colors.muted, height: 1.5),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: child,
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
    final colors = radioThemeColors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          decoration: InputDecoration(
            suffixText: unit.isEmpty ? null : unit,
            filled: true,
            fillColor: colors.panelAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
              borderRadius: BorderRadius.circular(14),
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

enum _PowerInputMode { watts, dbm, dbw }

enum _SwrInputMode { swr, returnLoss }
