import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/address.dart';
import '../data/models/boundary_point.dart';
import '../data/models/ownership_share.dart';
import '../data/models/parcel.dart';
import '../data/models/subject.dart';
import '../services/gml_service.dart';

class ParcelReportService {
  final GmlService _gmlService;

  ParcelReportService(this._gmlService);

  Future<void> printParcel(Parcel parcel) async {
    await Printing.layoutPdf(
      onLayout: (format) => _buildPdf([parcel]),
      name: 'OperatFlow - Dzialka ${parcel.pelnyNumerDzialki}',
    );
  }

  Future<void> printParcels(List<Parcel> parcels) async {
    await Printing.layoutPdf(
      onLayout: (format) => _buildPdf(parcels),
      name: 'OperatFlow - Raport Zbiorczy',
    );
  }

  Future<Uint8List> generatePdfBytes(List<Parcel> parcels) async {
    return _buildPdf(parcels);
  }

  Future<Uint8List> _buildPdf(List<Parcel> parcels) async {
    final doc = pw.Document();

    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    for (final parcel in parcels) {
      final points = _gmlService.getPointsForParcel(parcel);
      final owners = _gmlService.getSubjectsForParcel(parcel);
      final addresses = _gmlService.getAddressesForParcel(parcel);

      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _buildHeader(parcel),
            pw.SizedBox(height: 16),
            _buildInfoSection(parcel, addresses),
            pw.SizedBox(height: 16),
            _buildOwnersSection(owners),
            pw.SizedBox(height: 16),
            _buildPointsSection(points),
            pw.Footer(
              margin: const pw.EdgeInsets.only(top: 20),
              title: pw.Text(
                'Wygenerowano w OperatFlow GML Viewer',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildHeader(Parcel parcel) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'WYPIS Z DANYCH GML',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Dzialka ewidencyjna: ${parcel.pelnyNumerDzialki}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(
          height: 120,
          width: 160,
          child: _buildGeometryPreview(parcel),
        ),
      ],
    );
  }

  pw.Widget _buildGeometryPreview(Parcel parcel) {
    if (parcel.geometryPoints.isEmpty) {
      return pw.Container();
    }
    // Utrzymujemy ten sam układ osi co w podglądzie aplikacji:
    // oś X rysunku = współrzędna Y punktu, oś Y rysunku = współrzędna X punktu (odwrócona).
    final xs = parcel.geometryPoints.map((p) => p.y).toList(); // na osi poziomej
    final ys = parcel.geometryPoints.map((p) => p.x).toList(); // na osi pionowej
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final width = (maxX - minX).abs();
    final height = (maxY - minY).abs();

    // Utrzymujemy trochę paddingu wokół kształtu.
    const double boxW = 160 - 12;
    const double boxH = 120 - 12;
    final scale = width == 0 || height == 0
        ? 1.0
        : 0.9 * (width > height ? boxW / width : boxH / height);
    final offsetX = boxW / 2;
    final offsetY = boxH / 2;

    final points = parcel.geometryPoints.map((p) {
      final px = (p.y - minX - width / 2) * scale + offsetX;
      final py = (maxY - p.x) * scale + offsetY; // flip osi Y jak w UI
      return {'x': px, 'y': py};
    }).toList();

    final pathData = StringBuffer();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      pathData.write('${i == 0 ? 'M' : 'L'}${p['x']},${p['y']} ');
    }
    pathData.write('Z');

    final svg =
        '''
<svg width="160" height="120" viewBox="0 0 $boxW $boxH" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="$boxW" height="$boxH" fill="white" stroke="#999" stroke-width="1"/>
  <path d="${pathData.toString()}" fill="#e8f1fb" stroke="#2c6ecb" stroke-width="1.2"/>
</svg>
''';

    return pw.SvgImage(svg: svg);
  }

  pw.Widget _buildInfoSection(Parcel parcel, List<Address> addresses) {
    final addressStr = addresses.isNotEmpty
        ? addresses.map((a) => a.toSingleLine()).join(', ')
        : 'Brak danych adresowych';

    final uzytkiRows = parcel.uzytki
        .map(
          (u) => _tableRow(
            '${u.ofu} / ${u.ozu}${u.ozk != null ? ' / ${u.ozk}' : ''}',
            '${u.powierzchnia ?? '-'} ha',
          ),
        )
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DANE EWIDENCYJNE',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: const {
            0: pw.FixedColumnWidth(120),
            1: pw.FlexColumnWidth(),
          },
          children: [
            _tableRow('Identyfikator:', parcel.idDzialki),
            _tableRow(
              'Obreb:',
              '${parcel.obrebNazwa ?? ""} [${parcel.obrebId ?? ""}]',
            ),
            _tableRow(
              'Jednostka ewid.:',
              '${parcel.jednostkaNazwa ?? ""} [${parcel.jednostkaId ?? ""}]',
            ),
            _tableRow('Numer KW:', parcel.numerKW ?? '-'),
            _tableRow('Powierzchnia:', '${parcel.pole} ha'),
            _tableRow('Adres:', addressStr),
          ],
        ),
        if (uzytkiRows.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Użytki (OFU / OZU / OZK)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
            },
            children: uzytkiRows,
          ),
        ],
      ],
    );
  }

  pw.Widget _buildOwnersSection(
    List<MapEntry<OwnershipShare, Subject?>> owners,
  ) {
    if (owners.isEmpty) return pw.Container();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'WLASCICIELE / WLADAJACY',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Podmiot',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Udzial',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Typ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Adres',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            ...owners.map((entry) {
              final share = entry.key;
              final subject = entry.value;
              final addressStr = subject != null
                  ? _gmlService
                        .getAddressesForSubject(subject)
                        .map((a) => a.toSingleLine())
                        .join(', ')
                  : '';
              final resolvedAddress = addressStr.isNotEmpty
                  ? addressStr
                  : 'Brak adresu';
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(subject?.name ?? 'Nieznany podmiot'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(share.share, textAlign: pw.TextAlign.center),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      subject?.type ?? '-',
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(resolvedAddress),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPointsSection(List<BoundaryPoint> points) {
    if (points.isEmpty) return pw.Container();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PUNKTY GRANICZNE',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2), // Pelne ID
            1: pw.FlexColumnWidth(1), // Numer
            2: pw.FlexColumnWidth(1), // X
            3: pw.FlexColumnWidth(1), // Y
            4: pw.FlexColumnWidth(1), // SPD
            5: pw.FlexColumnWidth(1), // ISD
            6: pw.FlexColumnWidth(1), // STB
            7: pw.FlexColumnWidth(2), // Operat
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _tableHeaderCell('Pelne ID'),
                _tableHeaderCell('Numer'),
                _tableHeaderCell('X'),
                _tableHeaderCell('Y'),
                _tableHeaderCell('SPD'),
                _tableHeaderCell('ISD'),
                _tableHeaderCell('STB'),
                _tableHeaderCell('Operat'),
              ],
            ),
            ...points.map(
              (p) => pw.TableRow(
                children: [
                  _tableCell(p.pelneId, fontSize: 8),
                  _tableCell(p.displayNumer),
                  _tableCell(p.x ?? '-'),
                  _tableCell(p.y ?? '-'),
                  _tableCell(p.spd ?? '-'),
                  _tableCell(p.isd ?? '-'),
                  _tableCell(p.stb ?? '-'),
                  _tableCell(p.operat ?? '-'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            label,
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(value),
        ),
      ],
    );
  }

  pw.Widget _tableCell(String text, {double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize)),
    );
  }

  pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      ),
    );
  }
}
