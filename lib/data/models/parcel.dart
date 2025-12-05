import 'land_use.dart';
import 'building.dart';
import 'premises.dart';
import 'legal_basis.dart';

class ParsedPoint {
  final double x;
  final double y;
  ParsedPoint(this.x, this.y);
}

class Parcel {
  final String gmlId;
  final String idDzialki;
  final String numerDzialki;
  final String? numerKW;
  final double? pole;
  // Pole powierzchni obliczonej z geometrii (jeśli dostępna).
  final double? poleGeometryczne;
  // Rodzaj działki wg EGB_RodzajDzialki: kod i etykieta.
  final String? rodzajDzialkiCode;
  final String? rodzajDzialkiLabel;
  final List<LandUse> uzytki;
  // Kontury klasoużytków wyciągnięte spoza działki (jeśli dostępne).
  final List<LandUse> klasyfikacyjne;
  // Dodatkowe identyfikatory jednostek / obrębów.
  final String? jrgId;
  final List<String> jrgRefs;
  final List<String> pointRefs;
  
  final String? jednostkaId;
  final String? jednostkaNazwa;
  final String? obrebId;
  final String? obrebNazwa;

  final List<ParsedPoint> geometryPoints;
  final List<LandUse> landUseContours;
  final List<LandUse> classificationContours;
  final List<Building> buildings;
  final List<Premises> premises;
  final List<LegalBasis> legalBases;
  // Nieznane lub niezaimplementowane atrybuty GML w formie klucz->wartość.
  final Map<String, String> extraAttributes;

  Parcel({
    required this.gmlId,
    required this.idDzialki,
    required this.numerDzialki,
    this.numerKW,
    this.pole,
    this.poleGeometryczne,
    this.rodzajDzialkiCode,
    this.rodzajDzialkiLabel,
    this.uzytki = const [],
    this.klasyfikacyjne = const [],
    this.jrgId,
    this.jrgRefs = const [],
    this.pointRefs = const [],
    this.jednostkaId,
    this.jednostkaNazwa,
    this.obrebId,
    this.obrebNazwa,
    this.geometryPoints = const [],
    this.landUseContours = const [],
    this.classificationContours = const [],
    this.buildings = const [],
    this.premises = const [],
    this.legalBases = const [],
    this.extraAttributes = const {},
  });

  String get pelnyNumerDzialki => idDzialki;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Parcel &&
          runtimeType == other.runtimeType &&
          gmlId == other.gmlId;

  @override
  int get hashCode => gmlId.hashCode;
}
