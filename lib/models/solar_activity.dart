import 'package:xml/xml.dart';

class SolarActivity {
  final String sourceName;
  final String sourceUrl;
  final String updated;
  final String solarFlux;
  final String aIndex;
  final String kIndex;
  final String kIndexNt;
  final String xray;
  final String sunspots;
  final String heliumLine;
  final String protonFlux;
  final String electronFlux;
  final String aurora;
  final String normalization;
  final String latDegree;
  final String solarWind;
  final String magneticField;
  final String geomagneticField;
  final String signalNoise;
  final String fof2;
  final String mufFactor;
  final String muf;
  final List<SolarBandCondition> hfConditions;
  final List<SolarVhfCondition> vhfConditions;

  const SolarActivity({
    required this.sourceName,
    required this.sourceUrl,
    required this.updated,
    required this.solarFlux,
    required this.aIndex,
    required this.kIndex,
    required this.kIndexNt,
    required this.xray,
    required this.sunspots,
    required this.heliumLine,
    required this.protonFlux,
    required this.electronFlux,
    required this.aurora,
    required this.normalization,
    required this.latDegree,
    required this.solarWind,
    required this.magneticField,
    required this.geomagneticField,
    required this.signalNoise,
    required this.fof2,
    required this.mufFactor,
    required this.muf,
    required this.hfConditions,
    required this.vhfConditions,
  });

  factory SolarActivity.fromXml(String xml) {
    final document = XmlDocument.parse(xml);
    final data = document.findAllElements('solardata').firstOrNull;
    if (data == null) {
      throw const FormatException('HamQSL 返回数据缺少 solardata');
    }

    final source = data.findElements('source').firstOrNull;
    return SolarActivity(
      sourceName: source?.innerText.trim() ?? '',
      sourceUrl: source?.getAttribute('url')?.trim() ?? '',
      updated: _text(data, 'updated'),
      solarFlux: _text(data, 'solarflux'),
      aIndex: _text(data, 'aindex'),
      kIndex: _text(data, 'kindex'),
      kIndexNt: _text(data, 'kindexnt'),
      xray: _text(data, 'xray'),
      sunspots: _text(data, 'sunspots'),
      heliumLine: _text(data, 'heliumline'),
      protonFlux: _text(data, 'protonflux'),
      electronFlux: _text(data, 'electonflux'),
      aurora: _text(data, 'aurora'),
      normalization: _text(data, 'normalization'),
      latDegree: _text(data, 'latdegree'),
      solarWind: _text(data, 'solarwind'),
      magneticField: _text(data, 'magneticfield'),
      geomagneticField: _text(data, 'geomagfield'),
      signalNoise: _text(data, 'signalnoise'),
      fof2: _text(data, 'fof2'),
      mufFactor: _text(data, 'muffactor'),
      muf: _text(data, 'muf'),
      hfConditions: data
          .findAllElements('band')
          .map((element) => SolarBandCondition.fromXml(element))
          .toList(),
      vhfConditions: data
          .findAllElements('phenomenon')
          .map((element) => SolarVhfCondition.fromXml(element))
          .toList(),
    );
  }

  String get hfSummary {
    final good = hfConditions
        .where((item) => item.condition.toLowerCase() == 'good')
        .length;
    if (hfConditions.isEmpty) return '无报告';
    return '$good/${hfConditions.length} 良好';
  }

  static String _text(XmlElement parent, String name) {
    return parent.findElements(name).firstOrNull?.innerText.trim() ?? '';
  }
}

class SolarBandCondition {
  final String band;
  final String time;
  final String condition;

  const SolarBandCondition({
    required this.band,
    required this.time,
    required this.condition,
  });

  factory SolarBandCondition.fromXml(XmlElement element) {
    return SolarBandCondition(
      band: element.getAttribute('name')?.trim() ?? '',
      time: element.getAttribute('time')?.trim() ?? '',
      condition: element.innerText.trim(),
    );
  }
}

class SolarVhfCondition {
  final String name;
  final String location;
  final String condition;

  const SolarVhfCondition({
    required this.name,
    required this.location,
    required this.condition,
  });

  factory SolarVhfCondition.fromXml(XmlElement element) {
    return SolarVhfCondition(
      name: element.getAttribute('name')?.trim() ?? '',
      location: element.getAttribute('location')?.trim() ?? '',
      condition: element.innerText.trim(),
    );
  }
}
