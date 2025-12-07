import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class AddressParser implements GmlFeatureParser<Map<String, dynamic>> {
  AddressParser(this.featureName);

  @override
  final String featureName;

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {
        'kraj',
        'miejscowosc',
        'nazwaMiejscowosci',
        'kodPocztowy',
        'ulica',
        'nazwaUlicy',
        'numerPorzadkowy',
        'wojewodztwo',
        'powiat',
        'gmina',
        'terc',
        'simc',
        'ulic',
      },
    );
    return {
      'gmlId': gmlId,
      'kraj': element.textOf('kraj'),
      'miejscowosc':
          element.textOf('miejscowosc') ?? element.textOf('nazwaMiejscowosci'),
      'kodPocztowy': element.textOf('kodPocztowy'),
      'ulica': element.textOf('ulica') ?? element.textOf('nazwaUlicy'),
      'numerPorzadkowy': element.textOf('numerPorzadkowy'),
      'wojewodztwoTeryt': element.textOf('wojewodztwo'),
      'powiatTeryt': element.textOf('powiat'),
      'gminaTeryt': element.textOf('gmina'),
      'miejscowoscTeryt': element.textOf('simc'),
      'ulicaTeryt': element.textOf('ulic'),
      'extraAttributes': extras,
    };
  }
}
