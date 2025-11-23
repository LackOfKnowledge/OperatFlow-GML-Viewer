import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../data/models/parcel.dart';
import '../data/models/boundary_point.dart';
import '../data/models/subject.dart';
import '../data/models/land_use.dart';
import '../data/models/address.dart';
import '../data/models/ownership_share.dart';
import '../data/models/registration_unit.dart';

class GmlService {
  final List<Parcel> parcels = [];
  final Map<String, Subject> subjects = {};
  final Map<String, RegistrationUnit> registrationUnits = {};
  final Map<String, List<OwnershipShare>> sharesByJrgId = {};
  final Map<String, BoundaryPoint> boundaryPoints = {};
  final Map<String, List<Address>> subjectAddresses = {};
  final Map<String, List<Address>> parcelAddresses = {};

  static const String _gmlNs = 'http://www.opengis.net/gml/3.2';

  Future<void> parseGml(Uint8List fileBytes) async {
    parcels.clear();
    subjects.clear();
    registrationUnits.clear();
    sharesByJrgId.clear();
    boundaryPoints.clear();
    subjectAddresses.clear();
    parcelAddresses.clear();

    final Map<String, dynamic> parsedData = await compute(
      _parseInBackground,
      fileBytes,
    );
    _setParsedData(parsedData);
  }

  static Map<String, dynamic> _parseInBackground(Uint8List fileBytes) {
    final List<Map<String, dynamic>> parsedParcels = [];
    final Map<String, Map<String, dynamic>> parsedSubjects = {};
    final Map<String, Map<String, dynamic>> parsedRegUnits = {};
    final Map<String, List<Map<String, dynamic>>> parsedShares = {};
    final Map<String, Map<String, dynamic>> parsedPoints = {};
    final Map<String, Map<String, dynamic>> parsedAddresses = {};
    final Map<String, List<String>> parsedSubjectAddressRefs = {};
    final Map<String, List<String>> parsedParcelAddressRefs = {};
    final Map<String, Map<String, dynamic>> parsedObreby = {};
    final Map<String, Map<String, dynamic>> parsedJednostkiEwid = {};
    final Map<String, String> parcelObrebRefs = {};

    try {
      final gmlContent = utf8.decode(fileBytes);
      final document = XmlDocument.parse(gmlContent);
      final featureMembers = document.findAllElements(
        'featureMember',
        namespace: _gmlNs,
      );

      for (final member in featureMembers) {
        final element = member.children
            .whereType<XmlElement>()
            .firstOrNull;
        if (element == null) continue;

        final tagName = element.name.local;

        switch (tagName) {
          case 'EGB_DzialkaEwidencyjna':
            // --- Parsowanie Geometrii ---
            final List<Map<String, double>> geometry = [];
            final geomElement = _firstElementByLocal(element, 'geometria');
            if (geomElement != null) {
              final posList = geomElement
                  .findAllElements('posList', namespace: _gmlNs)
                  .firstOrNull;
              
              if (posList != null) {
                final coords = posList.innerText.trim().split(RegExp(r'\s+'));
                for (int i = 0; i < coords.length - 1; i += 2) {
                  final val1 = double.tryParse(coords[i]);
                  final val2 = double.tryParse(coords[i + 1]);
                  if (val1 != null && val2 != null) {
                    geometry.add({'x': val1, 'y': val2});
                  }
                }
              }
            }

            final parcelMap = _parseParcel(element);
            if (parcelMap != null) {
              parcelMap['geometry'] = geometry;
              
              parsedParcels.add(parcelMap);

              final List<String> adresRefs = _parseParcelAddressRefs(element);
              if (adresRefs.isNotEmpty) {
                parsedParcelAddressRefs[parcelMap['gmlId']] = adresRefs;
              }

              final String? lokalizacjaHref = _firstElementByLocal(
                element,
                'lokalizacjaDzialki',
              )?.getAttribute('xlink:href');
              final String? lokalizacjaId = _stripHref(lokalizacjaHref);
              if (lokalizacjaId != null && lokalizacjaId.isNotEmpty) {
                parcelObrebRefs[parcelMap['gmlId']] = lokalizacjaId;
              }
            }
            break;

          case 'EGB_PunktGraniczny':
            final point = _parseBoundaryPoint(element);
            if (point != null) {
              parsedPoints[point['gmlId']] = point;
            }
            break;

          case 'EGB_OsobaFizyczna':
          case 'EGB_Instytucja':
            final subject = (tagName == 'EGB_OsobaFizyczna') 
                ? _parseOsobaFizyczna(element) 
                : _parseInstytucja(element);
            
            if (subject != null) {
              parsedSubjects[subject['gmlId']] = subject;
              final List<String> adresRefs = _parseSubjectAddressRefs(element);
              if (adresRefs.isNotEmpty) {
                parsedSubjectAddressRefs[subject['gmlId']] = adresRefs;
              }
            }
            break;

          case 'EGB_JednostkaRejestrowaGruntow':
            final regUnit = _parseRegUnit(element);
            if (regUnit != null) {
              parsedRegUnits[regUnit['gmlId']] = regUnit;
            }
            break;

          case 'EGB_ObrebEwidencyjny':
            final String? gmlIdObrebu = element.getAttribute('gml:id');
            if (gmlIdObrebu != null) {
              parsedObreby[gmlIdObrebu] = {
                'idObrebu': _getElementText(element, 'idObrebu'),
                'nazwa': _getElementText(element, 'nazwaWlasna'),
                'jednostkaHref': _firstElementByLocal(element, 'lokalizacjaObrebu')?.getAttribute('xlink:href'),
              };
            }
            break;

          case 'EGB_JednostkaEwidencyjna':
            final String? gmlIdJedn = element.getAttribute('gml:id');
            if (gmlIdJedn != null) {
              parsedJednostkiEwid[gmlIdJedn] = {
                'idJednostkiEwid': _getElementText(element, 'idJednostkiEwid'),
                'nazwa': _getElementText(element, 'nazwaWlasna'),
              };
            }
            break;

          case 'EGB_UdzialWeWlasnosci':
            final share = _parseShare(element);
            if (share != null && share['jrgId'] != null) {
              final jrgId = share['jrgId'] as String;
              parsedShares.putIfAbsent(jrgId, () => []).add(share);
            }
            break;

          case 'EGB_AdresStalegoPobytu':
          case 'EGB_AdresZameldowania':
            final adr = _parseAdresStalegoPobytu(element);
            if (adr != null) parsedAddresses[adr['gmlId']] = adr;
            break;
          
          case 'EGB_AdresNieruchomosci':
            final adrNier = _parseAdresNieruchomosci(element);
            if (adrNier != null) parsedAddresses[adrNier['gmlId']] = adrNier;
            break;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Błąd parsowania XML: $e');
      throw Exception('Błąd parsowania XML: $e');
    }

    return {
      'parcels': parsedParcels,
      'subjects': parsedSubjects,
      'regUnits': parsedRegUnits,
      'shares': parsedShares,
      'points': parsedPoints,
      'addresses': parsedAddresses,
      'subjectAddressRefs': parsedSubjectAddressRefs,
      'parcelAddressRefs': parsedParcelAddressRefs,
      'obreby': parsedObreby,
      'jednostkiEwid': parsedJednostkiEwid,
      'parcelObrebRefs': parcelObrebRefs,
    };
  }

  void _setParsedData(Map<String, dynamic> parsedData) {
    if (parsedData.isEmpty) return;

    final obrebyData = parsedData['obreby'] as Map? ?? {};
    final jednostkiEwidData = parsedData['jednostkiEwid'] as Map? ?? {};
    final parcelObrebRefsData = parsedData['parcelObrebRefs'] as Map? ?? {};
    final addressesData = parsedData['addresses'] as Map? ?? {};

    // Odtwarzanie Adresów
    final Map<String, Address> addressesById = {};
    addressesData.forEach((key, value) {
      final map = value as Map;
      addressesById[key.toString()] = Address(
        gmlId: map['gmlId'],
        kraj: map['kraj'],
        miejscowosc: map['miejscowosc'],
        kodPocztowy: map['kodPocztowy'],
        ulica: map['ulica'],
        numerPorzadkowy: map['numerPorzadkowy'],
      );
    });

    // Odtwarzanie Punktów Granicznych
    final pointsData = parsedData['points'] as Map? ?? {};
    pointsData.forEach((key, value) {
      final map = value as Map;
      boundaryPoints[key.toString()] = BoundaryPoint(
        gmlId: map['gmlId'],
        pelneId: map['pelneId'],
        numer: map['numer'],
        x: map['x'],
        y: map['y'],
        isd: map['isd'],
        stb: map['stb'],
        spd: map['spd'],
        operat: map['operat'],
      );
    });

    // Odtwarzanie Podmiotów
    final subjectsData = parsedData['subjects'] as Map? ?? {};
    subjectsData.forEach((key, value) {
      final map = value as Map;
      subjects[key.toString()] = Subject(
        gmlId: map['gmlId'],
        name: map['name'],
        type: map['type'],
      );
    });

    // Odtwarzanie JRG
    final regUnitsData = parsedData['regUnits'] as Map? ?? {};
    regUnitsData.forEach((key, value) {
      final map = value as Map;
      registrationUnits[key.toString()] = RegistrationUnit(
        gmlId: map['gmlId'],
        idJRG: map['idJRG'],
      );
    });

    // Odtwarzanie Udziałów
    final sharesData = parsedData['shares'] as Map? ?? {};
    sharesData.forEach((jrgId, value) {
      final list = value as List;
      sharesByJrgId[jrgId.toString()] = list.map((s) {
        final map = s as Map;
        return OwnershipShare(
          gmlId: map['gmlId'],
          jrgId: map['jrgId'],
          subjectId: map['subjectId'],
          share: map['share'],
        );
      }).toList();
    });

    // Odtwarzanie Działek
    final parcelsData = parsedData['parcels'] as List? ?? [];
    for (final p in parcelsData) {
      final map = p as Map;
      
      // Rekonstrukcja LandUse
      final uzytki = (map['uzytki'] as List).map((u) {
        final uMap = u as Map;
        return LandUse(
          ofu: uMap['ofu'],
          ozu: uMap['ozu'],
          ozk: uMap['ozk'],
          powierzchnia: uMap['powierzchnia'],
        );
      }).toList();

      // Rekonstrukcja Geometrii
      final List<ParsedPoint> geomPoints = [];
      if (map['geometry'] != null) {
        for (var pointMap in (map['geometry'] as List)) {
          geomPoints.add(ParsedPoint(pointMap['x'], pointMap['y']));
        }
      }

      // Kontekst Obrebu/Jednostki
      String? obrebId, obrebNazwa, jednostkaId, jednostkaNazwa;
      final String parcelGmlId = map['gmlId'];
      final String? obrebRefId = parcelObrebRefsData[parcelGmlId];
      
      if (obrebRefId != null) {
        final obrebInfo = obrebyData[obrebRefId] as Map?;
        if (obrebInfo != null) {
          obrebId = obrebInfo['idObrebu'];
          obrebNazwa = obrebInfo['nazwa'];
          
          final jednostkaHref = obrebInfo['jednostkaHref'];
          final jednostkaGmlId = _stripHref(jednostkaHref);
          if (jednostkaGmlId != null) {
            final jednInfo = jednostkiEwidData[jednostkaGmlId] as Map?;
            if (jednInfo != null) {
              jednostkaId = jednInfo['idJednostkiEwid'];
              jednostkaNazwa = jednInfo['nazwa'];
            }
          }
        }
      }

      parcels.add(Parcel(
        gmlId: parcelGmlId,
        idDzialki: map['idDzialki'],
        numerDzialki: map['numerDzialki'],
        numerKW: map['numerKW'],
        pole: map['pole'],
        uzytki: uzytki,
        jrgId: map['jrgId'],
        pointRefs: (map['pointRefs'] as List).cast<String>(),
        geometryPoints: geomPoints,
        obrebId: obrebId,
        obrebNazwa: obrebNazwa,
        jednostkaId: jednostkaId,
        jednostkaNazwa: jednostkaNazwa,
      ));
    }

    // Sortowanie działek
    parcels.sort((a, b) => a.pelnyNumerDzialki.compareTo(b.pelnyNumerDzialki));

    // Relacje adresowe
    subjectAddresses.clear();
    final subAddrRefs = parsedData['subjectAddressRefs'] as Map? ?? {};
    subAddrRefs.forEach((subId, addrList) {
      final ids = (addrList as List).cast<String>();
      subjectAddresses[subId.toString()] = ids
          .map((id) => addressesById[id])
          .whereType<Address>()
          .toList();
    });
    if (kDebugMode) {
      print('Subject Addresses: $subjectAddresses');
    }

    parcelAddresses.clear();
    final parcAddrRefs = parsedData['parcelAddressRefs'] as Map? ?? {};
    parcAddrRefs.forEach((parcId, addrList) {
      final ids = (addrList as List).cast<String>();
      parcelAddresses[parcId.toString()] = ids
          .map((id) => addressesById[id])
          .whereType<Address>()
          .toList();
    });
  }

  // --- Metody dostępowe (API dla UI) ---

  List<MapEntry<OwnershipShare, Subject?>> getSubjectsForParcel(Parcel parcel) {
    if (parcel.jrgId == null) return [];
    final shares = sharesByJrgId[parcel.jrgId] ?? [];
    return shares.map((share) {
      final subject = share.subjectId != null ? subjects[share.subjectId!] : null;
      return MapEntry(share, subject);
    }).toList();
  }

  List<BoundaryPoint> getPointsForParcel(Parcel parcel) {
    return parcel.pointRefs
        .map((id) => boundaryPoints[id])
        .whereType<BoundaryPoint>()
        .toList();
  }

  List<Address> getAddressesForParcel(Parcel parcel) {
    return parcelAddresses[parcel.gmlId] ?? [];
  }
  
  List<Address> getAddressesForSubject(Subject subject) {
    return subjectAddresses[subject.gmlId] ?? [];
  }

  // --- Parsery XML (prywatne, statyczne) ---

  static Map<String, dynamic>? _parseParcel(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    final idDzialki = _getElementText(element, 'idDzialki');
    if (gmlId == null || idDzialki == null) return null;

    final numerKW = _getElementText(element, 'numerKW');
    final poleStr = _getElementText(element, 'poleEwidencyjne');
    
    final jrgHref = _firstElementByLocal(element, 'JRG2')?.getAttribute('xlink:href') ??
                    _firstElementByLocal(element, 'JRG')?.getAttribute('xlink:href');
    
    final uzytki = <Map<String, dynamic>>[];
    for (final u in element.descendants.whereType<XmlElement>().where((e) => e.name.local == 'EGB_Klasouzytek')) {
      uzytki.add({
        'ofu': _getElementText(u, 'OFU') ?? '?',
        'ozu': _getElementText(u, 'OZU') ?? '?',
        'ozk': _getElementText(u, 'OZK'),
        'powierzchnia': double.tryParse(_getElementText(u, 'powierzchnia') ?? ''),
      });
    }

    final pointIds = <String>[];
    final pktElems = element.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'punktGraniczny' || e.name.local == 'punktGranicyDzialki'
    );
    for (final pkt in pktElems) {
      final id = _stripHref(pkt.getAttribute('xlink:href'));
      if (id != null) pointIds.add(id);
    }

    final parts = idDzialki.split('.');
    final numerDzialki = parts.isNotEmpty ? parts.last : idDzialki;

    return {
      'gmlId': gmlId,
      'idDzialki': idDzialki,
      'numerDzialki': numerDzialki,
      'numerKW': numerKW,
      'pole': double.tryParse(poleStr ?? ''),
      'uzytki': uzytki,
      'jrgId': _stripHref(jrgHref),
      'pointRefs': pointIds,
    };
  }

  static Map<String, dynamic>? _parseBoundaryPoint(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final idPunktu = _getElementText(element, 'idPunktu');
    final numer = _getElementText(element, 'oznaczenieWMaterialeZrodlowym') ??
                  _getElementText(element, 'oznWMaterialeZrodlowym') ??
                  _getElementText(element, 'idPunktu'); 
    String? x, y;
    final posElement = element.findAllElements('pos', namespace: _gmlNs).firstOrNull;
    if (posElement != null) {
      final coords = posElement.innerText.trim().split(RegExp(r'\s+'));
      if (coords.length >= 2) {
        x = coords[0];
        y = coords[1];
      }
    }

    final spdRaw = _getElementText(element, 'sposobPozyskania');
    final isdRaw = _getElementText(element, 'spelnienieWarunkowDokl');
    final stbRaw = _getElementText(element, 'rodzajStabilizacji');

    return {
      'gmlId': gmlId,
      'pelneId': idPunktu ?? gmlId,
      'numer': numer,
      'x': x,
      'y': y,
      'spd': _mapSpd(spdRaw),
      'isd': _mapIsd(isdRaw),
      'stb': _mapStb(stbRaw),
      'operat': _getElementText(element, 'identyfikatorOperatuWgPZGIK') ?? _getElementText(element, 'numerOperatuTechnicznego'),
    };
  }

  static Map<String, dynamic>? _parseOsobaFizyczna(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final imie = _getElementText(element, 'imiePierwsze') ?? _getElementText(element, 'pierwszeImie');
    final nazwisko = _getElementText(element, 'nazwisko') ?? _getElementText(element, 'pierwszyCzlonNazwiska');
    
    final czlon1 = _getElementText(element, 'nazwiskoPierwszegoCzlonu') ?? _getElementText(element, 'pierwszyCzlonNazwiska');
    final czlon2 = _getElementText(element, 'nazwiskoDrugiegoCzlonu') ?? _getElementText(element, 'drugiCzlonNazwiska');

    String name = imie ?? '';
    if (nazwisko != null) {
      name += ' $nazwisko';
    } else if (czlon1 != null) {
      name += ' $czlon1';
      if (czlon2 != null) name += '-$czlon2';
    }
    
    return {'gmlId': gmlId, 'name': name.trim(), 'type': 'Osoba fizyczna'};
  }

  static Map<String, dynamic>? _parseInstytucja(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    return {
      'gmlId': gmlId,
      'name': _getElementText(element, 'nazwaPelna') ?? 'Instytucja',
      'type': 'Instytucja'
    };
  }

  static Map<String, dynamic>? _parseShare(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final l = _getElementText(element, 'licznikUlamkaOkreslajacegoWartoscUdzialu') ?? '1';
    final m = _getElementText(element, 'mianownikUlamkaOkreslajacegoWartoscUdzialu') ?? '1';
    
    // Szukanie referencji
    final jrgRef = _firstElementByLocal(element, 'JRG')?.getAttribute('xlink:href');
    
    String? subRef;
    final subElem = _firstElementByLocal(element, 'osobaFizyczna') ?? 
                    _firstElementByLocal(element, 'instytucja1') ??
                    _firstElementByLocal(element, 'instytucja');
    subRef = subElem?.getAttribute('xlink:href');

    return {
      'gmlId': gmlId,
      'jrgId': _stripHref(jrgRef),
      'subjectId': _stripHref(subRef),
      'share': '$l/$m',
    };
  }

  static Map<String, dynamic>? _parseRegUnit(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    final idJRG = _getElementText(element, 'idJednostkiRejestrowej');
    if (gmlId == null || idJRG == null) return null;
    return {'gmlId': gmlId, 'idJRG': idJRG};
  }

  static Map<String, dynamic>? _parseAdresStalegoPobytu(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    return {
      'gmlId': gmlId,
      'kraj': _getElementText(element, 'kraj'),
      'miejscowosc': _getElementText(element, 'miejscowosc') ?? _getElementText(element, 'nazwaMiejscowosci'),
      'kodPocztowy': _getElementText(element, 'kodPocztowy'),
      'ulica': _getElementText(element, 'ulica') ?? _getElementText(element, 'nazwaUlicy'),
      'numerPorzadkowy': _getElementText(element, 'numerPorzadkowy'),
    };
  }
  
  static Map<String, dynamic>? _parseAdresNieruchomosci(XmlElement element) {
     return _parseAdresStalegoPobytu(element);
  }

  static List<String> _parseSubjectAddressRefs(XmlElement element) {
    final res = <String>[];
    final addressElement = _firstElementByLocal(element, 'adresOsobyFizycznej') ??
                           _firstElementByLocal(element, 'adresInstytucji');
    if (addressElement != null) {
      final id = _stripHref(addressElement.getAttribute('xlink:href'));
      if (id != null) res.add(id);
    }
    return res;
  }

  static List<String> _parseParcelAddressRefs(XmlElement element) {
     final res = <String>[];
     for (final e in element.descendants.whereType<XmlElement>()) {
       if (e.name.local == 'adresDzialki') {
          final id = _stripHref(e.getAttribute('xlink:href'));
          if (id != null) res.add(id);
       }
     }
     return res;
  }

  // Helpery
  static XmlElement? _firstElementByLocal(XmlElement parent, String localName) {
    for (final node in parent.descendants) {
      if (node is XmlElement && node.name.local == localName) return node;
    }
    return null;
  }

  static String? _getElementText(XmlElement parent, String localName) {
    return _firstElementByLocal(parent, localName)?.innerText.trim();
  }

  static String? _stripHref(String? href) {
    if (href == null) return null;
    return href.startsWith('#') ? href.substring(1) : href;
  }

  static String? _mapSpd(String? value) {
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case '1':
        return 'ustalony (1)';
      case '2':
        return 'nieustalony (2)';
      default:
        return value;
    }
  }

  static String? _mapIsd(String? value) {
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case '1':
        return 'spełnia (1)';
      case '2':
        return 'nie spełnia (2)';
      default:
        return value;
    }
  }

  static String? _mapStb(String? value) {
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case '1':
        return 'brak informacji (1)';
      case '2':
        return 'niestabilizowany (2)';
      case '3':
        return 'znak naziemny (3)';
      case '4':
        return 'znak naziemny i podziemny (4)';
      case '5':
        return 'znak podziemny (5)';
      case '6':
        return 'szczegół terenowy (6)';
      default:
        return value;
    }
  }
}
