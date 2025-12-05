import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/address.dart';
import '../data/models/boundary_point.dart';
import '../data/models/ownership_share.dart';
import '../data/models/parcel.dart';
import '../data/models/subject.dart';
import '../data/models/building.dart';
import '../data/models/premises.dart';
import '../data/models/legal_basis.dart';
import '../data/models/land_use.dart';
import '../services/gml_service.dart';

enum ParcelReportMode { full, graphic }

class ParcelReportService {
  final GmlService _gmlService;

  ParcelReportService(this._gmlService);

  Future<void> printParcel(
    Parcel parcel, {
    ParcelReportMode mode = ParcelReportMode.full,
  }) async {
    debugPrint('PDF export start: parcel ${parcel.numerDzialki}, mode $mode');
    try {
      await Printing.layoutPdf(
        onLayout: (format) => _buildPdf([parcel], mode: mode),
        name: 'OperatFlow - Dzialka ${parcel.numerDzialki} (${mode.name})',
      );
      debugPrint('PDF export done: parcel ${parcel.numerDzialki}, mode $mode');
    } catch (e, st) {
      debugPrint('PDF export failed for parcel ${parcel.numerDzialki}: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> printParcels(
    List<Parcel> parcels, {
    ParcelReportMode mode = ParcelReportMode.full,
  }) async {
    debugPrint('PDF export start: ${parcels.length} parcels, mode $mode');
    try {
      await Printing.layoutPdf(
        onLayout: (format) => _buildPdf(parcels, mode: mode),
        name: 'OperatFlow - Raport Zbiorczy (${mode.name})',
      );
      debugPrint('PDF export done: ${parcels.length} parcels, mode $mode');
    } catch (e, st) {
      debugPrint('PDF export failed for batch (${parcels.length}): $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<Uint8List> generatePdfBytes(
    List<Parcel> parcels, {
    ParcelReportMode mode = ParcelReportMode.full,
  }) async {
    debugPrint('PDF bytes build start: ${parcels.length} parcels, mode $mode');
    try {
      final bytes = await _buildPdf(parcels, mode: mode);
      debugPrint('PDF bytes build done: ${parcels.length} parcels, mode $mode');
      return bytes;
    } catch (e, st) {
      debugPrint('PDF bytes build failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<Uint8List> _buildPdf(
    List<Parcel> parcels, {
    ParcelReportMode mode = ParcelReportMode.full,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    for (final parcel in parcels) {
      final points = _gmlService.getPointsForParcel(parcel);
      final owners = _gmlService.getSubjectsForParcel(parcel);
      final addresses = _gmlService.getAddressesForParcel(parcel);
      final buildings = _gmlService.getBuildingsForParcel(parcel);
      final premises = _gmlService.getPremisesForParcel(parcel);
      final legal = _gmlService.getLegalBasesForParcel(parcel);
      final landUses = [...parcel.uzytki, ...parcel.landUseContours];
      final classContours = parcel.classificationContours;

      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _buildHeader(parcel),
            pw.SizedBox(height: 12),
            if (mode == ParcelReportMode.full) ...[
              _buildInfoSection(parcel, addresses),
              pw.SizedBox(height: 12),
              ..._buildLandUseSection('Uzytki / Klasouzytki', landUses),
              if (classContours.isNotEmpty) pw.SizedBox(height: 8),
              if (classContours.isNotEmpty) ..._buildLandUseSection('Kontury klasyfikacyjne', classContours),
              ..._buildBuildingsSection(buildings),
              ..._buildPremisesSection(premises),
              pw.SizedBox(height: 12),
              ..._buildOwnersSection(owners),
              if (legal.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                ..._buildLegalSection(legal),
              ],
              pw.SizedBox(height: 12),
              ..._buildPointsSection(points),
            ] else ...[
              _buildGraphicExcerpt(parcel, points, addresses),
            ],
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
                'Dzialka ewidencyjna: ${parcel.numerDzialki}',
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
    if (parcel.geometryPoints.length < 3) {
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
    final addressStr =
        addresses.isNotEmpty ? addresses.map((a) => a.toSingleLine()).join(', ') : 'Brak danych';

    return pw.DefaultTextStyle(
      style: const pw.TextStyle(fontSize: 9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DANE EWIDENCYJNE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: const {0: pw.FixedColumnWidth(120), 1: pw.FlexColumnWidth()},
            children: [
              _tableRow('Identyfikator:', parcel.idDzialki),
              _tableRow('Obreb:', '${parcel.obrebNazwa ?? ''} [${parcel.obrebId ?? ''}]'),
              _tableRow('Jednostka ewid.:', '${parcel.jednostkaNazwa ?? ''} [${parcel.jednostkaId ?? ''}]'),
              _tableRow('Numer KW:', parcel.numerKW ?? '-'),
              _tableRow('Powierzchnia:', '${parcel.pole ?? '-'} ha'),
              _tableRow('Pow. z geometrii:', parcel.poleGeometryczne?.toString() ?? '-'),
              _tableRow('Rodzaj dzialki:', parcel.rodzajDzialkiLabel ?? parcel.rodzajDzialkiCode ?? '-'),
              _tableRow('Adres:', addressStr),
            ],
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildLandUseSection(String title, List<LandUse> list) {
    if (list.isEmpty) return [];
    final chunks = _chunk(list, 24);
    return [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          ...chunks.map((chunk) => pw.Column(
                children: [
                  pw.Table(
                    columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1)},
                    children: chunk.map((u) {
                      final parts = [u.ofu, u.ozu, if (u.ozk != null) u.ozk!]
                          .where((e) => e.isNotEmpty)
                          .join(' / ');
                      final pow = u.powierzchnia != null ? '${u.powierzchnia} ha' : '-';
                      return _tableRow(parts.isEmpty ? '-' : parts, pow);
                    }).toList(),
                  ),
                  if (chunk != chunks.last) pw.SizedBox(height: 6),
                ],
              )),
        ],
      )
    ];
  }

  List<pw.Widget> _buildBuildingsSection(List<Building> buildings) {
    if (buildings.isEmpty) return [];
    final chunks = _chunk(buildings, 20);
    return [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Budynki', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          ...chunks.map((chunk) => pw.Column(
                children: [
                  pw.Table(
                    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
                    children: chunk.map((b) {
                      final desc = [
                        if (b.number != null) 'nr ${b.number}',
                        if (b.functionCode != null) 'funkcja ${b.functionCode}',
                        if (b.floors != null) 'kond. ${b.floors}',
                        if (b.usableArea != null) 'Pu ${b.usableArea}',
                      ].join(', ');
                      return _tableRow(b.buildingId ?? b.gmlId, desc.isEmpty ? '-' : desc);
                    }).toList(),
                  ),
                  if (chunk != chunks.last) pw.SizedBox(height: 6),
                ],
              )),
        ],
      )
    ];
  }

  List<pw.Widget> _buildPremisesSection(List<Premises> premises) {
    if (premises.isEmpty) return [];
    final chunks = _chunk(premises, 20);
    return [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Lokale', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          ...chunks.map((chunk) => pw.Column(
                children: [
                  pw.Table(
                    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
                    children: chunk.map((l) {
                      final desc = [
                        if (l.number != null) 'nr ${l.number}',
                        if (l.typeCode != null) 'rodzaj ${l.typeCode}',
                        if (l.floor != null) 'kond. ${l.floor}',
                        if (l.usableArea != null) 'Pu ${l.usableArea}',
                      ].join(', ');
                      return _tableRow(l.premisesId ?? l.gmlId, desc.isEmpty ? '-' : desc);
                    }).toList(),
                  ),
                  if (chunk != chunks.last) pw.SizedBox(height: 6),
                ],
              )),
        ],
      )
    ];
  }

  List<pw.Widget> _buildOwnersSection(List<MapEntry<OwnershipShare, Subject?>> owners) {
    if (owners.isEmpty) return [];
    final chunks = _chunk(owners, 18);
    return [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Podmioty i udzialy', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          ...chunks.map((chunk) => pw.Column(
                children: [
                  pw.Table(
                    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1)},
                    children: chunk.map((entry) {
                      final share = entry.key;
                      final subject = entry.value;
                      final name = subject?.name ?? 'Nieznany podmiot';
                      final role = subject?.type ?? '-';
                      final right = share.rightTypeLabel ?? share.rightTypeCode ?? '';
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text(name),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text([role, right].where((e) => e.isNotEmpty).join(' | ')),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text(share.share),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  if (chunk != chunks.last) pw.SizedBox(height: 6),
                ],
              )),
        ],
      )
    ];
  }

  List<pw.Widget> _buildPointsSection(List<BoundaryPoint> points) {
    if (points.isEmpty) return [];
    final chunks = _chunk(points, 20);
    final allOperats = points
        .map((p) => p.operat?.trim())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Punkty graniczne', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          ...chunks.map((chunk) => pw.Column(
                children: [
                  pw.Table(
                    columnWidths: const {
                      0: pw.FlexColumnWidth(1.5),
                      1: pw.FlexColumnWidth(1),
                      2: pw.FlexColumnWidth(1),
                      3: pw.FlexColumnWidth(1),
                      4: pw.FlexColumnWidth(1),
                      5: pw.FlexColumnWidth(1.2),
                    },
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text('ID punktu', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text('Nr', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text('SPD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text('ISD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text('STB', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            child: pw.Text('Operat', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...chunk.map((p) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(p.displayFullId),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(p.displayNumer),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(p.spd ?? '-'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(p.isd ?? '-'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(p.stb ?? '-'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(p.operat ?? '-'),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  if (chunk != chunks.last) pw.SizedBox(height: 6),
                ],
              )),
          pw.SizedBox(height: 4),
          pw.Text(
            'Operaty: ${allOperats.isNotEmpty ? allOperats.join(', ') : '-'}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
          ),
        ],
      )
    ];
  }

  List<pw.Widget> _buildLegalSection(List<LegalBasis> legal) {
    if (legal.isEmpty) return [];
    final chunks = _chunk(legal, 24);
    return [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Podstawy prawne', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          ...chunks.map((chunk) => pw.Column(
                children: [
                  pw.Table(
                    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
                    children: chunk.map((l) {
                      final desc = [
                        l.type,
                        l.documentTypeLabel ?? l.documentTypeCode,
                        if (l.date != null) l.date,
                        if (l.description != null) l.description,
                      ].whereType<String>().where((e) => e.isNotEmpty).join(' | ');
                      return _tableRow(l.number ?? l.gmlId, desc.isEmpty ? '-' : desc);
                    }).toList(),
                  ),
                  if (chunk != chunks.last) pw.SizedBox(height: 6),
                ],
              )),
        ],
      )
    ];
  }

  pw.Widget _buildGraphicExcerpt(
      Parcel parcel, List<BoundaryPoint> points, List<Address> addresses) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildInfoSection(parcel, addresses),
        pw.SizedBox(height: 12),
        ..._buildPointsSection(points),
        pw.SizedBox(height: 12),
        pw.Text('Podglad geometrii', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 6),
        _buildGeometryPreview(parcel),
      ],
    );
  }

  pw.TableRow _tableRow(String left, String right) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(left),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(right),
        ),
      ],
    );
  }

  List<List<T>> _chunk<T>(List<T> items, int size) {
    if (items.isEmpty || size <= 0) return [];
    final result = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size) > items.length ? items.length : (i + size);
      result.add(items.sublist(i, end));
    }
    return result;
  }
}



