class LandUse {
  final String ofu;
  final String ozu;
  final String? ozk;
  final double? powierzchnia;

  LandUse({
    required this.ofu, 
    required this.ozu, 
    this.ozk, 
    this.powierzchnia
  });

  @override
  String toString() {
    final ozkStr = ozk != null ? '/$ozk' : '';
    final powStr = powierzchnia != null ? ' (${powierzchnia.toString()} ha)' : '';
    return '$ofu$ozkStr ($ozu)$powStr';
  }
}