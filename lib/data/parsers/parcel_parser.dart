import 'package:xml/xml.dart';

import '../../utils/xml_utils.dart';
import 'base_parser.dart';

class ParcelParseResult {
  final Map<String, dynamic> parcel;
  final List<String> addressRefs;
  final String? obrebRefId;

  ParcelParseResult({
    required this.parcel,
    required this.addressRefs,
    required this.obrebRefId,
  });
}

class ParcelParser implements GmlFeatureParser<ParcelParseResult> {
  @override
  String get featureName => 'EGB_DzialkaEwidencyjna';

  @override
  ParcelParseResult? parse(XmlElement element) {
    final parcelMap = _parseParcel(element);
    if (parcelMap == null) return null;

    parcelMap['geometry'] = parsePolygon(element);

    final addressRefs = _parseParcelAddressRefs(element);
    final lokalizacjaHref =
        element.firstDescendantByLocal('lokalizacjaDzialki')?.getAttribute('xlink:href');
    final lokalizacjaId = stripHref(lokalizacjaHref);

    return ParcelParseResult(
      parcel: parcelMap,
      addressRefs: addressRefs,
      obrebRefId: lokalizacjaId,
    );
  }

  Map<String, dynamic>? _parseParcel(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    final idDzialki = element.textOf('idDzialki');
    if (gmlId == null || idDzialki == null) return null;

    final numerKW = element.textOf('numerKW');
    final poleStr = element.textOf('poleEwidencyjne');
    final poleGeomStr =
        element.textOf('powierzchniaZGeometrii') ?? element.textOf('polePowierzchni');
    final rodzajDzialkiCode = element.textOf('rodzajDzialki');

    final jrgRefs = <String>[];
    final jrgHref =
        element.firstDescendantByLocal('JRG2')?.getAttribute('xlink:href') ??
            element.firstDescendantByLocal('JRG')?.getAttribute('xlink:href');
    if (jrgHref != null) jrgRefs.add(stripHref(jrgHref) ?? '');
    for (final ref in element
        .findDescendantsByLocal('JRG')
        .map((e) => stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()) {
      if (!jrgRefs.contains(ref)) jrgRefs.add(ref);
    }

    final uzytki = <Map<String, dynamic>>[];
    for (final u in element.findDescendantsByLocal('EGB_Klasouzytek')) {
      final extras = collectUnknownAttributes(
        u,
        knownLocals: {'OFU', 'OZU', 'OZK', 'powierzchnia'},
      );
      uzytki.add({
        'ofu': u.textOf('OFU') ?? '?',
        'ofuLabel': u.textOf('OFUOpis'),
        'ozu': u.textOf('OZU') ?? '?',
        'ozuLabel': u.textOf('OZUOpis'),
        'ozk': u.textOf('OZK'),
        'ozkLabel': u.textOf('OZKOpis'),
        'powierzchnia': double.tryParse(u.textOf('powierzchnia') ?? ''),
        'extra': extras,
      });
    }

    final pointIds = <String>[];
    final pktElems = element.findDescendantsByLocal('punktGraniczny').followedBy(
          element.findDescendantsByLocal('punktGranicyDzialki'),
        );
    for (final pkt in pktElems) {
      final id = stripHref(pkt.getAttribute('xlink:href'));
      if (id != null) pointIds.add(id);
    }

    final parts = idDzialki.split('.');
    final numerDzialki = parts.isNotEmpty ? parts.last : idDzialki;
    final extras = collectUnknownAttributes(
      element,
      knownLocals: {
        'idDzialki',
        'numerKW',
        'poleEwidencyjne',
        'powierzchniaZGeometrii',
        'polePowierzchni',
        'rodzajDzialki',
        'JRG',
        'JRG2',
        'punktGraniczny',
        'punktGranicyDzialki',
        'geometria',
        'lokalizacjaDzialki',
        'EGB_Klasouzytek',
      },
    );

    return {
      'gmlId': gmlId,
      'idDzialki': idDzialki,
      'numerDzialki': numerDzialki,
      'numerKW': numerKW,
      'pole': double.tryParse(poleStr ?? ''),
      'poleGeometryczne': double.tryParse(poleGeomStr ?? ''),
      'rodzajDzialkiCode': rodzajDzialkiCode,
      'rodzajDzialkiLabel': rodzajDzialkiCode,
      'uzytki': uzytki,
      'klasyfikacyjne': <Map<String, dynamic>>[],
      'jrgId': stripHref(jrgHref),
      'jrgRefs': jrgRefs.where((e) => e.isNotEmpty).toList(),
      'pointRefs': pointIds,
      'extraAttributes': extras,
    };
  }

  List<String> _parseParcelAddressRefs(XmlElement element) {
    final res = <String>[];
    for (final e in element.findDescendantsByLocal('adresDzialki')) {
      final id = stripHref(e.getAttribute('xlink:href'));
      if (id != null) res.add(id);
    }
    return res;
  }
}
