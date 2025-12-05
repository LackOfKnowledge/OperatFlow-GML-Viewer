class LegalBasis {
  final String gmlId;
  final String type; // dokument / operat / zmiana
  final String? number;
  final String? date;
  final String? documentTypeCode;
  final String? documentTypeLabel;
  final String? description;
  final List<String> parcelRefs;
  final Map<String, String> extraAttributes;

  const LegalBasis({
    required this.gmlId,
    required this.type,
    this.number,
    this.date,
    this.documentTypeCode,
    this.documentTypeLabel,
    this.description,
    this.parcelRefs = const [],
    this.extraAttributes = const {},
  });
}
