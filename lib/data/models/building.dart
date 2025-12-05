class Building {
  final String gmlId;
  final String? buildingId;
  final String? number;
  final String? functionCode;
  final String? functionLabel;
  final int? floors;
  final double? usableArea;
  final double? builtUpArea;
  final List<String> parcelRefs;
  final Map<String, String> extraAttributes;

  const Building({
    required this.gmlId,
    this.buildingId,
    this.number,
    this.functionCode,
    this.functionLabel,
    this.floors,
    this.usableArea,
    this.builtUpArea,
    this.parcelRefs = const [],
    this.extraAttributes = const {},
  });
}
