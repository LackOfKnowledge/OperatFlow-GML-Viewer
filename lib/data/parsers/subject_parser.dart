import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class SubjectParseResult {
  final Map<String, dynamic> subject;
  final List<String> addressRefs;

  SubjectParseResult({required this.subject, required this.addressRefs});
}

class PhysicalPersonParser implements GmlFeatureParser<SubjectParseResult> {
  @override
  String get featureName => 'EGB_OsobaFizyczna';

  @override
  SubjectParseResult? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final imie = element.textOf('imiePierwsze') ?? element.textOf('pierwszeImie');
    final nazwisko = element.textOf('nazwisko') ?? element.textOf('pierwszyCzlonNazwiska');
    final czlon1 = element.textOf('nazwiskoPierwszegoCzlonu') ?? element.textOf('pierwszyCzlonNazwiska');
    final czlon2 = element.textOf('nazwiskoDrugiegoCzlonu') ?? element.textOf('drugiCzlonNazwiska');

    String name = imie ?? '';
    if (nazwisko != null) {
      name += ' $nazwisko';
    } else if (czlon1 != null) {
      name += ' $czlon1';
      if (czlon2 != null) name += '-$czlon2';
    }

    final extras = collectUnknownAttributes(
      element,
      knownLocals: {
        'imiePierwsze',
        'pierwszeImie',
        'nazwisko',
        'pierwszyCzlonNazwiska',
        'nazwiskoPierwszegoCzlonu',
        'nazwiskoDrugiegoCzlonu',
        'drugiCzlonNazwiska',
        'PESEL',
      },
    );

    final identifiers = <String, String>{};
    final pesel = element.textOf('PESEL');
    if (pesel != null) identifiers['PESEL'] = pesel;

    final addressRefs = _parseSubjectAddressRefs(element);

    return SubjectParseResult(
      subject: {
        'gmlId': gmlId,
        'name': name.trim(),
        'type': 'Osoba fizyczna',
        'identifiers': identifiers,
        'extraAttributes': extras,
      },
      addressRefs: addressRefs,
    );
  }
}

class InstitutionParser implements GmlFeatureParser<SubjectParseResult> {
  @override
  String get featureName => 'EGB_Instytucja';

  @override
  SubjectParseResult? parse(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {'nazwaPelna', 'REGON', 'NIP'},
    );
    final identifiers = <String, String>{};
    final nip = element.textOf('NIP');
    final regon = element.textOf('REGON');
    if (nip != null) identifiers['NIP'] = nip;
    if (regon != null) identifiers['REGON'] = regon;

    final addressRefs = _parseSubjectAddressRefs(element);

    return SubjectParseResult(
      subject: {
        'gmlId': gmlId,
        'name': element.textOf('nazwaPelna') ?? 'Instytucja',
        'type': 'Instytucja',
        'identifiers': identifiers,
        'extraAttributes': extras,
      },
      addressRefs: addressRefs,
    );
  }
}

List<String> _parseSubjectAddressRefs(XmlElement element) {
  final res = <String>[];
  final addressElement = element.firstDescendantByLocal('adresOsobyFizycznej') ??
      element.firstDescendantByLocal('adresInstytucji');
  if (addressElement != null) {
    final id = stripHref(addressElement.getAttribute('xlink:href'));
    if (id != null) res.add(id);
  }
  return res;
}
