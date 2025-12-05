class OwnershipShare {
  final String gmlId;
  final String? jrgId;
  final String? subjectId;
  final String share;
  final int? numerator;
  final int? denominator;
  final bool? isJoint;
  final String? rightTypeCode;
  final String? rightTypeLabel;
  final Map<String, String> extraAttributes;

  OwnershipShare({
    required this.gmlId,
    this.jrgId,
    this.subjectId,
    required this.share,
    this.numerator,
    this.denominator,
    this.isJoint,
    this.rightTypeCode,
    this.rightTypeLabel,
    this.extraAttributes = const {},
  });
}
