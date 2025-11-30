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

  // --- Public API ---

  Future<void> printParcel(Parcel parcel) async {
    await Printing.layoutPdf(
      onLayout: (format) => _buildPdf([parcel]),
      name: 'OperatFlow - Dzialka ${parcel.numerDzialki}',
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

  // --- PDF Generation ---

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
            pw.SizedBox(height: 12),
            _buildInfoSection(parcel, addresses),
            pw.SizedBox(height: 12),
            _buildOwnersSection(owners),
            pw.SizedBox(height: 12),
            _buildPointsSection(points),
            pw.Footer(
              margin: const pw.EdgeInsets.only(top: 16),
              title: pw.Text(
                'Wygenerowano w OperatFlow GML Viewer',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
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
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Działka ewidencyjna: ${parcel.numerDzialki}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        pw.SizedBox(
          height: 100,
          width: 140,
          child: _buildGeometryPreview(parcel),
        ),
      ],
    );
  }

  pw.Widget _buildGeometryPreview(Parcel parcel) {
    if (parcel.geometryPoints.isEmpty) {
      return pw.Container();
    }
    final xs = parcel.geometryPoints.map((p) => p.y).toList();
    final ys = parcel.geometryPoints.map((p) => p.x).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final width = (maxX - minX).abs();
    final height = (maxY - minY).abs();

    if (width == 0 || height == 0) return pw.Container();

    const double boxW = 140;
    const double boxH = 100;
    const double padding = 8.0;

    final scaleX = (boxW - padding * 2) / width;
    final scaleY = (boxH - padding * 2) / height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledW = width * scale;
    final scaledH = height * scale;
    final offsetX = (boxW - scaledW) / 2;
    final offsetY = (boxH - scaledH) / 2;

    final points = parcel.geometryPoints.map((p) {
      final px = (p.y - minX) * scale + offsetX;
      final py = (maxY - p.x) * scale + offsetY;
      return {'x': px, 'y': py};
    }).toList();

    final pathData = StringBuffer();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      pathData.write('${i == 0 ? 'M' : 'L'}${p['x']},${p['y']} ');
    }
    pathData.write('Z');

    final svg = '''
<svg width="$boxW" height="$boxH" viewBox="0 0 $boxW $boxH" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="$boxW" height="$boxH" fill="#f5f7fa" stroke="#e1e6ed" stroke-width="1"/>
  <path d="${pathData.toString()}" fill="#2f80ed" fill-opacity="0.1" stroke="#2f80ed" stroke-width="1.2"/>
</svg>
''';
    return pw.SvgImage(svg: svg);
  }

  pw.Widget _buildInfoSection(Parcel parcel, List<Address> addresses) {
    final addressStr = addresses.isNotEmpty ? addresses.map((a) => a.toSingleLine()).join(', ') : 'Brak danych';
    final uzytkiRows = parcel.uzytki.map((u) {
      final parts = [u.ofu, u.ozu];
      if (u.ozk != null && u.ozk!.isNotEmpty) parts.add(u.ozk!);
      final label = parts.where((s) => s != null && s.isNotEmpty && s != '?').join(' / ');
      return _tableRow(label.isEmpty ? '-' : label, '${u.powierzchnia ?? '-'} ha');
    }).toList();

    return pw.DefaultTextStyle(
      style: const pw.TextStyle(fontSize: 9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DANE EWIDENCYJNE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: const {0: pw.FixedColumnWidth(100), 1: pw.FlexColumnWidth()},
            children: [
              _tableRow('Identyfikator:', parcel.idDzialki),
              _tableRow('Obręb:', '${parcel.obrebNazwa ?? ""} [${parcel.obrebId ?? ""}]'),
              _tableRow('Jednostka ewid.:', '${parcel.jednostkaNazwa ?? ""} [${parcel.jednostkaId ?? ""}]'),
              _tableRow('Numer KW:', parcel.numerKW ?? '-'),
              _tableRow('Powierzchnia:', '${parcel.pole} ha'),
              _tableRow('Adres:', addressStr),
            ],
          ),
          if (uzytkiRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Użytki', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Table(
              columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1)},
              children: uzytkiRows,
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildOwnersSection(List<MapEntry<OwnershipShare, Subject?>> owners) {
    if (owners.isEmpty) return pw.Container();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('WŁAŚCICIELE / WŁADAJĄCY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _tableHeaderCell('Podmiot'),
                _tableHeaderCell('Udział', align: pw.TextAlign.center),
                _tableHeaderCell('Typ', align: pw.TextAlign.center),
                _tableHeaderCell('Adres'),
              ],
            ),
            ...owners.map((entry) {
              final subject = entry.value;
              final addressStr = subject != null ? _gmlService.getAddressesForSubject(subject).map((a) => a.toSingleLine()).join(', ') : '';
              return pw.TableRow(
                children: [
                  _tableCell(subject?.name ?? 'Nieznany podmiot'),
                  _tableCell(entry.key.share, align: pw.TextAlign.center),
                  _tableCell(subject?.type ?? '-', align: pw.TextAlign.center),
                  _tableCell(addressStr.isNotEmpty ? addressStr : 'Brak adresu'),
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
        pw.Text('PUNKTY GRANICZNE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2), 1: pw.FlexColumnWidth(1.2), 2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(0.8), 4: pw.FlexColumnWidth(0.8), 5: pw.FlexColumnWidth(0.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _tableHeaderCell('Numer'), _tableHeaderCell('X'), _tableHeaderCell('Y'),
                _tableHeaderCell('SPD'), _tableHeaderCell('ISD'), _tableHeaderCell('STB'),
              ],
            ),
            ...points.map((p) => pw.TableRow(
                children: [
                  _tableCell(p.displayNumer),
                  _tableCell(p.x ?? '-'),
                  _tableCell(p.y ?? '-'),
                  _tableCell(p.spd ?? '-'),
                  _tableCell(p.isd ?? '-'),
                  _tableCell(p.stb ?? '-'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Text(value),
      ),
    ]);
  }

  pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8), textAlign: align),
    );
  }

  pw.Widget _tableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: align),
    );
  }
}
