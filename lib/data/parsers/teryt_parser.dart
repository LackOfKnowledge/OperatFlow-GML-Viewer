import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class ObrebParser implements GmlFeatureParser<Map<String, dynamic>> {
  @override
  String get featureName => 'EGB_ObrebEwidencyjny';

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    return {
      'gmlId': gmlId,
      'idObrebu': element.textOf('idObrebu'),
      'nazwa': element.textOf('nazwaWlasna'),
      'jednostkaHref':
          element.firstDescendantByLocal('lokalizacjaObrebu')?.getAttribute('xlink:href'),
    };
  }
}

class JednostkaEwidParser implements GmlFeatureParser<Map<String, dynamic>> {
  @override
  String get featureName => 'EGB_JednostkaEwidencyjna';

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    return {
      'gmlId': gmlId,
      'idJednostkiEwid': element.textOf('idJednostkiEwid'),
      'nazwa': element.textOf('nazwaWlasna'),
    };
  }
}
