import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/yagi_antenna_service.dart';
import 'radio_theme.dart';

class AntennaCalculatorPage extends StatelessWidget {
  const AntennaCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('天线计算器'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _ToolTile(
            title: '八木天线计算器',
            subtitle: '3 单元八木尺寸估算、图纸预览与切割表',
            icon: Icons.settings_input_antenna,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const YagiAntennaCalculatorPage(),
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

class YagiAntennaCalculatorPage extends StatefulWidget {
  const YagiAntennaCalculatorPage({super.key});

  @override
  State<YagiAntennaCalculatorPage> createState() =>
      _YagiAntennaCalculatorPageState();
}

class _YagiAntennaCalculatorPageState extends State<YagiAntennaCalculatorPage> {
  final _service = const YagiAntennaService();
  final _frequencyController = TextEditingController(text: '145.500');
  final _elementCountController = TextEditingController(text: '3');
  final _elementDiameterController = TextEditingController(text: '6.0');
  final _feedGapController = TextEditingController(text: '8.0');
  final _boomDiameterController = TextEditingController(text: '20.0');
  final _exportKey = GlobalKey();
  YagiMountStyle _mountStyle = YagiMountStyle.throughBoom;
  YagiDrivenElementStyle _drivenElementStyle =
      YagiDrivenElementStyle.splitDipole;
  YagiBoomMaterial _boomMaterial = YagiBoomMaterial.aluminum;
  String? _message;

  @override
  void dispose() {
    _frequencyController.dispose();
    _elementCountController.dispose();
    _elementDiameterController.dispose();
    _feedGapController.dispose();
    _boomDiameterController.dispose();
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
        title: const Text('八木天线计算器'),
        actions: [
          IconButton(
            tooltip: '保存图纸与切割表',
            onPressed: result == null ? null : () => _saveExportBoard(result),
            icon: const Icon(Icons.download_outlined),
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
                  title: '工作频率',
                  suffixText: 'MHz',
                  controller: _frequencyController,
                  onChanged: (_) => setState(() => _message = null),
                ),
                const SizedBox(height: 14),
                Text(
                  '单元数量',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _LabeledInput(
                  title:
                      '请输入 ${YagiAntennaService.minElementCount}-${YagiAntennaService.maxElementCount} 单元',
                  suffixText: '单元',
                  controller: _elementCountController,
                  onChanged: (_) => setState(() => _message = null),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledInput(
                        title: '元件直径',
                        suffixText: 'mm',
                        controller: _elementDiameterController,
                        onChanged: (_) => setState(() => _message = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledInput(
                        title: '馈电间隙',
                        suffixText: 'mm',
                        controller: _feedGapController,
                        onChanged: (_) => setState(() => _message = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LabeledInput(
                  title: 'boom 外径',
                  suffixText: 'mm',
                  controller: _boomDiameterController,
                  onChanged: (_) => setState(() => _message = null),
                ),
                const SizedBox(height: 14),
                Text(
                  '安装方式',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<YagiMountStyle>(
                  segments: const [
                    ButtonSegment<YagiMountStyle>(
                      value: YagiMountStyle.throughBoom,
                      label: Text('穿 boom'),
                    ),
                    ButtonSegment<YagiMountStyle>(
                      value: YagiMountStyle.insulatedAboveBoom,
                      label: Text('绝缘架高'),
                    ),
                  ],
                  selected: {_mountStyle},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _mountStyle = selection.first;
                      _message = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'boom 材料',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<YagiBoomMaterial>(
                  segments: const [
                    ButtonSegment<YagiBoomMaterial>(
                      value: YagiBoomMaterial.aluminum,
                      label: Text('铝合金'),
                    ),
                    ButtonSegment<YagiBoomMaterial>(
                      value: YagiBoomMaterial.fiberglass,
                      label: Text('玻纤'),
                    ),
                  ],
                  selected: {_boomMaterial},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _boomMaterial = selection.first;
                      _message = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  '振子类型',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<YagiDrivenElementStyle>(
                  segments: const [
                    ButtonSegment<YagiDrivenElementStyle>(
                      value: YagiDrivenElementStyle.splitDipole,
                      label: Text('直振子'),
                    ),
                    ButtonSegment<YagiDrivenElementStyle>(
                      value: YagiDrivenElementStyle.foldedDipole,
                      label: Text('折合振子'),
                    ),
                  ],
                  selected: {_drivenElementStyle},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _drivenElementStyle = selection.first;
                      _message = null;
                    });
                  },
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (result == null)
            _Panel(
              child: Text(
                _message ?? '请输入有效频率',
                style: TextStyle(color: colors.muted),
              ),
            )
          else
            RepaintBoundary(
              key: _exportKey,
              child: _ExportBoard(result: result),
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
                  tex: r'\lambda=\frac{c}{f}',
                  color: colors.text,
                ),
                const SizedBox(height: 8),
                _FormulaLine(
                  tex:
                      r'L_R\approx0.515\lambda,\ L_D\approx0.475\lambda,\ L_{Dir}\approx0.445\lambda',
                  color: colors.text,
                ),
                const SizedBox(height: 8),
                _FormulaLine(
                  tex:
                      r'S_{R-D}\approx0.20\lambda,\ S_{D-Dir}\approx0.15\lambda',
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

  YagiAntennaResult? _buildResult() {
    final frequency = double.tryParse(_frequencyController.text.trim());
    if (frequency == null) {
      _message = '请输入有效数字';
      return null;
    }
    if (frequency <= 0) {
      _message = '频率必须大于 0';
      return null;
    }
    final elementCount = int.tryParse(_elementCountController.text.trim());
    if (elementCount == null) {
      _message = '请输入有效单元数量';
      return null;
    }
    if (elementCount < YagiAntennaService.minElementCount ||
        elementCount > YagiAntennaService.maxElementCount) {
      _message =
          '单元数量需在 ${YagiAntennaService.minElementCount}-${YagiAntennaService.maxElementCount} 之间';
      return null;
    }
    final elementDiameter = double.tryParse(_elementDiameterController.text.trim());
    if (elementDiameter == null) {
      _message = '请输入有效元件直径';
      return null;
    }
    if (elementDiameter <= 0) {
      _message = '元件直径必须大于 0';
      return null;
    }
    final feedGap = double.tryParse(_feedGapController.text.trim());
    if (feedGap == null) {
      _message = '请输入有效馈电间隙';
      return null;
    }
    if (feedGap < 0) {
      _message = '馈电间隙不能小于 0';
      return null;
    }
    final boomDiameter = double.tryParse(_boomDiameterController.text.trim());
    if (boomDiameter == null) {
      _message = '请输入有效 boom 外径';
      return null;
    }
    if (boomDiameter <= 0) {
      _message = 'boom 外径必须大于 0';
      return null;
    }
    _message = null;
    return _service.calculate(
      frequencyMHz: frequency,
      elementCount: elementCount,
      elementDiameterMm: elementDiameter,
      feedGapMm: feedGap,
      boomDiameterMm: boomDiameter,
      mountStyle: _mountStyle,
      drivenElementStyle: _drivenElementStyle,
      boomMaterial: _boomMaterial,
    );
  }

  Future<void> _saveExportBoard(YagiAntennaResult result) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _renderLandscapeExport(result);
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('导出图片为空');
      }

      final directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final filename =
          'beacon-yagi-sheet-${result.frequencyMHz.toStringAsFixed(3).replaceAll('.', '_')}MHz.png';
      final file = File('${directory.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('图纸与切割表已保存：${file.path}')));
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  Future<Uint8List?> _renderLandscapeExport(YagiAntennaResult result) async {
    const width = 2200.0;
    final rowCount = result.elements.length;
    final tableHeight = 180.0 + rowCount * 52.0;
    const summaryHeight = 150.0;
    final height = 980.0 + tableHeight + summaryHeight;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final exportPainter = _LandscapeExportPainter(result: result);
    exportPainter.paint(canvas, Size(width, height));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }
}

class _ExportBoard extends StatelessWidget {
  final YagiAntennaResult result;

  const _ExportBoard({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.page,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF111B34),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.developer_board, color: Colors.cyan.shade300),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '八木天线计算器',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${result.frequencyMHz.toStringAsFixed(3)} MHz · ${result.elementCount} 单元估算',
                            style: TextStyle(
                              color: Colors.blueGrey.shade200,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF202B42),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF31405F)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Row(
                          children: [
                            Text(
                              '设计蓝图预览',
                              style: TextStyle(
                                color: Colors.blueGrey.shade100,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Boom ${result.boomLengthMillimeters.toStringAsFixed(1)} mm',
                              style: TextStyle(
                                color: Colors.cyan.shade200,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF31405F)),
                      AspectRatio(
                        aspectRatio: 1.7,
                        child: CustomPaint(
                          painter: _ProfessionalBlueprintPainter(result: result),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CutListPanel(result: result),
        ],
      ),
    );
  }
}

class _CutListPanel extends StatelessWidget {
  final YagiAntennaResult result;

  const _CutListPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(Icons.table_chart_outlined, color: colors.accent),
                const SizedBox(width: 10),
                Text(
                  '切割尺寸表',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '公差建议 ±0.5 mm',
              style: TextStyle(
                color: colors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(colors.panelAlt),
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('单元')),
                  DataColumn(label: Text('位置 mm')),
                  DataColumn(label: Text('间距 mm')),
                  DataColumn(label: Text('半长 mm')),
                  DataColumn(label: Text('切割长 mm')),
                  DataColumn(label: Text('备注')),
                ],
                rows: result.elements.map((element) {
                  return DataRow(
                    cells: [
                      DataCell(Text(element.name)),
                      DataCell(Text(element.positionMillimeters.toStringAsFixed(1))),
                      DataCell(
                        Text(
                          element.spacingFromPreviousMeters == 0
                              ? '-'
                              : element.spacingMillimeters.toStringAsFixed(1),
                        ),
                      ),
                      DataCell(Text(element.halfLengthMillimeters.toStringAsFixed(1))),
                      DataCell(
                        Text(
                          element.lengthMillimeters.toStringAsFixed(1),
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      DataCell(Text(element.note)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      '频率: ${result.frequencyMHz.toStringAsFixed(3)} MHz',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '波长: ${(result.wavelengthMeters * 1000).toStringAsFixed(1)} mm',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '单元数: ${result.elementCount}',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '总臂长: ${result.boomLengthMillimeters.toStringAsFixed(1)} mm',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '元件直径: ${result.elementDiameterMm.toStringAsFixed(1)} mm',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '馈电间隙: ${result.feedGapMm.toStringAsFixed(1)} mm',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '安装: ${result.mountStyle == YagiMountStyle.throughBoom ? '穿 boom' : '绝缘架高'}',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '振子: ${result.drivenElementStyle == YagiDrivenElementStyle.foldedDipole ? '折合振子' : '直振子'}',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'boom 外径: ${result.boomDiameterMm.toStringAsFixed(1)} mm',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'boom 材料: ${result.boomMaterial == YagiBoomMaterial.aluminum ? '铝合金' : '玻纤'}',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '当前仅提供几何尺寸估算与切割参考。元件直径、馈电间隙、boom 外径、boom 材料、安装方式和振子类型只做经验修正，不包含增益、阻抗、驻波比和匹配网络计算。',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
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

class _ToolTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolTile({
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
          fontSize: 19,
        ),
      ),
    );
  }
}

class _ProfessionalBlueprintPainter extends CustomPainter {
  final YagiAntennaResult result;
  final bool compactLabels;

  const _ProfessionalBlueprintPainter({
    required this.result,
    this.compactLabels = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const background = Color(0xFF1E293B);
    const grid = Color(0xFF2D3A52);
    const axis = Color(0xFF4B5D79);
    const reflectorColor = Color(0xFFFF73B4);
    const drivenColor = Color(0xFF38BDF8);
    const directorColor = Color(0xFFE2E8F0);
    const labelColor = Color(0xFF94A3B8);
    const white = Colors.white;

    final bgPaint = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, bgPaint);

    const horizontalPadding = 36.0;
    const topPadding = 42.0;
    const bottomPadding = 58.0;
    final usableWidth = size.width - horizontalPadding * 2;
    final usableHeight = size.height - topPadding - bottomPadding;
    final boomY = topPadding + usableHeight * 0.52;
    final scale = usableWidth / math.max(result.boomLengthMillimeters, 1);
    final maxElementLength = result.elements
        .map((element) => element.lengthMillimeters)
        .reduce(math.max);
    final maxHalfElementPixels = math.max(
      36.0,
      math.min(usableHeight * 0.34, 132.0),
    );
    final verticalScale =
        maxHalfElementPixels / math.max(maxElementLength / 2, 1);
    final labelStep = compactLabels ? math.max(2, (result.elements.length / 6).ceil()) : 1;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (double x = horizontalPadding; x <= size.width - horizontalPadding; x += 40) {
      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, size.height - bottomPadding),
        gridPaint,
      );
    }
    for (double y = topPadding; y <= size.height - bottomPadding; y += 36) {
      canvas.drawLine(
        Offset(horizontalPadding, y),
        Offset(size.width - horizontalPadding, y),
        gridPaint,
      );
    }

    final boomPaint = Paint()
      ..color = axis
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(horizontalPadding, boomY),
      Offset(size.width - horizontalPadding, boomY),
      boomPaint,
    );

    for (final element in result.elements) {
      final x = horizontalPadding + element.positionMillimeters * scale;
      final halfLength = (element.lengthMillimeters / 2) * verticalScale;
      final color = switch (element.shortName) {
        'R' => reflectorColor,
        'DE' => drivenColor,
        _ => directorColor,
      };
      final paint = Paint()
        ..color = color
        ..strokeWidth = element.shortName == 'DE' ? 4.5 : 3.5
        ..strokeCap = StrokeCap.round;

      if (element.shortName == 'DE') {
        const gap = 8.0;
        canvas.drawLine(
          Offset(x - 4, boomY - halfLength),
          Offset(x - 4, boomY - gap),
          paint,
        );
        canvas.drawLine(
          Offset(x - 4, boomY + gap),
          Offset(x - 4, boomY + halfLength),
          paint,
        );
        canvas.drawLine(
          Offset(x + 4, boomY - halfLength),
          Offset(x + 4, boomY - gap),
          paint,
        );
        canvas.drawLine(
          Offset(x + 4, boomY + gap),
          Offset(x + 4, boomY + halfLength),
          paint,
        );
        canvas.drawCircle(
          Offset(x, boomY),
          2.5,
          Paint()..color = white,
        );
      } else {
        canvas.drawLine(
          Offset(x, boomY - halfLength),
          Offset(x, boomY + halfLength),
          paint,
        );
      }

      final index = result.elements.indexOf(element);
      final shouldLabel = !compactLabels ||
          index == 0 ||
          index == 1 ||
          index == result.elements.length - 1 ||
          index % labelStep == 0;
      if (shouldLabel) {
        _paintText(
          canvas,
          text: element.shortName,
          offset: Offset(x - 12, size.height - 44),
          style: const TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        );
        _paintText(
          canvas,
          text: _formatAxisValue(element.positionMillimeters),
          offset: Offset(x - 16, size.height - 26),
          style: const TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        );
        _paintText(
          canvas,
          text: _formatAxisValue(element.lengthMillimeters),
          offset: Offset(x + 8, boomY - 8),
          style: const TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProfessionalBlueprintPainter oldDelegate) {
    return oldDelegate.result != result;
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _formatAxisValue(double mm) {
    if (compactLabels && mm >= 10000) {
      return '${(mm / 1000).toStringAsFixed(1)}m';
    }
    return mm.toStringAsFixed(0);
  }
}

class _LandscapeExportPainter extends CustomPainter {
  final YagiAntennaResult result;

  const _LandscapeExportPainter({required this.result});

  @override
  void paint(Canvas canvas, Size size) {
    const pageColor = Color(0xFFF7F4F7);
    const panelColor = Color(0xFF111B34);
    const subPanelColor = Color(0xFF202B42);
    const borderColor = Color(0xFF31405F);
    const textPrimary = Colors.white;
    const textMuted = Color(0xFF9FB0C8);
    const accent = Color(0xFF67E8F9);

    final pageRect = Offset.zero & size;
    canvas.drawRect(pageRect, Paint()..color = pageColor);

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(90, 70, size.width - 180, size.height - 140),
      const Radius.circular(28),
    );
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = panelColor
        ..style = PaintingStyle.fill,
    );

    _paintText(
      canvas,
      text: '八木天线工程单',
      offset: const Offset(150, 130),
      style: const TextStyle(
        color: textPrimary,
        fontSize: 40,
        fontWeight: FontWeight.w900,
      ),
    );
    _paintText(
      canvas,
      text: '${result.frequencyMHz.toStringAsFixed(3)} MHz · ${result.elementCount} 单元',
      offset: const Offset(150, 182),
      style: const TextStyle(
        color: textMuted,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );

    const blueprintTop = 250.0;
    const blueprintHeight = 620.0;
    final blueprintRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(140, blueprintTop, 1920, blueprintHeight),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      blueprintRect,
      Paint()
        ..color = subPanelColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      blueprintRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _paintText(
      canvas,
      text: '设计蓝图预览',
      offset: const Offset(180, 285),
      style: const TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w800,
      ),
    );
    _paintText(
      canvas,
      text: 'Boom ${result.boomLengthMillimeters.toStringAsFixed(1)} mm',
      offset: const Offset(
        1520,
        285,
      ),
      style: const TextStyle(
        color: accent,
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
    );

    canvas.save();
    canvas.translate(140, 330);
    _ProfessionalBlueprintPainter(
      result: result,
      compactLabels: result.boomLengthMillimeters > 20000 || result.elementCount > 8,
    ).paint(canvas, const Size(1920, 540));
    canvas.restore();

    const tableTop = blueprintTop + blueprintHeight + 50;
    final tableHeight = 180.0 + result.elements.length * 52.0;
    final tableRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(140, tableTop, 1920, tableHeight),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      tableRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      tableRect,
      Paint()
        ..color = const Color(0xFFD4D8E2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _paintText(
      canvas,
      text: '切割尺寸表',
      offset: const Offset(180, 965),
      style: const TextStyle(
        color: Color(0xFF1F2937),
        fontSize: 30,
        fontWeight: FontWeight.w900,
      ),
    );
    _paintText(
      canvas,
      text: '公差建议 ±0.5 mm',
      offset: const Offset(180, 1010),
      style: const TextStyle(
        color: Color(0xFF667085),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );

    _paintTable(canvas, tableTop + 135);
    _paintSummary(canvas, tableTop + tableHeight + 26);
  }

  void _paintTable(Canvas canvas, double startY) {
    const startX = 180.0;
    const rowHeight = 52.0;
    const columns = <double>[210, 210, 210, 210, 230, 520];
    final headers = ['单元', '位置 mm', '间距 mm', '半长 mm', '切割长 mm', '备注'];

    double x = startX;
    for (var i = 0; i < headers.length; i++) {
      final width = columns[i];
      canvas.drawRect(
        Rect.fromLTWH(x, startY, width, rowHeight),
        Paint()..color = const Color(0xFFF3F6FA),
      );
      _paintText(
        canvas,
        text: headers[i],
        offset: Offset(x + 12, startY + 14),
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      );
      x += width;
    }

    for (var row = 0; row < result.elements.length; row++) {
      final element = result.elements[row];
      final y = startY + rowHeight * (row + 1);
      final values = [
        element.name,
        element.positionMillimeters.toStringAsFixed(1),
        element.spacingFromPreviousMeters == 0
            ? '-'
            : element.spacingMillimeters.toStringAsFixed(1),
        element.halfLengthMillimeters.toStringAsFixed(1),
        element.lengthMillimeters.toStringAsFixed(1),
        element.note,
      ];
      double cellX = startX;
      for (var i = 0; i < values.length; i++) {
        final width = columns[i];
        canvas.drawRect(
          Rect.fromLTWH(cellX, y, width, rowHeight),
          Paint()..color = row.isEven ? Colors.white : const Color(0xFFFAFBFC),
        );
        _paintText(
          canvas,
          text: values[i],
          offset: Offset(cellX + 12, y + 14),
          style: TextStyle(
            color: i == 4 ? const Color(0xFF0EA5E9) : const Color(0xFF334155),
            fontSize: 17,
            fontWeight: i == 4 ? FontWeight.w900 : FontWeight.w700,
          ),
        );
        cellX += width;
      }
    }
  }

  void _paintSummary(Canvas canvas, double startY) {
    final lines = [
      '频率: ${result.frequencyMHz.toStringAsFixed(3)} MHz',
      '波长: ${_formatDistance(result.wavelengthMeters * 1000)}',
      '单元数: ${result.elementCount}',
      '总臂长: ${_formatDistance(result.boomLengthMillimeters)}',
      '元件直径: ${result.elementDiameterMm.toStringAsFixed(1)} mm',
      '馈电间隙: ${result.feedGapMm.toStringAsFixed(1)} mm',
      '安装: ${result.mountStyle == YagiMountStyle.throughBoom ? '穿 boom' : '绝缘架高'}',
      '振子: ${result.drivenElementStyle == YagiDrivenElementStyle.foldedDipole ? '折合振子' : '直振子'}',
      'boom 外径: ${result.boomDiameterMm.toStringAsFixed(1)} mm',
      'boom 材料: ${result.boomMaterial == YagiBoomMaterial.aluminum ? '铝合金' : '玻纤'}',
    ];

    double x = 180;
    double y = startY;
    for (final line in lines) {
      _paintText(
        canvas,
        text: line,
        offset: Offset(x, y),
        style: const TextStyle(
          color: Color(0xFF475467),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      );
      x += 360;
      if (x > 1700) {
        x = 180;
        y += 34;
      }
    }

    _paintText(
      canvas,
      text:
          '当前仅提供几何尺寸估算与切割参考。元件直径、馈电间隙、boom 外径、boom 材料、安装方式和振子类型只做经验修正，不包含增益、阻抗、驻波比和匹配网络计算。',
      offset: Offset(180, y + 46),
      style: const TextStyle(
        color: Color(0xFF0EA5E9),
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      maxWidth: 1720,
    );
  }

  @override
  bool shouldRepaint(covariant _LandscapeExportPainter oldDelegate) {
    return oldDelegate.result != result;
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required TextStyle style,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxWidth == null ? 1 : 3,
      ellipsis: maxWidth == null ? null : '...',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
  }

  String _formatDistance(double mm) {
    if (mm >= 10000) {
      return '${(mm / 1000).toStringAsFixed(3)} m';
    }
    return '${mm.toStringAsFixed(1)} mm';
  }
}
