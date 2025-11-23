class OwnershipShare {
  final String gmlId;
  final String? jrgId;
  final String? subjectId;
  final String share;

  OwnershipShare({
    required this.gmlId,
    this.jrgId,
    this.subjectId,
    required this.share,
  });
}