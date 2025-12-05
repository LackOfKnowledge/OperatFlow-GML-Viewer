class RegistrationUnit {
  final String gmlId;
  final String idJRG;
  final String? rodzajJRGCode;
  final String? rodzajJRGLabel;
  final List<String> parcelRefs;
  final List<String> buildingRefs;
  final List<String> premisesRefs;
  final Map<String, String> extraAttributes;

  RegistrationUnit({
    required this.gmlId,
    required this.idJRG,
    this.rodzajJRGCode,
    this.rodzajJRGLabel,
    this.parcelRefs = const [],
    this.buildingRefs = const [],
    this.premisesRefs = const [],
    this.extraAttributes = const {},
  });
}
