class LandUse {
  final String ofu;
  final String ozu;
  final String? ofuLabel;
  final String? ozuLabel;
  final String? ozk;
  final String? ozkLabel;
  final double? powierzchnia;
  final Map<String, String> extraAttributes;

  LandUse({
    required this.ofu,
    required this.ozu,
    this.ofuLabel,
    this.ozuLabel,
    this.ozk,
    this.ozkLabel,
    this.powierzchnia,
    this.extraAttributes = const {},
  });

  @override
  String toString() {
    final ozkStr = ozk != null ? '/$ozk' : '';
    final powStr = powierzchnia != null ? ' (${powierzchnia.toString()} ha)' : '';
    return '$ofu$ozkStr ($ozu)$powStr';
  }
}
