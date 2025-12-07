import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class RegistrationUnitParser implements GmlFeatureParser<Map<String, dynamic>> {
  @override
  String get featureName => 'EGB_JednostkaRejestrowaGruntow';

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    final idJRG = element.textOf('idJednostkiRejestrowej');
    if (gmlId == null || idJRG == null) return null;
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {
        'idJednostkiRejestrowej',
        'rodzajJednostki',
        'dzialkaEwidencyjna',
        'budynek',
        'lokal',
      },
    );
    final parcelRefs = element
        .findDescendantsByLocal('dzialkaEwidencyjna')
        .map((e) => stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    final buildingRefs = element
        .findDescendantsByLocal('budynek')
        .map((e) => stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    final premisesRefs = element
        .findDescendantsByLocal('lokal')
        .map((e) => stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    return {
      'gmlId': gmlId,
      'idJRG': idJRG,
      'rodzajJRGCode': element.textOf('rodzajJednostki'),
      'parcelRefs': parcelRefs,
      'buildingRefs': buildingRefs,
      'premisesRefs': premisesRefs,
      'extraAttributes': extras,
    };
  }
}
