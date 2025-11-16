import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

// --- MODELE ---

class Parcel {
  final String gmlId;
  final String idDzialki;
  final String jednostkaEwidencyjna;
  final String obreb;
  final String numerDzialki;
  final String? numerKW;
  final double? pole;
  final List<LandUse> uzytki;
  final String? jrgId;
  final List<String> pointRefs;
  final String? jednostkaId;
  final String? jednostkaNazwa;
  final String? obrebId;
  final String? obrebNazwa;

  Parcel({
    required this.gmlId,
    required this.idDzialki,
    this.numerKW,
    this.pole,
    this.uzytki = const [],
    this.jrgId,
    this.pointRefs = const [],
    this.jednostkaId,
    this.jednostkaNazwa,
    this.obrebId,
    this.obrebNazwa,
  }) : jednostkaEwidencyjna = _parseIdPart(idDzialki, 0),
       obreb = _parseIdPart(idDzialki, 1),
       numerDzialki = _parseIdPart(idDzialki, 2);

  static String _parseIdPart(String id, int part) {
    try {
      final parts = id.split('.');
      if (parts.length > part) {
        return parts[part];
      }
    } catch (_) {}
    return '';
  }

  String get pelnyNumerDzialki {
    return '$jednostkaEwidencyjna.$obreb.$numerDzialki';
  }
}

class LandUse {
  final String ofu;
  final String ozu;
  final String? ozk;
  final double? powierzchnia;

  LandUse({required this.ofu, required this.ozu, this.ozk, this.powierzchnia});

  @override
  String toString() {
    final ozkStr = ozk != null ? '/$ozk' : '';
    final powStr = powierzchnia != null
        ? ' (${powierzchnia.toString()} ha)'
        : '';
    return '$ofu$ozkStr ($ozu)$powStr';
  }
}

class Subject {
  final String gmlId;
  final String name;
  final String type;

  Subject({required this.gmlId, required this.name, required this.type});
}

class RegistrationUnit {
  final String gmlId;
  final String idJRG;

  RegistrationUnit({required this.gmlId, required this.idJRG});
}

class OwnershipShare {
  final String gmlId;
  final String? jrgId;
  final String? subjectId;
  final String share;

  OwnershipShare({
    required this.gmlId,
    this.jrgId,
    this.subjectId,
    required this.share,
  });
}

class BoundaryPoint {
  final String gmlId;
  final String? numer;
  final String? x;
  final String? y;
  final String? isd;
  final String? stb;
  final String? spd;
  final String? operat;

  BoundaryPoint({
    required this.gmlId,
    this.numer,
    this.x,
    this.y,
    this.isd,
    this.stb,
    this.spd,
    this.operat,
  });
}

class Address {
  final String gmlId;
  final String? kraj;
  final String? miejscowosc;
  final String? kodPocztowy;
  final String? ulica;
  final String? numerPorzadkowy;

  Address({
    required this.gmlId,
    this.kraj,
    this.miejscowosc,
    this.kodPocztowy,
    this.ulica,
    this.numerPorzadkowy,
  });

  String toSingleLine() {
    final List<String> parts = [];

    final String streetAndNumber = [
      ulica,
      numerPorzadkowy,
    ].where((String? v) => v != null && v.trim().isNotEmpty).join(' ');
    if (streetAndNumber.isNotEmpty) {
      parts.add(streetAndNumber);
    }

    final String cityAndPostal = [
      kodPocztowy,
      miejscowosc,
    ].where((String? v) => v != null && v.trim().isNotEmpty).join(' ');
    if (cityAndPostal.isNotEmpty) {
      parts.add(cityAndPostal);
    }

    if (kraj != null && kraj!.trim().isNotEmpty) {
      parts.add(kraj!);
    }

    if (parts.isEmpty) {
      return 'Brak danych adresowych';
    }
    return parts.join(', ');
  }

  @override
  String toString() => toSingleLine();
}

// --- SERWIS ---

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

    if (kDebugMode) {
      final sharesCount = sharesByJrgId.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );
      // ignore: avoid_print
      print(
        'GML parsed: ${parcels.length} parcels, '
        '${subjects.length} subjects, '
        '${registrationUnits.length} reg units, '
        '${boundaryPoints.length} boundary points, '
        '$sharesCount ownership shares.',
      );
    }
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
            .cast<XmlElement?>()
            .firstOrNull;
        if (element == null) continue;

        final tagName = element.name.local;

        switch (tagName) {
          case 'EGB_DzialkaEwidencyjna':
            final parcel = _parseParcel(element);
            if (parcel != null) {
              parsedParcels.add({
                'gmlId': parcel.gmlId,
                'idDzialki': parcel.idDzialki,
                'numerKW': parcel.numerKW,
                'pole': parcel.pole,
                'uzytki': parcel.uzytki
                    .map(
                      (u) => {
                        'ofu': u.ofu,
                        'ozu': u.ozu,
                        'ozk': u.ozk,
                        'powierzchnia': u.powierzchnia,
                      },
                    )
                    .toList(),
                'jrgId': parcel.jrgId,
                'pointRefs': parcel.pointRefs,
              });

              final List<String> adresRefs = _parseParcelAddressRefs(element);
              if (adresRefs.isNotEmpty) {
                parsedParcelAddressRefs[parcel.gmlId] = adresRefs;
              }

              final String? lokalizacjaHref = _firstElementByLocal(
                element,
                'lokalizacjaDzialki',
              )?.getAttribute('xlink:href');
              final String? lokalizacjaId = _stripHref(lokalizacjaHref);
              if (lokalizacjaId != null && lokalizacjaId.isNotEmpty) {
                parcelObrebRefs[parcel.gmlId] = lokalizacjaId;
              }
            }
            break;
          case 'EGB_OsobaFizyczna':
            final subject = _parseOsobaFizyczna(element);
            if (subject != null) {
              parsedSubjects[subject.gmlId] = {
                'gmlId': subject.gmlId,
                'name': subject.name,
                'type': subject.type,
              };

              final List<String> adresRefs = _parseSubjectAddressRefs(element);
              if (adresRefs.isNotEmpty) {
                parsedSubjectAddressRefs[subject.gmlId] = adresRefs;
              }
            }
            break;
          case 'EGB_Instytucja':
            final subject = _parseInstytucja(element);
            if (subject != null) {
              parsedSubjects[subject.gmlId] = {
                'gmlId': subject.gmlId,
                'name': subject.name,
                'type': subject.type,
              };

              final List<String> adresRefs = _parseSubjectAddressRefs(element);
              if (adresRefs.isNotEmpty) {
                parsedSubjectAddressRefs[subject.gmlId] = adresRefs;
              }
            }
            break;
          case 'EGB_JednostkaRejestrowaGruntow':
            final regUnit = _parseRegUnit(element);
            if (regUnit != null) {
              parsedRegUnits[regUnit.gmlId] = {
                'gmlId': regUnit.gmlId,
                'idJRG': regUnit.idJRG,
              };
            }
            break;
          case 'EGB_ObrebEwidencyjny':
            final String? gmlIdObrebu = element.getAttribute('gml:id');
            if (gmlIdObrebu != null) {
              final String? idObrebu = _getElementText(element, 'idObrebu');
              final String? nazwaObrebu = _getElementText(
                element,
                'nazwaWlasna',
              );
              final String? jednostkaHref = _firstElementByLocal(
                element,
                'lokalizacjaObrebu',
              )?.getAttribute('xlink:href');

              parsedObreby[gmlIdObrebu] = <String, dynamic>{
                'idObrebu': idObrebu,
                'nazwa': nazwaObrebu,
                'jednostkaHref': jednostkaHref,
              };
            }
            break;
          case 'EGB_JednostkaEwidencyjna':
            final String? gmlIdJedn = element.getAttribute('gml:id');
            if (gmlIdJedn != null) {
              final String? idJednostki = _getElementText(
                element,
                'idJednostkiEwid',
              );
              final String? nazwaJednostki = _getElementText(
                element,
                'nazwaWlasna',
              );
              parsedJednostkiEwid[gmlIdJedn] = <String, dynamic>{
                'idJednostkiEwid': idJednostki,
                'nazwa': nazwaJednostki,
              };
            }
            break;
          case 'EGB_UdzialWeWlasnosci':
            final share = _parseShare(element);
            if (share != null && share.jrgId != null) {
              final jrgId = share.jrgId!;
              parsedShares.putIfAbsent(jrgId, () => []);
              parsedShares[jrgId]!.add({
                'gmlId': share.gmlId,
                'jrgId': share.jrgId,
                'subjectId': share.subjectId,
                'share': share.share,
              });
            }
            break;
          case 'EGB_PunktGraniczny':
            final point = _parseBoundaryPoint(element);
            if (point != null) {
              parsedPoints[point.gmlId] = {
                'gmlId': point.gmlId,
                'numer': point.numer,
                'x': point.x,
                'y': point.y,
                'isd': point.isd,
                'stb': point.stb,
                'spd': point.spd,
                'operat': point.operat,
              };
            }
            break;
          case 'EGB_AdresStalegoPobytu':
            final Map<String, dynamic>? adresStalego = _parseAdresStalegoPobytu(
              element,
            );
            if (adresStalego != null) {
              final String gmlId = adresStalego['gmlId'] as String;
              parsedAddresses[gmlId] = adresStalego;
            }
            break;
          case 'EGB_AdresZameldowania':
            final Map<String, dynamic>? adresZameldowania =
                _parseAdresStalegoPobytu(element);
            if (adresZameldowania != null) {
              final String gmlId = adresZameldowania['gmlId'] as String;
              parsedAddresses[gmlId] = adresZameldowania;
            }
            break;
          case 'EGB_AdresNieruchomosci':
            final Map<String, dynamic>? adresnieruchomosci =
                _parseAdresNieruchomosci(element);
            if (adresnieruchomosci != null) {
              final String gmlId = adresnieruchomosci['gmlId'] as String;
              parsedAddresses[gmlId] = adresnieruchomosci;
            }
            break;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Błąd parsowania XML: $e');
      }
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

    final Map<String, dynamic> obrebyData =
        parsedData['obreby'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic> jednostkiEwidData =
        parsedData['jednostkiEwid'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final Map<String, dynamic> parcelObrebRefsData =
        parsedData['parcelObrebRefs'] as Map<String, dynamic>? ??
        <String, dynamic>{};

    final Map<String, Address> addressesById = {};
    final addressesData =
        parsedData['addresses'] as Map<String, dynamic>? ?? {};
    addressesData.forEach((String key, dynamic value) {
      final map = value as Map<dynamic, dynamic>;
      final address = Address(
        gmlId: map['gmlId'] as String,
        kraj: map['kraj'] as String?,
        miejscowosc: map['miejscowosc'] as String?,
        kodPocztowy: map['kodPocztowy'] as String?,
        ulica: map['ulica'] as String?,
        numerPorzadkowy: map['numerPorzadkowy'] as String?,
      );
      addressesById[key] = address;
    });

    final parcelsData = parsedData['parcels'] as List<dynamic>? ?? [];
    for (final dynamic p in parcelsData) {
      final map = p as Map<dynamic, dynamic>;
      final uzytkiData = map['uzytki'] as List<dynamic>? ?? [];
      final uzytki = uzytkiData
          .map(
            (dynamic u) => LandUse(
              ofu: (u as Map<dynamic, dynamic>)['ofu'] as String? ?? '?',
              ozu: u['ozu'] as String? ?? '?',
              ozk: u['ozk'] as String?,
              powierzchnia: (u['powierzchnia'] as num?)?.toDouble(),
            ),
          )
          .toList();

      final String parcelGmlId = map['gmlId'] as String;

      String? obrebId;
      String? obrebNazwa;
      String? jednostkaId;
      String? jednostkaNazwa;

      final String? obrebRefId = parcelObrebRefsData[parcelGmlId] as String?;
      if (obrebRefId != null) {
        final Map<dynamic, dynamic>? obrebData =
            obrebyData[obrebRefId] as Map<dynamic, dynamic>?;
        if (obrebData != null) {
          obrebId = obrebData['idObrebu'] as String?;
          obrebNazwa = obrebData['nazwa'] as String?;

          final String? jednostkaHref = obrebData['jednostkaHref'] as String?;
          final String? jednostkaGmlId = _stripHref(jednostkaHref);
          if (jednostkaGmlId != null) {
            final Map<dynamic, dynamic>? jednData =
                jednostkiEwidData[jednostkaGmlId] as Map<dynamic, dynamic>?;
            if (jednData != null) {
              jednostkaId = jednData['idJednostkiEwid'] as String?;
              jednostkaNazwa = jednData['nazwa'] as String?;
            }
          }
        }
      }

      parcels.add(
        Parcel(
          gmlId: parcelGmlId,
          idDzialki: map['idDzialki'] as String,
          numerKW: map['numerKW'] as String?,
          pole: (map['pole'] as num?)?.toDouble(),
          uzytki: uzytki,
          jrgId: map['jrgId'] as String?,
          pointRefs: (map['pointRefs'] as List<dynamic>? ?? []).cast<String>(),
          jednostkaId: jednostkaId,
          jednostkaNazwa: jednostkaNazwa,
          obrebId: obrebId,
          obrebNazwa: obrebNazwa,
        ),
      );
    }

    parcels.sort((a, b) => a.pelnyNumerDzialki.compareTo(b.pelnyNumerDzialki));

    final subjectsData = parsedData['subjects'] as Map<String, dynamic>? ?? {};
    subjectsData.forEach((key, dynamic value) {
      final map = value as Map<dynamic, dynamic>;
      subjects[key] = Subject(
        gmlId: map['gmlId'] as String,
        name: map['name'] as String,
        type: map['type'] as String,
      );
    });

    final regUnitsData = parsedData['regUnits'] as Map<String, dynamic>? ?? {};
    regUnitsData.forEach((key, dynamic value) {
      final map = value as Map<dynamic, dynamic>;
      registrationUnits[key] = RegistrationUnit(
        gmlId: map['gmlId'] as String,
        idJRG: map['idJRG'] as String,
      );
    });

    final sharesData = parsedData['shares'] as Map<String, dynamic>? ?? {};
    sharesData.forEach((jrgId, dynamic value) {
      final list = value as List<dynamic>;
      sharesByJrgId[jrgId] = list
          .map((dynamic s) => s as Map<dynamic, dynamic>)
          .map(
            (map) => OwnershipShare(
              gmlId: map['gmlId'] as String,
              jrgId: map['jrgId'] as String?,
              subjectId: map['subjectId'] as String?,
              share: map['share'] as String,
            ),
          )
          .toList();
    });

    final pointsData = parsedData['points'] as Map<String, dynamic>? ?? {};
    pointsData.forEach((key, dynamic value) {
      final map = value as Map<dynamic, dynamic>;
      boundaryPoints[key] = BoundaryPoint(
        gmlId: map['gmlId'] as String,
        numer: map['numer'] as String?,
        x: map['x'] as String?,
        y: map['y'] as String?,
        isd: map['isd'] as String?,
        stb: map['stb'] as String?,
        spd: map['spd'] as String?,
        operat: map['operat'] as String?,
      );
    });

    final subjectAddressRefsData =
        parsedData['subjectAddressRefs'] as Map<String, dynamic>? ?? {};
    subjectAddresses.clear();
    subjectAddressRefsData.forEach((String subjectId, dynamic value) {
      final List<String> ids = (value as List<dynamic>).cast<String>();
      subjectAddresses[subjectId] = ids
          .map((String id) => addressesById[id])
          .whereType<Address>()
          .toList();
    });

    final parcelAddressRefsData =
        parsedData['parcelAddressRefs'] as Map<String, dynamic>? ?? {};
    parcelAddresses.clear();
    parcelAddressRefsData.forEach((String parcelId, dynamic value) {
      final List<String> ids = (value as List<dynamic>).cast<String>();
      parcelAddresses[parcelId] = ids
          .map((String id) => addressesById[id])
          .whereType<Address>()
          .toList();
    });
  }

  List<MapEntry<OwnershipShare, Subject?>> getSubjectsForParcel(Parcel parcel) {
    if (parcel.jrgId == null) return [];

    final shares = sharesByJrgId[parcel.jrgId] ?? [];
    final List<MapEntry<OwnershipShare, Subject?>> result = [];

    for (final share in shares) {
      final subject = share.subjectId != null
          ? subjects[share.subjectId!]
          : null;
      result.add(MapEntry(share, subject));
    }
    return result;
  }

  List<BoundaryPoint> getPointsForParcel(Parcel parcel) {
    if (parcel.pointRefs.isEmpty) return [];

    final List<BoundaryPoint> result = [];
    for (final id in parcel.pointRefs) {
      final point = boundaryPoints[id];
      if (point != null) {
        result.add(point);
      }
    }
    return result;
  }

  List<Address> getAddressesForParcel(Parcel parcel) {
    return parcelAddresses[parcel.gmlId] ?? <Address>[];
  }

  List<Address> getAddressesForSubject(Subject subject) {
    return subjectAddresses[subject.gmlId] ?? <Address>[];
  }

  /// Zwraca pierwszy element potomny o podanej nazwie lokalnej (ignoruje prefix).
  static XmlElement? _firstElementByLocal(
    XmlElement parent,
    String localName, {
    String? namespace,
  }) {
    for (final node in parent.descendants) {
      if (node is XmlElement) {
        if (node.name.local == localName &&
            (namespace == null || node.name.namespaceUri == namespace)) {
          return node;
        }
      }
    }
    return null;
  }

  static Parcel? _parseParcel(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    final idDzialki = _getElementText(element, 'idDzialki');
    if (gmlId == null || idDzialki == null) return null;

    final numerKW = _getElementText(element, 'numerKW');
    final poleStr = _getElementText(element, 'poleEwidencyjne');

    final jrgHref =
        _firstElementByLocal(element, 'JRG2')?.getAttribute('xlink:href') ??
        _firstElementByLocal(element, 'JRG')?.getAttribute('xlink:href');
    final jrgId = _stripHref(jrgHref);

    final List<LandUse> uzytki = [];
    final klasouzytki = element.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'EGB_Klasouzytek',
    );
    for (final egbKlasouzytek in klasouzytki) {
      final ofu = _getElementText(egbKlasouzytek, 'OFU');
      final ozu = _getElementText(egbKlasouzytek, 'OZU');
      final ozk = _getElementText(egbKlasouzytek, 'OZK');
      final powStr = _getElementText(egbKlasouzytek, 'powierzchnia');
      uzytki.add(
        LandUse(
          ofu: ofu ?? '?',
          ozu: ozu ?? '?',
          ozk: ozk,
          powierzchnia: double.tryParse(powStr ?? ''),
        ),
      );
    }

    final List<String> pointIds = [];
    final punktyGraniczne = element.descendants.whereType<XmlElement>().where(
      (e) =>
          e.name.local == 'punktGraniczny' ||
          e.name.local == 'punktGranicyDzialki',
    );
    for (final pkt in punktyGraniczne) {
      final href = pkt.getAttribute('xlink:href');
      final id = _stripHref(href);
      if (id != null) {
        pointIds.add(id);
      }
    }

    return Parcel(
      gmlId: gmlId,
      idDzialki: idDzialki,
      numerKW: numerKW,
      pole: double.tryParse(poleStr ?? ''),
      uzytki: uzytki,
      jrgId: jrgId,
      pointRefs: pointIds,
    );
  }

  static Subject? _parseOsobaFizyczna(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final imie =
        _getElementText(element, 'imiePierwsze') ??
        _getElementText(element, 'pierwszeImie');
    final nazwisko =
        _getElementText(element, 'nazwisko') ??
        _getElementText(element, 'pierwszyCzlonNazwiska');
    final nazwiskoCzlon1 =
        _getElementText(element, 'nazwiskoPierwszegoCzlonu') ??
        _getElementText(element, 'pierwszyCzlonNazwiska');
    final nazwiskoCzlon2 =
        _getElementText(element, 'nazwiskoDrugiegoCzlonu') ??
        _getElementText(element, 'drugiCzlonNazwiska');

    String finalName;
    if (nazwisko != null && nazwisko.isNotEmpty) {
      finalName = '${imie ?? ''} $nazwisko'.trim();
    } else if (nazwiskoCzlon1 != null && nazwiskoCzlon1.isNotEmpty) {
      finalName = '${imie ?? ''} $nazwiskoCzlon1 ${nazwiskoCzlon2 ?? ''}'
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
    } else {
      finalName = imie ?? 'Brak danych';
    }

    return Subject(gmlId: gmlId, name: finalName, type: 'Osoba fizyczna');
  }

  static Subject? _parseInstytucja(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final nazwa = _getElementText(element, 'nazwaPelna');

    return Subject(
      gmlId: gmlId,
      name: nazwa ?? 'Brak nazwy',
      type: 'Instytucja',
    );
  }

  static RegistrationUnit? _parseRegUnit(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    final idJRG = _getElementText(element, 'idJednostkiRejestrowej');
    if (gmlId == null || idJRG == null) return null;

    return RegistrationUnit(gmlId: gmlId, idJRG: idJRG);
  }

  static OwnershipShare? _parseShare(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final licznik =
        _getElementText(element, 'licznikUlamkaOkreslajacegoWartoscUdzialu') ??
        '1';
    final mianownik =
        _getElementText(
          element,
          'mianownikUlamkaOkreslajacegoWartoscUdzialu',
        ) ??
        '1';

    final jrgHref = _firstElementByLocal(
      element,
      'JRG',
    )?.getAttribute('xlink:href');
    final jrgId = _stripHref(jrgHref);

    final osobaHref =
        _firstElementByLocal(
          element,
          'osobaFizyczna',
        )?.getAttribute('xlink:href') ??
        _firstElementByLocal(
          element,
          'instytucja1',
        )?.getAttribute('xlink:href') ??
        _firstElementByLocal(element, 'instytucja')?.getAttribute('xlink:href');

    final subjectId = _stripHref(osobaHref);

    return OwnershipShare(
      gmlId: gmlId,
      jrgId: jrgId,
      subjectId: subjectId,
      share: '$licznik/$mianownik',
    );
  }

  static BoundaryPoint? _parseBoundaryPoint(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final numer =
        _getElementText(element, 'oznaczenieWMaterialeZrodlowym') ??
        _getElementText(element, 'oznWMaterialeZrodlowym') ??
        _getElementText(element, 'idPunktu');

    // ISD / SPD / STB mogÄ… byÄ‡ zakodowane jako pola opisowe:
    // - ISD: spelnienieWarunkowDokl
    // - STB: rodzajStabilizacji
    // - SPD: sposobPozyskania
    final isd =
        _getElementText(element, 'ISD') ??
        _getElementText(element, 'spelnienieWarunkowDokl');
    final stb =
        _getElementText(element, 'STB') ??
        _getElementText(element, 'rodzajStabilizacji');
    final spd =
        _getElementText(element, 'SPD') ??
        _getElementText(element, 'sposobPozyskania');

    final posElement = element
        .findAllElements('pos', namespace: _gmlNs)
        .firstOrNull;

    String? x, y;
    if (posElement != null) {
      final coords = posElement.innerText.trim().split(RegExp(r'\s+'));
      if (coords.length >= 2) {
        x = coords[0];
        y = coords[1];
      }
    }

    final operat =
        _getElementText(element, 'identyfikatorOperatuWgPZGIK') ??
        _getElementText(element, 'numerOperatuTechnicznego');

    return BoundaryPoint(
      gmlId: gmlId,
      numer: numer,
      x: x,
      y: y,
      isd: isd,
      stb: stb,
      spd: spd,
      operat: operat,
    );
  }

  static List<String> _parseSubjectAddressRefs(XmlElement element) {
    final List<String> result = [];
    final Iterable<XmlElement> adresElements = element.descendants
        .whereType<XmlElement>()
        .where((XmlElement e) {
          final String local = _normalizeLocalName(e.name.local);
          return local == 'adresosobyfizycznej' ||
              local == 'adresstalegopobytu' ||
              local == 'adreszameldowania';
        });

    for (final XmlElement adres in adresElements) {
      final String? href = adres.getAttribute('xlink:href');
      final String? id = _stripHref(href);
      if (id != null && id.isNotEmpty) {
        result.add(id);
      }
    }
    return result;
  }

  static List<String> _parseParcelAddressRefs(XmlElement element) {
    final List<String> result = [];
    final Iterable<XmlElement> adresElements = element.descendants
        .whereType<XmlElement>()
        .where((XmlElement e) {
          final String local = _normalizeLocalName(e.name.local);
          return local == 'adresdzialki';
        });

    for (final XmlElement adres in adresElements) {
      final String? href = adres.getAttribute('xlink:href');
      final String? id = _stripHref(href);
      if (id != null && id.isNotEmpty) {
        result.add(id);
      }
    }
    return result;
  }

  static Map<String, dynamic>? _parseAdresStalegoPobytu(XmlElement element) {
    final String? gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final String? kraj = _getElementText(element, 'kraj');
    final String? miejscowosc =
        _getElementText(element, 'miejscowosc') ??
        _getElementText(element, 'nazwaMiejscowosci');
    final String? kodPocztowy = _getElementText(element, 'kodPocztowy');
    final String? ulica =
        _getElementText(element, 'ulica') ??
        _getElementText(element, 'nazwaUlicy');
    final String? numerPorzadkowy = _getElementText(element, 'numerPorzadkowy');

    return <String, dynamic>{
      'gmlId': gmlId,
      'kraj': kraj,
      'miejscowosc': miejscowosc,
      'kodPocztowy': kodPocztowy,
      'ulica': ulica,
      'numerPorzadkowy': numerPorzadkowy,
    };
  }

  static Map<String, dynamic>? _parseAdresNieruchomosci(XmlElement element) {
    final String? gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final String? kraj = _getElementText(element, 'kraj');
    final String? miejscowosc =
        _getElementText(element, 'nazwaMiejscowosci') ??
        _getElementText(element, 'miejscowosc');
    final String? kodPocztowy = _getElementText(element, 'kodPocztowy');
    final String? ulica =
        _getElementText(element, 'nazwaUlicy') ??
        _getElementText(element, 'ulica');
    final String? numerPorzadkowy = _getElementText(element, 'numerPorzadkowy');

    return <String, dynamic>{
      'gmlId': gmlId,
      'kraj': kraj,
      'miejscowosc': miejscowosc,
      'kodPocztowy': kodPocztowy,
      'ulica': ulica,
      'numerPorzadkowy': numerPorzadkowy,
    };
  }

  static String? _getElementText(XmlElement parent, String localName) {
    final element = _firstElementByLocal(parent, localName);
    final text = element?.innerText.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static String? _stripHref(String? href) {
    if (href == null) return null;
    return href.startsWith('#') ? href.substring(1) : href;
  }
}

String _normalizeLocalName(String name) {
  String result = name.toLowerCase();
  const Map<String, String> replacements = <String, String>{
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ź': 'z',
    'ż': 'z',
  };
  replacements.forEach((String from, String to) {
    result = result.replaceAll(from, to);
  });
  return result;
}
