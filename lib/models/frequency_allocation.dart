class FrequencyAllocation {
  final String region;
  final double lowerMhz;
  final double upperMhz;
  final String unit;
  final List<String> services;
  final List<String> footnotes;
  final String source;
  final int sortOrder;

  const FrequencyAllocation({
    required this.region,
    required this.lowerMhz,
    required this.upperMhz,
    required this.unit,
    required this.services,
    required this.footnotes,
    required this.source,
    required this.sortOrder,
  });

  factory FrequencyAllocation.fromJson(Map<String, dynamic> json) {
    return FrequencyAllocation(
      region: json['region'] as String? ?? 'CN',
      lowerMhz: (json['lower_mhz'] as num?)?.toDouble() ?? 0,
      upperMhz: (json['upper_mhz'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'MHz',
      services: (json['services'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [],
      footnotes: (json['footnotes'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [],
      source: json['source'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'region': region,
      'lower_mhz': lowerMhz,
      'upper_mhz': upperMhz,
      'unit': unit,
      'services': services.join('\n'),
      'footnotes': footnotes.join('\n'),
      'source': source,
      'sort_order': sortOrder,
    };
  }

  String get rangeLabel {
    return '${_formatMhz(lowerMhz)} - ${_formatMhz(upperMhz)} MHz';
  }

  bool get isAmateur => services.any((item) => item.contains('业余'));

  static String _formatMhz(double value) {
    if (value >= 1000) return value.toStringAsFixed(0);
    if (value >= 100) return value.toStringAsFixed(3);
    if (value >= 1) return value.toStringAsFixed(3);
    return value.toStringAsFixed(6);
  }
}
