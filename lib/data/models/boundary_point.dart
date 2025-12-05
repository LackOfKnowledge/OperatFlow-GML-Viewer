class BoundaryPoint {
  final String gmlId;
  final String pelneId;
  final String? numer;
  final String? x;
  final String? y;
  // SPD (sposób pozyskania punktu) kod + etykieta
  final String? spdCode;
  final String? spdLabel;
  // ISD/ISD (spełnienie warunków dokładności) kod + etykieta
  final String? isdCode;
  final String? isdLabel;
  // STB (rodzaj stabilizacji) kod + etykieta
  final String? stbCode;
  final String? stbLabel;
  final String? operat;
  final Map<String, String> extraAttributes;

  BoundaryPoint({
    required this.gmlId,
    required this.pelneId,
    this.numer,
    this.x,
    this.y,
    this.spdCode,
    this.spdLabel,
    this.isdCode,
    this.isdLabel,
    this.stbCode,
    this.stbLabel,
    this.operat,
    this.extraAttributes = const {},
  });

  String get displayNumer => numer ?? '-';
  String get displayFullId => pelneId;
  // Zachowanie kompatybilności z wcześniejszymi polami.
  String? get spd => spdLabel ?? spdCode;
  String? get isd => isdLabel ?? isdCode;
  String? get stb => stbLabel ?? stbCode;
}
