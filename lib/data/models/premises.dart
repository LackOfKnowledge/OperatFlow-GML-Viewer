class Premises {
  final String gmlId;
  final String? premisesId;
  final String? number;
  final String? typeCode;
  final String? typeLabel;
  final String? floor;
  final double? usableArea;
  final List<String> parcelRefs;
  final String? buildingRef;
  final Map<String, String> extraAttributes;

  const Premises({
    required this.gmlId,
    this.premisesId,
    this.number,
    this.typeCode,
    this.typeLabel,
    this.floor,
    this.usableArea,
    this.parcelRefs = const [],
    this.buildingRef,
    this.extraAttributes = const {},
  });
}
