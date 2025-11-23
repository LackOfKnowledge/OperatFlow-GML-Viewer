class BoundaryPoint {
  final String gmlId;
  final String pelneId;
  final String? numer;
  final String? x;
  final String? y;
  final String? isd;
  final String? stb;
  final String? spd;
  final String? operat;

  BoundaryPoint({
    required this.gmlId,
    required this.pelneId,
    this.numer,
    this.x,
    this.y,
    this.isd,
    this.stb,
    this.spd,
    this.operat,
  });

  String get displayNumer => numer ?? '-';
  String get displayFullId => pelneId;
}