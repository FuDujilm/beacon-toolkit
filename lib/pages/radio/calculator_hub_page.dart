import 'package:flutter/material.dart';

import 'antenna_calculator_page.dart';
import 'radio_placeholder_page.dart';
import 'satellite_tracker_page.dart';
import 'timezone_calculator_page.dart';
import 'transmission_line_calculator_page.dart';
import 'unit_converter_page.dart';
import 'grid_map_page.dart';
import 'radio_theme.dart';

class CalculatorHubPage extends StatelessWidget {
  const CalculatorHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    final sections = _buildSections(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        title: const Text('计算目录'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _HubIntroCard(sectionCount: sections.length),
          const SizedBox(height: 14),
          for (var i = 0; i < sections.length; i++) ...[
            _HubSectionCard(section: sections[i]),
            if (i != sections.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          Text(
            '仅供参考，请遵守当地法规和主管部门要求。',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<_CalculatorSection> _buildSections(BuildContext context) {
    return [
      _CalculatorSection(
        title: '天线',
        englishTitle: 'Antenna Calculators',
        icon: Icons.settings_input_antenna,
        color: const Color(0xffef9743),
        sourceCount: 14,
        items: [
          _implementedItem(
            context,
            title: '八木天线计算器',
            subtitle: 'Yagi Antenna Element Length Calculator',
            pageBuilder: (_) => const YagiAntennaCalculatorPage(),
          ),
          _placeholderItem(
            context,
            title: '半波振子长度',
            subtitle: 'Half-Wave Dipole Length Calculator',
          ),
          _placeholderItem(
            context,
            title: 'Moxon 尺寸',
            subtitle: 'Moxon Rectangle Dimension Calculator',
          ),
          _placeholderItem(
            context,
            title: '四分之一波垂直天线',
            subtitle: 'Quarter-Wave Vertical and Radial Calculator',
          ),
        ],
      ),
      _CalculatorSection(
        title: '传输线',
        englishTitle: 'Transmission Line',
        icon: Icons.cable,
        color: const Color(0xff4d89ff),
        sourceCount: 11,
        items: [
          _implementedItem(
            context,
            title: '同轴损耗',
            subtitle: 'Coax Matched-Line Loss Calculator',
            pageBuilder: (_) => const CoaxLossCalculatorPage(),
          ),
          _implementedItem(
            context,
            title: 'SWR / 回波损耗',
            subtitle: 'SWR ↔ Return Loss ↔ Reflection Coefficient',
            pageBuilder: (_) => const SwrReturnLossCalculatorPage(),
          ),
          _implementedItem(
            context,
            title: '电气长度换算',
            subtitle: 'Electrical Length and Physical Length Converter',
            pageBuilder: (_) => const ElectricalLengthCalculatorPage(),
          ),
          _implementedItem(
            context,
            title: '同轴扼流圈匝数',
            subtitle: 'Ferrite Coax Choke Minimum Turns Calculator',
            pageBuilder: (_) => const CoaxChokeTurnsCalculatorPage(),
          ),
        ],
      ),
      _CalculatorSection(
        title: '传播',
        englishTitle: 'Propagation',
        icon: Icons.public,
        color: const Color(0xff2aa67f),
        sourceCount: 10,
        items: [
          _implementedItem(
            context,
            title: '时区与灰线',
            subtitle: 'Grey Line Time Calculator',
            pageBuilder: (_) => const TimezoneCalculatorPage(),
          ),
          _implementedItem(
            context,
            title: '卫星追踪',
            subtitle: 'VHF/UHF Radio Horizon Calculator / related tools',
            pageBuilder: (_) => const SatelliteTrackerPage(),
          ),
          _placeholderItem(
            context,
            title: '自由空间路径损耗',
            subtitle: 'Free-Space Path Loss',
          ),
          _placeholderItem(
            context,
            title: 'HF 链路预算',
            subtitle: 'HF Link Budget Calculator',
          ),
        ],
      ),
      _CalculatorSection(
        title: '电子',
        englishTitle: 'Electronics',
        icon: Icons.bolt,
        color: const Color(0xfff0b23a),
        sourceCount: 15,
        items: [
          _implementedItem(
            context,
            title: '单位换算',
            subtitle: 'dBm, dBW and Watts Converter',
            pageBuilder: (_) => const UnitConverterPage(),
          ),
          _placeholderItem(
            context,
            title: '欧姆定律',
            subtitle: 'Ohm\'s Law Calculator',
          ),
          _placeholderItem(
            context,
            title: '电抗计算',
            subtitle: 'Inductive and Capacitive Reactance Calculator',
          ),
          _placeholderItem(
            context,
            title: 'LC 谐振',
            subtitle: 'LC Resonant Frequency Calculator',
          ),
        ],
      ),
      _CalculatorSection(
        title: '阻抗匹配',
        englishTitle: 'Impedance Matching',
        icon: Icons.tune,
        color: const Color(0xff8c6df5),
        sourceCount: 9,
        items: [
          _placeholderItem(
            context,
            title: 'L 网络匹配',
            subtitle: 'L-Network Impedance Matching Calculator',
          ),
          _placeholderItem(
            context,
            title: 'Pi 网络匹配',
            subtitle: 'Pi-Network Matching Calculator',
          ),
          _placeholderItem(
            context,
            title: '巴伦匝数',
            subtitle: 'Balun and UNUN Turns Calculator',
          ),
          _implementedItem(
            context,
            title: '四分之一波阻抗变换',
            subtitle: 'Quarter-Wave Coax Transformer Calculator',
            pageBuilder: (_) => const QuarterWaveTransformerCalculatorPage(),
          ),
        ],
      ),
      _CalculatorSection(
        title: '数字模式',
        englishTitle: 'Digital Modes',
        icon: Icons.memory,
        color: const Color(0xff17a1b8),
        sourceCount: 8,
        items: [
          _placeholderItem(
            context,
            title: 'WSPR 天线对比',
            subtitle: 'WSPR Antenna Comparison',
          ),
          _placeholderItem(
            context,
            title: 'FT8 / FT4 链路预算',
            subtitle: 'FT8 / FT4 Link Budget Calculator',
          ),
          _placeholderItem(
            context,
            title: '波特率带宽',
            subtitle: 'Baud Rate to Bandwidth Calculator',
          ),
          _placeholderItem(
            context,
            title: '噪声系数',
            subtitle: 'Noise Figure and Noise Temperature Calculator',
          ),
        ],
      ),
      _CalculatorSection(
        title: 'VHF / 卫星',
        englishTitle: 'VHF & Satellite',
        icon: Icons.satellite_alt,
        color: const Color(0xff3f8cff),
        sourceCount: 10,
        items: [
          _implementedItem(
            context,
            title: '卫星追踪',
            subtitle: 'Satellite Doppler Shift Calculator / footprint',
            pageBuilder: (_) => const SatelliteTrackerPage(),
          ),
          _placeholderItem(
            context,
            title: '无线电地平线',
            subtitle: 'Radio Horizon Distance Calculator',
          ),
          _placeholderItem(
            context,
            title: '抛物面天线增益',
            subtitle: 'Parabolic Dish Gain and Beamwidth Calculator',
          ),
          _placeholderItem(
            context,
            title: 'EME 链路预算',
            subtitle: 'Earth-Moon-Earth Link Budget Calculator',
          ),
        ],
      ),
      _CalculatorSection(
        title: '日志 / 竞赛',
        englishTitle: 'Logging & Contest',
        icon: Icons.map,
        color: const Color(0xffca5d9a),
        sourceCount: 7,
        items: [
          _implementedItem(
            context,
            title: 'QTH 定位',
            subtitle: 'Maidenhead Grid Square Calculator',
            pageBuilder: (_) => const GridMapPage(),
          ),
          _implementedItem(
            context,
            title: '时区计算',
            subtitle: 'UTC / Local Time Converter',
            pageBuilder: (_) => const TimezoneCalculatorPage(),
          ),
          _placeholderItem(
            context,
            title: '大圆距离与波束方位',
            subtitle: 'Great-Circle Distance and Beam Heading Calculator',
          ),
          _placeholderItem(
            context,
            title: 'CW 速度',
            subtitle: 'CW Speed (WPM) Calculator',
          ),
        ],
      ),
      _CalculatorSection(
        title: '电源 / 便携',
        englishTitle: 'Power & Portable',
        icon: Icons.battery_charging_full,
        color: const Color(0xffc47d2a),
        sourceCount: 8,
        items: [
          _implementedItem(
            context,
            title: '单位换算',
            subtitle: 'Watts / dBm / dBW Converter',
            pageBuilder: (_) => const UnitConverterPage(),
          ),
          _placeholderItem(
            context,
            title: '电池续航',
            subtitle: 'Battery Runtime Calculator',
          ),
          _placeholderItem(
            context,
            title: '太阳能充电时间',
            subtitle: 'Solar Panel Charge Time Calculator',
          ),
          _placeholderItem(
            context,
            title: '直流压降',
            subtitle: 'DC Voltage Drop Calculator',
          ),
        ],
      ),
    ];
  }

  _CalculatorItem _implementedItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required WidgetBuilder pageBuilder,
  }) {
    return _CalculatorItem(
      title: title,
      subtitle: subtitle,
      implemented: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: pageBuilder),
      ),
    );
  }

  _CalculatorItem _placeholderItem(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return _CalculatorItem(
      title: title,
      subtitle: subtitle,
      implemented: false,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RadioPlaceholderPage(
            title: title,
            icon: Icons.calculate_outlined,
            subtitle: '$subtitle\n\n当前版本先保留目录入口，后续再补完整计算逻辑。',
          ),
        ),
      ),
    );
  }
}

class _HubIntroCard extends StatelessWidget {
  final int sectionCount;

  const _HubIntroCard({required this.sectionCount});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '按主题整理的无线电计算器目录',
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '参考 Ham Radio Base 的分类结构，当前先接入 $sectionCount 个目录分组。已完成的工具可以直接进入，未完成的条目保留为目录入口。',
            style: TextStyle(
              color: colors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubSectionCard extends StatelessWidget {
  final _CalculatorSection section;

  const _HubSectionCard({required this.section});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(section.icon, color: section.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${section.englishTitle} · ${section.sourceCount} 项',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < section.items.length; i++) ...[
            _HubItemTile(item: section.items[i]),
            if (i != section.items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _HubItemTile extends StatelessWidget {
  final _CalculatorItem item;

  const _HubItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Material(
      color: colors.panelAlt,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: item.implemented
                      ? Colors.green.withValues(alpha: 0.14)
                      : colors.panel,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: item.implemented
                        ? Colors.green.withValues(alpha: 0.4)
                        : colors.border,
                  ),
                ),
                child: Text(
                  item.implemented ? '已接入' : '目录项',
                  style: TextStyle(
                    color: item.implemented ? Colors.green : colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalculatorSection {
  final String title;
  final String englishTitle;
  final IconData icon;
  final Color color;
  final int sourceCount;
  final List<_CalculatorItem> items;

  const _CalculatorSection({
    required this.title,
    required this.englishTitle,
    required this.icon,
    required this.color,
    required this.sourceCount,
    required this.items,
  });
}

class _CalculatorItem {
  final String title;
  final String subtitle;
  final bool implemented;
  final VoidCallback onTap;

  const _CalculatorItem({
    required this.title,
    required this.subtitle,
    required this.implemented,
    required this.onTap,
  });
}
