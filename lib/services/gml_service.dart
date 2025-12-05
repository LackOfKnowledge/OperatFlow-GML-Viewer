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
import '../data/models/building.dart';
import '../data/models/premises.dart';
import '../data/models/legal_basis.dart';

class GmlService {
  final List<Parcel> parcels = [];
  final Map<String, Subject> subjects = {};
  final Map<String, RegistrationUnit> registrationUnits = {};
  final Map<String, List<OwnershipShare>> sharesByJrgId = {};
  final Map<String, BoundaryPoint> boundaryPoints = {};
  final Map<String, List<Address>> subjectAddresses = {};
  final Map<String, List<Address>> parcelAddresses = {};
  final Map<String, Building> buildings = {};
  final Map<String, Premises> premises = {};
  final Map<String, LegalBasis> legalBases = {};
  final Map<String, List<String>> landUseContoursByParcel = {};
  final Map<String, List<String>> classContoursByParcel = {};
  final Map<String, List<String>> buildingsByParcel = {};
  final Map<String, List<String>> premisesByParcel = {};
  final Map<String, List<String>> legalBasesByParcel = {};

  static const String _gmlNs = 'http://www.opengis.net/gml/3.2';
  static const Map<String, String> _spdEnum = {
    '1': 'ustalony (1)',
    '2': 'nieustalony (2)',
    'TRK': 'TRK',
    'PZG': 'PZG',
  };
  static const Map<String, String> _isdEnum = {
    '1': 'spełnia (1)',
    '2': 'nie spełnia (2)',
    'PZG': 'PZG',
  };
  static const Map<String, String> _stbEnum = {
    '1': 'brak informacji (1)',
    '2': 'niestabilizowany (2)',
    '3': 'znak naziemny (3)',
    '4': 'znak naziemny i podziemny (4)',
    '5': 'znak podziemny (5)',
    '6': 'szczegół terenowy (6)',
    'ZRD': 'ZRD',
  };

  Future<void> parseGml(Uint8List fileBytes) async {
    parcels.clear();
    subjects.clear();
    registrationUnits.clear();
    sharesByJrgId.clear();
    boundaryPoints.clear();
    subjectAddresses.clear();
    parcelAddresses.clear();
    buildings.clear();
    premises.clear();
    legalBases.clear();
    landUseContoursByParcel.clear();
    classContoursByParcel.clear();
    buildingsByParcel.clear();
    premisesByParcel.clear();
    legalBasesByParcel.clear();

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
    final Map<String, Map<String, dynamic>> parsedBuildings = {};
    final Map<String, Map<String, dynamic>> parsedPremises = {};
    final Map<String, Map<String, dynamic>> parsedLegalBases = {};
    final Map<String, List<String>> parsedLandUseContours = {};
    final Map<String, List<String>> parsedClassContours = {};
    final Map<String, Map<String, dynamic>> parsedContours = {};

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

          case 'EGB_Budynek':
            final bud = _parseBuilding(element);
            if (bud != null) {
              parsedBuildings[bud['gmlId']] = bud;
            }
            break;

          case 'EGB_Lokal':
            final lok = _parsePremises(element);
            if (lok != null) {
              parsedPremises[lok['gmlId']] = lok;
            }
            break;

          case 'EGB_OperatTechniczny':
          case 'EGB_Dokument':
          case 'EGB_Zmiana':
            final legal = _parseLegalBasis(element, tagName);
            if (legal != null) {
              parsedLegalBases[legal['gmlId']] = legal;
            }
            break;

          case 'EGB_KonturUzytkuGruntowego':
            final kontur = _parseLandUseContour(element);
            if (kontur != null) {
              for (final ref in (kontur['parcelRefs'] as List<String>)) {
                parsedLandUseContours.putIfAbsent(ref, () => []).add(kontur['gmlId']);
              }
              parsedContours[kontur['gmlId']] = kontur;
            }
            break;

          case 'EGB_KonturKlasyfikacyjny':
            final konturK = _parseClassContour(element);
            if (konturK != null) {
              for (final ref in (konturK['parcelRefs'] as List<String>)) {
                parsedClassContours.putIfAbsent(ref, () => []).add(konturK['gmlId']);
              }
              parsedContours[konturK['gmlId']] = konturK;
            }
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
      'buildings': parsedBuildings,
      'premises': parsedPremises,
      'legalBases': parsedLegalBases,
      'landUseContours': parsedLandUseContours,
      'classContours': parsedClassContours,
      'contoursStore': parsedContours,
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
        rodzajAdresuCode: map['rodzajAdresuCode'],
        rodzajAdresuLabel: map['rodzajAdresuLabel'],
        wojewodztwoTeryt: map['wojewodztwoTeryt'],
        powiatTeryt: map['powiatTeryt'],
        gminaTeryt: map['gminaTeryt'],
        miejscowoscTeryt: map['miejscowoscTeryt'],
        ulicaTeryt: map['ulicaTeryt'],
        extraAttributes: _castStringMap(map['extraAttributes'] as Map?),
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
        spdCode: map['spdCode'],
        spdLabel: map['spdLabel'],
        isdCode: map['isdCode'],
        isdLabel: map['isdLabel'],
        stbCode: map['stbCode'],
        stbLabel: map['stbLabel'],
        operat: map['operat'],
        extraAttributes: _castStringMap(map['extraAttributes'] as Map?),
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
        identifiers: _castStringMap(map['identifiers'] as Map?),
        extraAttributes: _castStringMap(map['extraAttributes'] as Map?),
      );
    });

    // Odtwarzanie JRG
    final regUnitsData = parsedData['regUnits'] as Map? ?? {};
    regUnitsData.forEach((key, value) {
      final map = value as Map;
      registrationUnits[key.toString()] = RegistrationUnit(
        gmlId: map['gmlId'],
        idJRG: map['idJRG'],
        rodzajJRGCode: map['rodzajJRGCode'],
        rodzajJRGLabel: map['rodzajJRGLabel'],
        parcelRefs: (map['parcelRefs'] as List?)?.cast<String>() ?? const [],
        buildingRefs: (map['buildingRefs'] as List?)?.cast<String>() ?? const [],
        premisesRefs: (map['premisesRefs'] as List?)?.cast<String>() ?? const [],
        extraAttributes: _castStringMap(map['extraAttributes'] as Map?),
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
          numerator: map['numerator'],
          denominator: map['denominator'],
          isJoint: map['isJoint'],
          rightTypeCode: map['rightTypeCode'],
          rightTypeLabel: map['rightTypeLabel'],
          extraAttributes: _castStringMap(map['extraAttributes'] as Map?),
        );
      }).toList();
    });

    // Odtwarzanie Konturów i mapowanie do działek
    final contourStore = parsedData['contoursStore'] as Map? ?? {};
    final landUseRefsData = parsedData['landUseContours'] as Map? ?? {};
    final classRefsData = parsedData['classContours'] as Map? ?? {};
    final Map<String, LandUse> contourById = {};
    contourStore.forEach((key, value) {
      final map = value as Map;
      final extras = _castStringMap(map['extraAttributes'] as Map?);
      if (map['geometry'] != null) {
        extras['geometry'] = jsonEncode(map['geometry']);
      }
      contourById[key.toString()] = LandUse(
        ofu: map['ofu'] ?? '',
        ozu: map['ozu'] ?? '',
        ozk: map['ozk'],
        powierzchnia: map['powierzchnia'],
        extraAttributes: extras,
      );
    });
    landUseContoursByParcel.clear();
    landUseRefsData.forEach((parcelId, list) {
      landUseContoursByParcel[parcelId.toString()] =
          (list as List).cast<String>();
    });
    classContoursByParcel.clear();
    classRefsData.forEach((parcelId, list) {
      classContoursByParcel[parcelId.toString()] =
          (list as List).cast<String>();
    });

    // Odtwarzanie budynków
    final buildingsData = parsedData['buildings'] as Map? ?? {};
    buildings.clear();
    buildingsByParcel.clear();
    buildingsData.forEach((key, value) {
      final map = value as Map;
      final refs = (map['parcelRefs'] as List?)?.cast<String>() ?? const [];
      final b = Building(
        gmlId: map['gmlId'],
        buildingId: map['buildingId'],
        number: map['number'],
        functionCode: map['functionCode'],
        floors: map['floors'],
        usableArea: map['usableArea'],
        builtUpArea: map['builtUpArea'],
        parcelRefs: refs,
        extraAttributes: _castStringMap(map['extraAttributes'] as Map?),
      );
      buildings[key.toString()] = b;
      for (final ref in refs) {
        buildingsByParcel.putIfAbsent(ref, () => []).add(key.toString());
      }
    });

    // Odtwarzanie lokali
    final premisesData = parsedData['premises'] as Map? ?? {};
    premises.clear();
    premisesByParcel.clear();
    premisesData.forEach((key, value) {
      final map = value as Map;
      final refs = (map['parcelRefs'] as List?)?.cast<String>() ?? const [];
      final l = Premises(
        gmlId: map['gmlId'],
        premisesId: map['premisesId'],
        number: map['number'],
        typeCode: map['typeCode'],
        floor: map['floor'],
        usableArea: map['usableArea'],
        parcelRefs: refs,
        buildingRef: map['buildingRef'],
        extraAttributes: _castStringMap(map['extraAttributes'] as Map?),
      );
      premises[key.toString()] = l;
      for (final ref in refs) {
        premisesByParcel.putIfAbsent(ref, () => []).add(key.toString());
      }
    });

    // Odtwarzanie podstaw prawnych
    final legalData = parsedData['legalBases'] as Map? ?? {};
    legalBases.clear();
    legalBasesByParcel.clear();
    legalData.forEach((key, value) {
      final map = value as Map;
      final refs = (map['parcelRefs'] as List?)?.cast<String>() ?? const [];
      final l = LegalBasis(
        gmlId: map['gmlId'],
        type: map['type'],
        number: map['number'],
        date: map['date'],
        documentTypeCode: map['documentTypeCode'],
        documentTypeLabel: map['documentTypeLabel'],
        description: map['description'],
        parcelRefs: refs,
        extraAttributes: _castStringMap(map['extraAttributes'] as Map?),
      );
      legalBases[key.toString()] = l;
      for (final ref in refs) {
        legalBasesByParcel.putIfAbsent(ref, () => []).add(key.toString());
      }
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
          ofuLabel: uMap['ofuLabel'],
          ozu: uMap['ozu'],
          ozuLabel: uMap['ozuLabel'],
          ozk: uMap['ozk'],
          powierzchnia: uMap['powierzchnia'],
          extraAttributes: _castStringMap(uMap['extra'] as Map?),
        );
      }).toList();
      final klasyfikacyjne = (map['klasyfikacyjne'] as List)
          .map((u) => u as Map)
          .map((uMap) => LandUse(
                ofu: uMap['ofu'] ?? '',
                ofuLabel: uMap['ofuLabel'],
                ozu: uMap['ozu'] ?? '',
                ozuLabel: uMap['ozuLabel'],
                ozk: uMap['ozk'],
                ozkLabel: uMap['ozkLabel'],
                powierzchnia: uMap['powierzchnia'],
                extraAttributes: _castStringMap(uMap['extra'] as Map?),
              ))
          .toList();

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

      final landUseContoursList = (landUseContoursByParcel[parcelGmlId] ?? [])
          .map((id) => contourById[id])
          .whereType<LandUse>()
          .toList();
      final classContoursList = (classContoursByParcel[parcelGmlId] ?? [])
          .map((id) => contourById[id])
          .whereType<LandUse>()
          .toList();
      final buildingList = (buildingsByParcel[parcelGmlId] ?? [])
          .map((id) => buildings[id])
          .whereType<Building>()
          .toList();
      final premisesList = (premisesByParcel[parcelGmlId] ?? [])
          .map((id) => premises[id])
          .whereType<Premises>()
          .toList();
      final legalList = (legalBasesByParcel[parcelGmlId] ?? [])
          .map((id) => legalBases[id])
          .whereType<LegalBasis>()
          .toList();

      parcels.add(Parcel(
        gmlId: parcelGmlId,
        idDzialki: map['idDzialki'],
        numerDzialki: map['numerDzialki'],
        numerKW: map['numerKW'],
        pole: map['pole'],
        poleGeometryczne: map['poleGeometryczne'],
        rodzajDzialkiCode: map['rodzajDzialkiCode'],
        rodzajDzialkiLabel: map['rodzajDzialkiLabel'],
        uzytki: uzytki,
        klasyfikacyjne: klasyfikacyjne,
        jrgId: map['jrgId'],
        jrgRefs: (map['jrgRefs'] as List?)?.cast<String>() ?? const [],
        pointRefs: (map['pointRefs'] as List).cast<String>(),
        geometryPoints: geomPoints,
        obrebId: obrebId,
        obrebNazwa: obrebNazwa,
        jednostkaId: jednostkaId,
        jednostkaNazwa: jednostkaNazwa,
        landUseContours: landUseContoursList,
        classificationContours: classContoursList,
        buildings: buildingList,
        premises: premisesList,
        legalBases: legalList,
        extraAttributes: _castStringMap(map['extraAttributes'] as Map?),
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

  List<Building> getBuildingsForParcel(Parcel parcel) {
    return parcel.buildings.isNotEmpty
        ? parcel.buildings
        : (buildingsByParcel[parcel.gmlId] ?? [])
            .map((id) => buildings[id])
            .whereType<Building>()
            .toList();
  }

  List<Premises> getPremisesForParcel(Parcel parcel) {
    return parcel.premises.isNotEmpty
        ? parcel.premises
        : (premisesByParcel[parcel.gmlId] ?? [])
            .map((id) => premises[id])
            .whereType<Premises>()
            .toList();
  }

  List<LegalBasis> getLegalBasesForParcel(Parcel parcel) {
    return parcel.legalBases.isNotEmpty
        ? parcel.legalBases
        : (legalBasesByParcel[parcel.gmlId] ?? [])
            .map((id) => legalBases[id])
            .whereType<LegalBasis>()
            .toList();
  }

  List<LandUse> getLandUseContours(Parcel parcel) {
    return parcel.landUseContours;
  }

  List<LandUse> getClassificationContours(Parcel parcel) {
    return parcel.classificationContours;
  }
  
  List<Address> getAddressesForSubject(Subject subject) {
    return subjectAddresses[subject.gmlId] ?? [];
  }

  List<MapEntry<OwnershipShare, Subject?>> getSubjectsForParcels(
      List<Parcel> parcels) {
    final Set<String> jrgIds =
        parcels.map((p) => p.jrgId).whereType<String>().toSet();
    final List<OwnershipShare> allShares =
        jrgIds.map((id) => sharesByJrgId[id] ?? []).expand((list) => list).toList();

    final Map<String, MapEntry<OwnershipShare, Subject?>> uniqueSubjects = {};
    for (var share in allShares) {
      final subject =
          share.subjectId != null ? subjects[share.subjectId!] : null;
      if (subject != null && !uniqueSubjects.containsKey(subject.gmlId)) {
        uniqueSubjects[subject.gmlId] = MapEntry(share, subject);
      }
    }
    return uniqueSubjects.values.toList();
  }

  List<Parcel> getParcelsForSubject(Subject subject) {
    List<Parcel> subjectParcels = [];
    final List<String> jrgIds = [];
    sharesByJrgId.forEach((jrgId, shares) {
      if (shares.any((share) => share.subjectId == subject.gmlId)) {
        jrgIds.add(jrgId);
      }
    });

    for (var parcel in parcels) {
      if (parcel.jrgId != null && jrgIds.contains(parcel.jrgId)) {
        subjectParcels.add(parcel);
      }
    }
    return subjectParcels;
  }



  static Map<String, dynamic>? _parseParcel(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    final idDzialki = _getElementText(element, 'idDzialki');
    if (gmlId == null || idDzialki == null) return null;

    final numerKW = _getElementText(element, 'numerKW');
    final poleStr = _getElementText(element, 'poleEwidencyjne');
    final poleGeomStr = _getElementText(element, 'powierzchniaZGeometrii') ??
        _getElementText(element, 'polePowierzchni');
    final rodzajDzialkiCode = _getElementText(element, 'rodzajDzialki');
    
    final jrgRefs = <String>[];
    final jrgHref = _firstElementByLocal(element, 'JRG2')
            ?.getAttribute('xlink:href') ??
        _firstElementByLocal(element, 'JRG')?.getAttribute('xlink:href');
    if (jrgHref != null) jrgRefs.add(_stripHref(jrgHref) ?? '');
    for (final ref in element
        .findAllElements('JRG', namespace: element.name.namespaceUri)
        .map((e) => _stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()) {
      if (!jrgRefs.contains(ref)) jrgRefs.add(ref);
    }
    
    final uzytki = <Map<String, dynamic>>[];
    for (final u in element.descendants.whereType<XmlElement>().where((e) => e.name.local == 'EGB_Klasouzytek')) {
      final extras = <String, String>{};
      _collectUnknownAttributes(u, extras, knownLocals: {'OFU', 'OZU', 'OZK', 'powierzchnia'});
      uzytki.add({
        'ofu': _getElementText(u, 'OFU') ?? '?',
        'ofuLabel': _getElementText(u, 'OFUOpis'),
        'ozu': _getElementText(u, 'OZU') ?? '?',
        'ozuLabel': _getElementText(u, 'OZUOpis'),
        'ozk': _getElementText(u, 'OZK'),
        'ozkLabel': _getElementText(u, 'OZKOpis'),
        'powierzchnia': double.tryParse(_getElementText(u, 'powierzchnia') ?? ''),
        'extra': extras,
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
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
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
      'rodzajDzialkiLabel': rodzajDzialkiCode, // brak tabeli odwzorowań
      'uzytki': uzytki,
      'klasyfikacyjne': <Map<String, dynamic>>[],
      'jrgId': _stripHref(jrgHref),
      'jrgRefs': jrgRefs.where((e) => e.isNotEmpty).toList(),
      'pointRefs': pointIds,
      'extraAttributes': extras,
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

    final spdRaw =
        _getElementText(element, 'sposobPozyskania') ?? _getElementText(element, 'SPD');
    final isdRaw = _getElementText(element, 'spelnienieWarunkowDokl') ??
        _getElementText(element, 'ISD');
    final stbRaw =
        _getElementText(element, 'rodzajStabilizacji') ?? _getElementText(element, 'STB');
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
      knownLocals: {
        'idPunktu',
        'oznaczenieWMaterialeZrodlowym',
        'oznWMaterialeZrodlowym',
        'SPD',
        'ISD',
        'STB',
        'sposobPozyskania',
        'spelnienieWarunkowDokl',
        'rodzajStabilizacji',
        'geometria',
      },
    );

    return {
      'gmlId': gmlId,
      'pelneId': idPunktu ?? gmlId,
      'numer': numer,
      'x': x,
      'y': y,
      'spdCode': spdRaw,
      'spdLabel': _spdEnum[spdRaw ?? ''] ?? _mapSpd(spdRaw),
      'isdCode': isdRaw,
      'isdLabel': _isdEnum[isdRaw ?? ''] ?? _mapIsd(isdRaw),
      'stbCode': stbRaw,
      'stbLabel': _stbEnum[stbRaw ?? ''] ?? _mapStb(stbRaw),
      'operat': _getElementText(element, 'identyfikatorOperatuWgPZGIK') ?? _getElementText(element, 'numerOperatuTechnicznego'),
      'extraAttributes': extras,
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
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
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
    final pesel = _getElementText(element, 'PESEL');
    if (pesel != null) identifiers['PESEL'] = pesel;
    return {
      'gmlId': gmlId,
      'name': name.trim(),
      'type': 'Osoba fizyczna',
      'identifiers': identifiers,
      'extraAttributes': extras,
    };
  }

  static Map<String, dynamic>? _parseInstytucja(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
      knownLocals: {'nazwaPelna', 'REGON', 'NIP'},
    );
    final identifiers = <String, String>{};
    final nip = _getElementText(element, 'NIP');
    final regon = _getElementText(element, 'REGON');
    if (nip != null) identifiers['NIP'] = nip;
    if (regon != null) identifiers['REGON'] = regon;
    return {
      'gmlId': gmlId,
      'name': _getElementText(element, 'nazwaPelna') ?? 'Instytucja',
      'type': 'Instytucja',
      'identifiers': identifiers,
      'extraAttributes': extras,
    };
  }

  static Map<String, dynamic>? _parseShare(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;

    final l = _getElementText(element, 'licznikUlamkaOkreslajacegoWartoscUdzialu') ?? '1';
    final m = _getElementText(element, 'mianownikUlamkaOkreslajacegoWartoscUdzialu') ?? '1';
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
      knownLocals: {
        'licznikUlamkaOkreslajacegoWartoscUdzialu',
        'mianownikUlamkaOkreslajacegoWartoscUdzialu',
        'JRG',
        'osobaFizyczna',
        'instytucja',
        'instytucja1',
      },
    );
    
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
      'numerator': int.tryParse(l),
      'denominator': int.tryParse(m),
      'extraAttributes': extras,
    };
  }

  static Map<String, dynamic>? _parseRegUnit(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    final idJRG = _getElementText(element, 'idJednostkiRejestrowej');
    if (gmlId == null || idJRG == null) return null;
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
      knownLocals: {
        'idJednostkiRejestrowej',
        'rodzajJednostki',
        'dzialkaEwidencyjna',
        'budynek',
        'lokal',
      },
    );
    final parcelRefs = element
        .findElements('dzialkaEwidencyjna')
        .map((e) => _stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    final buildingRefs = element
        .findElements('budynek')
        .map((e) => _stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    final premisesRefs = element
        .findElements('lokal')
        .map((e) => _stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    return {
      'gmlId': gmlId,
      'idJRG': idJRG,
      'rodzajJRGCode': _getElementText(element, 'rodzajJednostki'),
      'parcelRefs': parcelRefs,
      'buildingRefs': buildingRefs,
      'premisesRefs': premisesRefs,
      'extraAttributes': extras,
    };
  }

  static Map<String, dynamic>? _parseAdresStalegoPobytu(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
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
      'kraj': _getElementText(element, 'kraj'),
      'miejscowosc': _getElementText(element, 'miejscowosc') ?? _getElementText(element, 'nazwaMiejscowosci'),
      'kodPocztowy': _getElementText(element, 'kodPocztowy'),
      'ulica': _getElementText(element, 'ulica') ?? _getElementText(element, 'nazwaUlicy'),
      'numerPorzadkowy': _getElementText(element, 'numerPorzadkowy'),
      'wojewodztwoTeryt': _getElementText(element, 'wojewodztwo'),
      'powiatTeryt': _getElementText(element, 'powiat'),
      'gminaTeryt': _getElementText(element, 'gmina'),
      'miejscowoscTeryt': _getElementText(element, 'simc'),
      'ulicaTeryt': _getElementText(element, 'ulic'),
      'extraAttributes': extras,
    };
  }
  
  static Map<String, dynamic>? _parseAdresNieruchomosci(XmlElement element) {
     return _parseAdresStalegoPobytu(element);
  }

  static Map<String, dynamic>? _parseBuilding(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
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
        .findElements('dzialkaEwidencyjna')
        .map((e) => _stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    return {
      'gmlId': gmlId,
      'buildingId': _getElementText(element, 'idBudynku'),
      'number': _getElementText(element, 'numerPorzadkowy'),
      'functionCode': _getElementText(element, 'funkcjaBudynku'),
      'floors': int.tryParse(_getElementText(element, 'liczbaKondygnacjiNadziemnych') ?? ''),
      'usableArea': double.tryParse(_getElementText(element, 'powierzchniaUzytkowa') ?? ''),
      'builtUpArea': double.tryParse(_getElementText(element, 'powierzchniaZabudowy') ?? ''),
      'parcelRefs': parcelRefs,
      'extraAttributes': extras,
    };
  }

  static Map<String, dynamic>? _parsePremises(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
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
        .findElements('dzialkaEwidencyjna')
        .map((e) => _stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    final buildingRef = _stripHref(_firstElementByLocal(element, 'budynek')?.getAttribute('xlink:href'));
    return {
      'gmlId': gmlId,
      'premisesId': _getElementText(element, 'idLokalu'),
      'number': _getElementText(element, 'numerLokalu'),
      'typeCode': _getElementText(element, 'rodzajLokalu'),
      'floor': _getElementText(element, 'kondygnacja'),
      'usableArea': double.tryParse(_getElementText(element, 'powierzchniaUzytkowa') ?? ''),
      'parcelRefs': parcelRefs,
      'buildingRef': buildingRef,
      'extraAttributes': extras,
    };
  }

  static Map<String, dynamic>? _parseLegalBasis(XmlElement element, String tagName) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
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
        .findElements('dzialkaEwidencyjna')
        .map((e) => _stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    final number = _getElementText(element, 'numerOperatuTechnicznego') ??
        _getElementText(element, 'numerDokumentu');
    final date = _getElementText(element, 'dataDokumentu');
    final docType = _getElementText(element, 'rodzajDokumentu');
    final desc = _getElementText(element, 'opis');
    return {
      'gmlId': gmlId,
      'type': tagName,
      'number': number,
      'date': date,
      'documentTypeCode': docType,
      'documentTypeLabel': docType,
      'description': desc,
      'parcelRefs': parcelRefs,
      'extraAttributes': extras,
    };
  }

  static Map<String, dynamic>? _parseLandUseContour(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final geometry = _parsePolygon(element);
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
      knownLocals: {'OFU', 'OZU', 'powierzchnia', 'dzialkaEwidencyjna', 'geometria'},
    );
    final parcelRefs = element
        .findElements('dzialkaEwidencyjna')
        .map((e) => _stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    return {
      'gmlId': gmlId,
      'ofu': _getElementText(element, 'OFU') ?? '',
      'ozu': _getElementText(element, 'OZU') ?? '',
      'powierzchnia': double.tryParse(_getElementText(element, 'powierzchnia') ?? ''),
      'parcelRefs': parcelRefs,
      'geometry': geometry,
      'extraAttributes': extras,
    };
  }

  static Map<String, dynamic>? _parseClassContour(XmlElement element) {
    final gmlId = element.getAttribute('gml:id');
    if (gmlId == null) return null;
    final geometry = _parsePolygon(element);
    final extras = <String, String>{};
    _collectUnknownAttributes(
      element,
      extras,
      knownLocals: {'OZU', 'OZK', 'powierzchnia', 'dzialkaEwidencyjna', 'geometria'},
    );
    final parcelRefs = element
        .findElements('dzialkaEwidencyjna')
        .map((e) => _stripHref(e.getAttribute('xlink:href')))
        .whereType<String>()
        .toList();
    return {
      'gmlId': gmlId,
      'ofu': _getElementText(element, 'OZU') ?? '',
      'ozu': _getElementText(element, 'OZU') ?? '',
      'ozk': _getElementText(element, 'OZK'),
      'powierzchnia': double.tryParse(_getElementText(element, 'powierzchnia') ?? ''),
      'parcelRefs': parcelRefs,
      'geometry': geometry,
      'extraAttributes': extras,
    };
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
  static void _collectUnknownAttributes(
    XmlElement element,
    Map<String, String> target, {
    Set<String> knownLocals = const {},
    String prefix = '',
  }) {
    final currentPath =
        prefix.isEmpty ? element.name.local : '$prefix/${element.name.local}';

    for (final attr in element.attributes) {
      final key = '$currentPath@${attr.name.local}';
      target.putIfAbsent(key, () => attr.value.trim());
    }

    final directText = element.children
        .whereType<XmlText>()
        .map((e) => e.text.trim())
        .where((t) => t.isNotEmpty)
        .join(' ');
    if (directText.isNotEmpty && !knownLocals.contains(element.name.local)) {
      target.putIfAbsent(currentPath, () => directText);
    }

    final Map<String, int> counters = {};
    for (final child in element.children.whereType<XmlElement>()) {
      final idx = counters[child.name.local] ?? 0;
      counters[child.name.local] = idx + 1;
      final nextPrefix = '$currentPath/${child.name.local}[$idx]';
      _collectUnknownAttributes(
        child,
        target,
        knownLocals: knownLocals,
        prefix: nextPrefix,
      );
    }
  }

  static Map<String, String> _castStringMap(Map? source) {
    if (source == null) return {};
    return source.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  static List<Map<String, double>> _parsePolygon(XmlElement element) {
    final List<Map<String, double>> geometry = [];
    final geomElement = _firstElementByLocal(element, 'geometria');
    if (geomElement != null) {
      final posList = geomElement
          .findAllElements('posList', namespace: _gmlNs)
          .firstOrNull;
      if (posList != null) {
        final coords = posList.innerText.trim().split(RegExp(r'\\s+'));
        for (int i = 0; i < coords.length - 1; i += 2) {
          final val1 = double.tryParse(coords[i]);
          final val2 = double.tryParse(coords[i + 1]);
          if (val1 != null && val2 != null) {
            geometry.add({'x': val1, 'y': val2});
          }
        }
      }
    }
    return geometry;
  }

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
        return 'spelnia (1)';
      case '2':
        return 'nie spelnia (2)';
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
        return 'szczegol terenowy (6)';
      default:
        return value;
    }
  }
}
