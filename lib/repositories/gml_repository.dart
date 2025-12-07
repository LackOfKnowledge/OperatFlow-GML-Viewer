import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../data/models/address.dart';
import '../data/models/boundary_point.dart';
import '../data/models/building.dart';
import '../data/models/legal_basis.dart';
import '../data/models/land_use.dart';
import '../data/models/ownership_share.dart';
import '../data/models/parcel.dart';
import '../data/models/premises.dart';
import '../data/models/registration_unit.dart';
import '../data/models/subject.dart';
import '../data/parsers/address_parser.dart';
import '../data/parsers/base_parser.dart';
import '../data/parsers/building_parser.dart';
import '../data/parsers/geometry_parser.dart';
import '../data/parsers/land_use_parser.dart';
import '../data/parsers/legal_basis_parser.dart';
import '../data/parsers/parcel_parser.dart';
import '../data/parsers/premises_parser.dart';
import '../data/parsers/registration_unit_parser.dart';
import '../data/parsers/share_parser.dart';
import '../data/parsers/subject_parser.dart';
import '../data/parsers/teryt_parser.dart';
import '../utils/xml_utils.dart';

class GmlRepository {
  GmlRepository({List<GmlFeatureParser>? parsers})
      : _parsers = parsers ?? _buildDefaultParsers(),
        _customParsers = parsers != null;

  final List<GmlFeatureParser> _parsers;
  final bool _customParsers;

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

  Future<void> parseGml(Uint8List fileBytes) async {
    _reset();

    final Map<String, dynamic> parsedData = _customParsers
        ? GmlDocumentParser(_parsers).parse(fileBytes)
        : await compute(_parseGmlInIsolate, fileBytes);

    _applyParsedData(parsedData);
  }

  void _reset() {
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
  }

  void clear() => _reset();

  void _applyParsedData(Map<String, dynamic> parsedData) {
    if (parsedData.isEmpty) return;

    final obrebyData = parsedData['obreby'] as Map? ?? {};
    final jednostkiEwidData = parsedData['jednostkiEwid'] as Map? ?? {};
    final parcelObrebRefsData = parsedData['parcelObrebRefs'] as Map? ?? {};
    final addressesData = parsedData['addresses'] as Map? ?? {};

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

    final parcelsData = parsedData['parcels'] as List? ?? [];
    for (final p in parcelsData) {
      final map = p as Map;

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

      final List<ParsedPoint> geomPoints = [];
      if (map['geometry'] != null) {
        for (var pointMap in (map['geometry'] as List)) {
          geomPoints.add(ParsedPoint(pointMap['x'], pointMap['y']));
        }
      }

      String? obrebId, obrebNazwa, jednostkaId, jednostkaNazwa;
      final String parcelGmlId = map['gmlId'];
      final String? obrebRefId = parcelObrebRefsData[parcelGmlId];

      if (obrebRefId != null) {
        final obrebInfo = obrebyData[obrebRefId] as Map?;
        if (obrebInfo != null) {
          obrebId = obrebInfo['idObrebu'];
          obrebNazwa = obrebInfo['nazwa'];

          final jednostkaHref = obrebInfo['jednostkaHref'];
          final jednostkaGmlId = stripHref(jednostkaHref);
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

    parcels.sort((a, b) => a.pelnyNumerDzialki.compareTo(b.pelnyNumerDzialki));

    subjectAddresses.clear();
    final subAddrRefs = parsedData['subjectAddressRefs'] as Map? ?? {};
    subAddrRefs.forEach((subId, addrList) {
      final ids = (addrList as List).cast<String>();
      subjectAddresses[subId.toString()] = ids
          .map((id) => addressesById[id])
          .whereType<Address>()
          .toList();
    });

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
}

class GmlDocumentParser {
  GmlDocumentParser(List<GmlFeatureParser> parsers)
      : _parsers = {for (final p in parsers) p.featureName: p};

  final Map<String, GmlFeatureParser> _parsers;

  Map<String, dynamic> parse(Uint8List fileBytes) {
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
      final featureMembers = document.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'featureMember');

      for (final member in featureMembers) {
        final element = member.children.whereType<XmlElement>().firstOrNull;
        if (element == null) continue;

        final parser = _parsers[element.name.local];
        if (parser == null) continue;

        try {
          final result = parser.parse(element);
          if (result == null) continue;

          final tagName = element.name.local;
          if (result is ParcelParseResult) {
            final parcelMap = result.parcel;
            parsedParcels.add(parcelMap);
            if (result.addressRefs.isNotEmpty) {
              parsedParcelAddressRefs[parcelMap['gmlId']] = result.addressRefs;
            }
            if (result.obrebRefId != null && result.obrebRefId!.isNotEmpty) {
              parcelObrebRefs[parcelMap['gmlId']] = result.obrebRefId!;
            }
          } else if (result is SubjectParseResult) {
            parsedSubjects[result.subject['gmlId']] = result.subject;
            if (result.addressRefs.isNotEmpty) {
              parsedSubjectAddressRefs[result.subject['gmlId']] =
                  result.addressRefs;
            }
          } else if (result is Map<String, dynamic>) {
            switch (tagName) {
              case 'EGB_JednostkaRejestrowaGruntow':
                parsedRegUnits[result['gmlId']] = result;
                break;
              case 'EGB_ObrebEwidencyjny':
                parsedObreby[result['gmlId']] = result;
                break;
              case 'EGB_JednostkaEwidencyjna':
                parsedJednostkiEwid[result['gmlId']] = result;
                break;
              case 'EGB_UdzialWeWlasnosci':
                if (result['jrgId'] != null) {
                  final jrgId = result['jrgId'] as String;
                  parsedShares.putIfAbsent(jrgId, () => []).add(result);
                }
                break;
              case 'EGB_AdresStalegoPobytu':
              case 'EGB_AdresZameldowania':
              case 'EGB_AdresNieruchomosci':
                parsedAddresses[result['gmlId']] = result;
                break;
              case 'EGB_Budynek':
                parsedBuildings[result['gmlId']] = result;
                break;
              case 'EGB_Lokal':
                parsedPremises[result['gmlId']] = result;
                break;
              case 'EGB_OperatTechniczny':
              case 'EGB_Dokument':
              case 'EGB_Zmiana':
                parsedLegalBases[result['gmlId']] = result;
                break;
              case 'EGB_KonturUzytkuGruntowego':
                for (final ref in (result['parcelRefs'] as List<String>)) {
                  parsedLandUseContours.putIfAbsent(ref, () => []).add(result['gmlId']);
                }
                parsedContours[result['gmlId']] = result;
                break;
              case 'EGB_KonturKlasyfikacyjny':
                for (final ref in (result['parcelRefs'] as List<String>)) {
                  parsedClassContours.putIfAbsent(ref, () => []).add(result['gmlId']);
                }
                parsedContours[result['gmlId']] = result;
                break;
              case 'EGB_PunktGraniczny':
                parsedPoints[result['gmlId']] = result;
                break;
            }
          }
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('Blad podczas parsowania ${element.name.local}: $e');
            debugPrint('$st');
          }
          // continue parsing remaining featureMembers
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Blad parsowania XML: $e');
      throw Exception('Blad parsowania XML: $e');
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
}

Map<String, dynamic> _parseGmlInIsolate(Uint8List fileBytes) {
  final parser = GmlDocumentParser(_buildDefaultParsers());
  return parser.parse(fileBytes);
}

List<GmlFeatureParser> _buildDefaultParsers() => [
      ParcelParser(),
      BoundaryPointParser(),
      PhysicalPersonParser(),
      InstitutionParser(),
      RegistrationUnitParser(),
      ObrebParser(),
      JednostkaEwidParser(),
      ShareParser(),
      AddressParser('EGB_AdresStalegoPobytu'),
      AddressParser('EGB_AdresZameldowania'),
      AddressParser('EGB_AdresNieruchomosci'),
      BuildingParser(),
      PremisesParser(),
      LegalBasisParser('EGB_OperatTechniczny'),
      LegalBasisParser('EGB_Dokument'),
      LegalBasisParser('EGB_Zmiana'),
      LandUseContourParser(),
      ClassificationContourParser(),
    ];

Map<String, String> _castStringMap(Map? source) {
  if (source == null) return {};
  return source.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  );
}
