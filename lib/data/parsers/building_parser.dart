import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class BuildingParser implements GmlFeatureParser<Map<String, dynamic>> {
  @override
  String get featureName => 'EGB_Budynek';

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {
        'idBudynku',
        'numerPorzadkowy',
        'funkcjaBudynku',
        'liczbaKondygnacjiNadziemnych',
        'liczbaKondygnacjiPodziemnych',
        'powierzchniaUzytkowa',
        'powierzchniaZabudowy',
        'dzialkaEwidencyjna',
      },
    );
    final parcelRefs = element
        .findDescendantsByLocal('dzialkaEwidencyjna')
        .map((e) => stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    return {
      'gmlId': gmlId,
      'buildingId': element.textOf('idBudynku'),
      'number': element.textOf('numerPorzadkowy'),
      'functionCode': element.textOf('funkcjaBudynku'),
      'floors':
          int.tryParse(element.textOf('liczbaKondygnacjiNadziemnych') ?? ''),
      'usableArea': double.tryParse(element.textOf('powierzchniaUzytkowa') ?? ''),
      'builtUpArea': double.tryParse(element.textOf('powierzchniaZabudowy') ?? ''),
      'parcelRefs': parcelRefs,
      'extraAttributes': extras,
    };
  }
}
