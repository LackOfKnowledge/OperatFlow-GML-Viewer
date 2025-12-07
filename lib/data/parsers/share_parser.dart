import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class ShareParser implements GmlFeatureParser<Map<String, dynamic>> {
  @override
  String get featureName => 'EGB_UdzialWeWlasnosci';

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final l = element.textOf('licznikUlamkaOkreslajacegoWartoscUdzialu') ?? '1';
    final m = element.textOf('mianownikUlamkaOkreslajacegoWartoscUdzialu') ?? '1';
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {
        'licznikUlamkaOkreslajacegoWartoscUdzialu',
        'mianownikUlamkaOkreslajacegoWartoscUdzialu',
        'JRG',
        'osobaFizyczna',
        'instytucja',
        'instytucja1',
      },
    );

    final jrgRef = element.firstDescendantByLocal('JRG')?.getAttribute('xlink:href');
    final subElem = element.firstDescendantByLocal('osobaFizyczna') ??
        element.firstDescendantByLocal('instytucja1') ??
        element.firstDescendantByLocal('instytucja');
    final subRef = subElem?.getAttribute('xlink:href');

    return {
      'gmlId': gmlId,
      'jrgId': stripHref(jrgRef),
      'subjectId': stripHref(subRef),
      'share': '$l/$m',
      'numerator': int.tryParse(l),
      'denominator': int.tryParse(m),
      'extraAttributes': extras,
    };
  }
}
