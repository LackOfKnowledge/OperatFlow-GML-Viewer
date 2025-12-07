import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class BoundaryPointParser implements GmlFeatureParser<Map<String, dynamic>> {
  static const Map<String, String> _spdEnum = {
    '1': 'ustalony (1)',
    '2': 'nieustalony (2)',
    'TRK': 'TRK',
    'PZG': 'PZG',
  };

  static const Map<String, String> _isdEnum = {
    '1': 'spelnia (1)',
    '2': 'nie spelnia (2)',
    'PZG': 'PZG',
  };

  static const Map<String, String> _stbEnum = {
    '1': 'brak informacji (1)',
    '2': 'niestabilizowany (2)',
    '3': 'znak naziemny (3)',
    '4': 'znak naziemny i podziemny (4)',
    '5': 'znak podziemny (5)',
    '6': 'szczegol terenowy (6)',
    'ZRD': 'ZRD',
  };

  @override
  String get featureName => 'EGB_PunktGraniczny';

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final idPunktu = element.textOf('idPunktu');
    final numer = element.textOf('oznaczenieWMaterialeZrodlowym') ??
        element.textOf('oznWMaterialeZrodlowym') ??
        element.textOf('idPunktu');
    String? x, y;
    XmlElement? posElement = element.findDescendantsByLocal('pos').firstOrNull;
    posElement ??= element.findDescendantsByLocal('posList').firstOrNull;
    if (posElement != null) {
      final coords = posElement.innerText.trim().split(RegExp(r'\s+'));
      if (coords.length >= 2) {
        x = coords[0];
        y = coords[1];
      }
    }

    final spdRaw = element.textOf('sposobPozyskania') ?? element.textOf('SPD');
    final isdRaw = element.textOf('spelnienieWarunkowDokl') ?? element.textOf('ISD');
    final stbRaw = element.textOf('rodzajStabilizacji') ?? element.textOf('STB');
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {
        'idPunktu',
        'oznaczenieWMaterialeZrodlowym',
        'oznWMaterialeZrodlowym',
        'SPD',
        'ISD',
        'STB',
        'sposobPozyskania',
        'spelnienieWarunkowDokl',
        'rodzajStabilizacji',
        'geometria',
      },
    );

    return {
      'gmlId': gmlId,
      'pelneId': idPunktu ?? gmlId,
      'numer': numer,
      'x': x,
      'y': y,
      'spdCode': spdRaw,
      'spdLabel': _spdEnum[spdRaw ?? ''] ?? _mapSpd(spdRaw),
      'isdCode': isdRaw,
      'isdLabel': _isdEnum[isdRaw ?? ''] ?? _mapIsd(isdRaw),
      'stbCode': stbRaw,
      'stbLabel': _stbEnum[stbRaw ?? ''] ?? _mapStb(stbRaw),
      'operat': element.textOf('identyfikatorOperatuWgPZGIK') ??
          element.textOf('numerOperatuTechnicznego'),
      'extraAttributes': extras,
    };
  }

  String? _mapSpd(String? value) {
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case '1':
        return 'ustalony (1)';
      case '2':
        return 'nieustalony (2)';
      default:
        return value;
    }
  }

  String? _mapIsd(String? value) {
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case '1':
        return 'spelnia (1)';
      case '2':
        return 'nie spelnia (2)';
      default:
        return value;
    }
  }

  String? _mapStb(String? value) {
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case '1':
        return 'brak informacji (1)';
      case '2':
        return 'niestabilizowany (2)';
      case '3':
        return 'znak naziemny (3)';
      case '4':
        return 'znak naziemny i podziemny (4)';
      case '5':
        return 'znak podziemny (5)';
      case '6':
        return 'szczegol terenowy (6)';
      default:
        return value;
    }
  }
}
