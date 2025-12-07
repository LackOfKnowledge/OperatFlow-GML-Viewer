import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class PremisesParser implements GmlFeatureParser<Map<String, dynamic>> {
  @override
  String get featureName => 'EGB_Lokal';

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {
        'idLokalu',
        'numerLokalu',
        'rodzajLokalu',
        'kondygnacja',
        'powierzchniaUzytkowa',
        'budynek',
        'dzialkaEwidencyjna',
      },
    );
    final parcelRefs = element
        .findDescendantsByLocal('dzialkaEwidencyjna')
        .map((e) => stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    final buildingRef =
        stripHref(element.firstDescendantByLocal('budynek')?.getAttribute('xlink:href'));
    return {
      'gmlId': gmlId,
      'premisesId': element.textOf('idLokalu'),
      'number': element.textOf('numerLokalu'),
      'typeCode': element.textOf('rodzajLokalu'),
      'floor': element.textOf('kondygnacja'),
      'usableArea': double.tryParse(element.textOf('powierzchniaUzytkowa') ?? ''),
      'parcelRefs': parcelRefs,
      'buildingRef': buildingRef,
      'extraAttributes': extras,
    };
  }
}
