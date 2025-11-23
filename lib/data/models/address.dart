class Address {
  final String gmlId;
  final String? kraj;
  final String? miejscowosc;
  final String? kodPocztowy;
  final String? ulica;
  final String? numerPorzadkowy;

  Address({
    required this.gmlId,
    this.kraj,
    this.miejscowosc,
    this.kodPocztowy,
    this.ulica,
    this.numerPorzadkowy,
  });

  String toSingleLine() {
    final List<String> parts = [];

    final String streetAndNumber = [
      ulica,
      numerPorzadkowy,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' ');
    
    if (streetAndNumber.isNotEmpty) {
      parts.add(streetAndNumber);
    }

    final String cityAndPostal = [
      kodPocztowy,
      miejscowosc,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' ');
    
    if (cityAndPostal.isNotEmpty) {
      parts.add(cityAndPostal);
    }

    if (kraj != null && kraj!.trim().isNotEmpty) {
      parts.add(kraj!);
    }

    if (parts.isEmpty) {
      return 'Brak danych adresowych';
    }
    return parts.join(', ');
  }
}