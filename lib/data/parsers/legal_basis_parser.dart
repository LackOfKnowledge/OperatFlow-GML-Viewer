import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class LegalBasisParser implements GmlFeatureParser<Map<String, dynamic>> {
  LegalBasisParser(this.featureName);

  @override
  final String featureName;

  @override
  Map<String, dynamic>? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {
        'numerOperatuTechnicznego',
        'numerDokumentu',
        'dataDokumentu',
        'opis',
        'rodzajDokumentu',
        'dzialkaEwidencyjna',
      },
    );
    final parcelRefs = element
        .findDescendantsByLocal('dzialkaEwidencyjna')
        .map((e) => stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    final number = element.textOf('numerOperatuTechnicznego') ??
        element.textOf('numerDokumentu');
    final date = element.textOf('dataDokumentu');
    final docType = element.textOf('rodzajDokumentu');
    final desc = element.textOf('opis');
    return {
      'gmlId': gmlId,
      'type': featureName,
      'number': number,
      'date': date,
      'documentTypeCode': docType,
      'documentTypeLabel': docType,
      'description': desc,
      'parcelRefs': parcelRefs,
      'extraAttributes': extras,
    };
  }
}
