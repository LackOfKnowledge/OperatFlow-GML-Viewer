import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class LandUseContourParser implements GmlFeatureParser<Map<String, dynamic>> {
  @override
  String get featureName => 'EGB_KonturUzytkuGruntowego';

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final geometry = parsePolygon(element);
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {'OFU', 'OZU', 'powierzchnia', 'dzialkaEwidencyjna', 'geometria'},
    );
    final parcelRefs = element
        .findDescendantsByLocal('dzialkaEwidencyjna')
        .map((e) => stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    return {
      'gmlId': gmlId,
      'ofu': element.textOf('OFU') ?? '',
      'ozu': element.textOf('OZU') ?? '',
      'powierzchnia': double.tryParse(element.textOf('powierzchnia') ?? ''),
      'parcelRefs': parcelRefs,
      'geometry': geometry,
      'extraAttributes': extras,
    };
  }
}

class ClassificationContourParser implements GmlFeatureParser<Map<String, dynamic>> {
  @override
  String get featureName => 'EGB_KonturKlasyfikacyjny';

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final geometry = parsePolygon(element);
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {'OZU', 'OZK', 'powierzchnia', 'dzialkaEwidencyjna', 'geometria'},
    );
    final parcelRefs = element
        .findDescendantsByLocal('dzialkaEwidencyjna')
        .map((e) => stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    return {
      'gmlId': gmlId,
      'ofu': element.textOf('OZU') ?? '',
      'ozu': element.textOf('OZU') ?? '',
      'ozk': element.textOf('OZK'),
      'powierzchnia': double.tryParse(element.textOf('powierzchnia') ?? ''),
      'parcelRefs': parcelRefs,
      'geometry': geometry,
      'extraAttributes': extras,
    };
  }
}
