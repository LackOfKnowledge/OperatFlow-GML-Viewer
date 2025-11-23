import 'land_use.dart';

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
  final List<LandUse> uzytki;
  final String? jrgId;
  final List<String> pointRefs;
  
  final String? jednostkaId;
  final String? jednostkaNazwa;
  final String? obrebId;
  final String? obrebNazwa;

  final List<ParsedPoint> geometryPoints;

  Parcel({
    required this.gmlId,
    required this.idDzialki,
    required this.numerDzialki,
    this.numerKW,
    this.pole,
    this.uzytki = const [],
    this.jrgId,
    this.pointRefs = const [],
    this.jednostkaId,
    this.jednostkaNazwa,
    this.obrebId,
    this.obrebNazwa,
    this.geometryPoints = const [],
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