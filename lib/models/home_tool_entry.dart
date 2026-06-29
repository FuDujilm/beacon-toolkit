import 'package:flutter/material.dart';

class HomeToolEntry {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const HomeToolEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const homeToolEntries = <HomeToolEntry>[
  HomeToolEntry(
    id: 'callsign_lookup',
    title: '呼号查询',
    subtitle: '查询电台信息、B站/QRZ 数据',
    icon: Icons.search,
    color: Color(0xff347cff),
  ),
  HomeToolEntry(
    id: 'beacon_scan',
    title: '扫码确认',
    subtitle: '扫描 Beacon 二维码确认 QSL 收妥',
    icon: Icons.qr_code_scanner,
    color: Color(0xff00a5c8),
  ),
  HomeToolEntry(
    id: 'qth_locator',
    title: 'QTH 定位',
    subtitle: '经纬度与 Maidenhead 网格定位',
    icon: Icons.public,
    color: Color(0xff6a6dff),
  ),
  HomeToolEntry(
    id: 'frequency_table',
    title: '频率表',
    subtitle: '业余频段划分与常用频率',
    icon: Icons.radio,
    color: Color(0xff38c77b),
  ),
  HomeToolEntry(
    id: 'exam_practice',
    title: '考试题库',
    subtitle: 'CRAC 题库、模拟考试与错题回顾',
    icon: Icons.assignment,
    color: Color(0xffffa33c),
  ),
  HomeToolEntry(
    id: 'antenna_calculator',
    title: '天线计算',
    subtitle: '天线长度、增益与常见换算',
    icon: Icons.settings_input_antenna,
    color: Color(0xff2196f3),
  ),
  HomeToolEntry(
    id: 'walkie_calculator',
    title: '对讲计算',
    subtitle: '中继频差、亚音与常用参数计算',
    icon: Icons.calculate,
    color: Color(0xffb26a2e),
  ),
  HomeToolEntry(
    id: 'qso_log',
    title: '通联日志',
    subtitle: '记录 QSO、导出日志与同步统计',
    icon: Icons.event_note,
    color: Color(0xffca5d9a),
  ),
  HomeToolEntry(
    id: 'study_calendar',
    title: '学习日历',
    subtitle: '练习记录与活跃天数',
    icon: Icons.calendar_month,
    color: Color(0xff34aadc),
  ),
  HomeToolEntry(
    id: 'satellite_tracker',
    title: '卫星追踪',
    subtitle: '实时卫星位置与过境预报',
    icon: Icons.satellite_alt,
    color: Color(0xff3f8cff),
  ),
  HomeToolEntry(
    id: 'tone_decoder',
    title: '声码器',
    subtitle: 'CTCSS / DCS / DTCS 查询',
    icon: Icons.graphic_eq,
    color: Color(0xff7357d9),
  ),
  HomeToolEntry(
    id: 'propagation_forecast',
    title: '传播预测',
    subtitle: 'HF 传播预测与电离层数据',
    icon: Icons.cloud_queue,
    color: Color(0xff4bc987),
  ),
];

const defaultHomeToolIds = <String>[
  'callsign_lookup',
  'qth_locator',
  'frequency_table',
  'exam_practice',
  'antenna_calculator',
  'walkie_calculator',
  'qso_log',
  'study_calendar',
];
