class Subject {
  final String gmlId;
  final String name;
  final String type;
  final Map<String, String> identifiers;
  final Map<String, String> extraAttributes;

  Subject({
    required this.gmlId,
    required this.name,
    required this.type,
    this.identifiers = const {},
    this.extraAttributes = const {},
  });
}
