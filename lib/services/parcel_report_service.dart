import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException, rootBundle;
import 'package:intl/intl.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/widgets.dart' show PdfGoogleFonts;
import 'package:printing/printing.dart';

import '../data/models/address.dart';
import '../data/models/boundary_point.dart';
import '../data/models/building.dart';
import '../data/models/legal_basis.dart';
import '../data/models/land_use.dart';
import '../data/models/ownership_share.dart';
import '../data/models/parcel.dart';
import '../data/models/premises.dart';
import '../data/models/subject.dart';
import '../repositories/gml_repository.dart';

enum ParcelReportMode { full, graphic }

class ParcelReportService {
  ParcelReportService(this._gmlRepository);

  final GmlRepository _gmlRepository;

  Future<void> printParcel(
    Parcel parcel, {
    ParcelReportMode mode = ParcelReportMode.full,
  }) async {
    await printParcels([parcel], mode: mode);
  }

  Future<void> printParcels(
    List<Parcel> parcels, {
    ParcelReportMode mode = ParcelReportMode.full,
  }) async {
    final bytes = await generatePdfBytes(parcels, mode: mode);
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: 'OperatFlow - Raport (${mode.name})',
    );
  }

  Future<Uint8List> generatePdfBytes(
    List<Parcel> parcels, {
    ParcelReportMode mode = ParcelReportMode.full,
  }) async {
    if (_htmlSupported()) {
      final html = await _renderHtml(parcels, mode);
      return _convertHtmlWithFallback(html, parcels, mode);
    }
    debugPrint('convertHtml unsupported on ${Platform.operatingSystem}, using pw fallback');
    return _buildPwPdf(parcels, mode: mode);
  }

  Future<String> _renderHtml(
    List<Parcel> parcels,
    ParcelReportMode mode,
  ) async {
    final templateSource =
        await rootBundle.loadString('assets/templates/parcel_report_template.html');
    final template = Template(templateSource, htmlEscapeValues: true);
    final data = {
      'modeLabel': mode == ParcelReportMode.full ? 'Dane pełne' : 'Wypis graficzny',
      'generatedAt': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      'showFull': mode == ParcelReportMode.full,
      'parcels': parcels.map((p) => _parcelToTemplateMap(p, mode)).toList(),
    };
    return template.renderString(data);
  }

  Map<String, dynamic> _parcelToTemplateMap(
    Parcel parcel,
    ParcelReportMode mode,
  ) {
    final addresses =
        _gmlRepository.getAddressesForParcel(parcel).map((a) => a.toSingleLine()).toList();
    final owners = _gmlRepository.getSubjectsForParcel(parcel).map((entry) {
      final subject = entry.value;
      return {
        'name': subject?.name ?? 'Nieznany podmiot',
        'role': subject?.type ?? '',
        'share': entry.key.share,
        'right': entry.key.rightTypeLabel ?? entry.key.rightTypeCode ?? '',
        'addresses': subject != null
            ? _gmlRepository.getAddressesForSubject(subject).map((a) => a.toSingleLine()).toList()
            : const <String>[],
      };
    }).toList();

    final landUses = [
      ...parcel.uzytki,
      ..._gmlRepository.getLandUseContours(parcel),
    ]
        .map((u) => {
              'ofu': u.ofu ?? '',
              'ozu': u.ozu ?? '',
              'ozk': u.ozk ?? '',
              'powierzchnia': _formatDouble(u.powierzchnia, suffix: 'ha'),
            })
        .toList();

    final classContours = _gmlRepository
        .getClassificationContours(parcel)
        .map((u) => {
              'ofu': u.ofu ?? '',
              'ozu': u.ozu ?? '',
              'ozk': u.ozk ?? '',
              'powierzchnia': _formatDouble(u.powierzchnia, suffix: 'ha'),
            })
        .toList();

    final points = _gmlRepository
        .getPointsForParcel(parcel)
        .map((p) => {
              'id': p.displayFullId,
              'nr': p.displayNumer,
              'spd': p.spd ?? '-',
              'isd': p.isd ?? '-',
              'stb': p.stb ?? '-',
              'operat': p.operat ?? '-',
              'x': p.x ?? '-',
              'y': p.y ?? '-',
            })
        .toList();

    final buildings = _gmlRepository
        .getBuildingsForParcel(parcel)
        .map((b) => {
              'label': b.buildingId ?? b.gmlId,
              'description': _compactParts([
                if (b.number != null) 'nr ${b.number}',
                if (b.functionCode != null) 'funkcja ${b.functionCode}',
                if (b.floors != null) 'kond. ${b.floors}',
                if (b.usableArea != null) 'Pu ${b.usableArea}',
              ]),
            })
        .toList();

    final premises = _gmlRepository
        .getPremisesForParcel(parcel)
        .map((l) => {
              'label': l.premisesId ?? l.gmlId,
              'description': _compactParts([
                if (l.number != null) 'nr ${l.number}',
                if (l.typeCode != null) 'rodzaj ${l.typeCode}',
                if (l.floor != null) 'kond. ${l.floor}',
                if (l.usableArea != null) 'Pu ${l.usableArea}',
              ]),
            })
        .toList();

    final legal = _gmlRepository
        .getLegalBasesForParcel(parcel)
        .map((l) => {
              'label': l.number ?? l.gmlId,
              'description': _compactParts([
                l.type,
                l.documentTypeLabel ?? l.documentTypeCode,
                l.date,
                l.description,
              ]),
            })
        .toList();

    return {
      'numerDzialki': parcel.numerDzialki,
      'idDzialki': parcel.idDzialki,
      'obreb': _formatObreb(parcel),
      'kw': parcel.numerKW ?? '-',
      'powierzchnia': _formatDouble(parcel.pole, suffix: 'ha'),
      'adresy': addresses,
      'owners': owners,
      'landUses': landUses,
      'classUses': classContours,
      'points': points,
      'buildings': buildings,
      'premises': premises,
      'legal': legal,
      'showFull': mode == ParcelReportMode.full,
    };
  }

  String _formatObreb(Parcel parcel) {
    final reg = RegExp(r'^\d+_\d\.(\d{4})');
    final match = reg.firstMatch(parcel.idDzialki);
    final obrebNumber = match != null ? match.group(1) : parcel.obrebId ?? '-';
    final name = parcel.obrebNazwa ?? '';
    if (name.isNotEmpty) {
      return '$name ${obrebNumber ?? ''}'.trim();
    }
    return obrebNumber ?? '-';
  }

  String _compactParts(List<String?> parts) {
    return parts.whereType<String>().where((e) => e.isNotEmpty).join(' | ');
  }

  String _formatDouble(double? value, {String suffix = ''}) {
    if (value == null) return '-';
    final formatted = value.toStringAsFixed(4);
    return suffix.isNotEmpty ? '$formatted $suffix' : formatted;
  }

  bool _htmlSupported() {
    if (kIsWeb) return true;
    if (Platform.isWindows || Platform.isLinux) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  Future<Uint8List> _convertHtmlWithFallback(
    String html,
    List<Parcel> parcels,
    ParcelReportMode mode,
  ) async {
    try {
      debugPrint('convertHtml start len=${html.length} platform=${Platform.operatingSystem}');
      final bytes = await Printing.convertHtml(
        format: PdfPageFormat.a4,
        html: html,
      );
      debugPrint('convertHtml success bytes=${bytes.length}');
      return bytes;
    } on MissingPluginException catch (e, st) {
      debugPrint('convertHtml missing plugin on ${Platform.operatingSystem}: $e');
      debugPrint('$st');
    } catch (e, st) {
      debugPrint('convertHtml failed: $e');
      debugPrint('$st');
    }

    debugPrint('Falling back to pw PDF build (mode=${mode.name}, parcels=${parcels.length})');
    return _buildPwPdf(parcels, mode: mode);
  }

  Future<Uint8List> _buildPwPdf(List<Parcel> parcels, {required ParcelReportMode mode}) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold).copyWith(
      defaultTextStyle: pw.TextStyle(fontSize: 10),
    );

    for (final parcel in parcels) {
      final addresses = _gmlRepository.getAddressesForParcel(parcel).map((a) => a.toSingleLine()).toList();
      final owners = _gmlRepository.getSubjectsForParcel(parcel);
      final points = _gmlRepository.getPointsForParcel(parcel);
      final landUses = [
        ...parcel.uzytki,
        ..._gmlRepository.getLandUseContours(parcel),
      ];
      final classUses = _gmlRepository.getClassificationContours(parcel);
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => [
            pw.Text('Działka ${parcel.numerDzialki}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Id: ${parcel.idDzialki} | KW: ${parcel.numerKW ?? '-'}'),
            pw.Text('Pow: ${_formatDouble(parcel.pole, suffix: 'ha')}'),
            pw.SizedBox(height: 8),
            pw.Text('Adresy:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (addresses.isEmpty) pw.Text('Brak adresów') else ...addresses.map((a) => pw.Text(a)),
            if (mode == ParcelReportMode.full) ...[
              pw.SizedBox(height: 12),
              pw.Text('Użytki gruntowe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (landUses.isEmpty)
                pw.Text('Brak danych')
              else
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2), 3: pw.FlexColumnWidth(1)},
                  children: [
                    pw.TableRow(
                      children: ['OFU', 'OZU', 'OZK', 'Pow. (ha)']
                          .map((h) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                                child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              ))
                          .toList(),
                    ),
                    ...landUses.map(
                      (u) => pw.TableRow(
                        children: [
                          u.ofu ?? '',
                          u.ozu ?? '',
                          u.ozk ?? '',
                          _formatDouble(u.powierzchnia, suffix: 'ha'),
                        ].map((txt) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(txt))).toList(),
                      ),
                    ),
                  ],
                ),
              pw.SizedBox(height: 10),
              pw.Text('Kontury klasyfikacyjne', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (classUses.isEmpty)
                pw.Text('Brak danych')
              else
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2), 3: pw.FlexColumnWidth(1)},
                  children: [
                    pw.TableRow(
                      children: ['OFU', 'OZU', 'OZK', 'Pow. (ha)']
                          .map((h) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                                child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              ))
                          .toList(),
                    ),
                    ...classUses.map(
                      (u) => pw.TableRow(
                        children: [
                          u.ofu ?? '',
                          u.ozu ?? '',
                          u.ozk ?? '',
                          _formatDouble(u.powierzchnia, suffix: 'ha'),
                        ].map((txt) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(txt))).toList(),
                      ),
                    ),
                  ],
                ),
              pw.SizedBox(height: 12),
              pw.Text('Podmioty i udziały', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (owners.isEmpty)
                pw.Text('Brak danych')
              else
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(1),
                    2: pw.FlexColumnWidth(1),
                  },
                  children: owners.map((e) {
                    final subject = e.value;
                    final share = e.key.share;
                    final role = e.key.rightTypeLabel ?? e.key.rightTypeCode ?? '';
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(subject?.name ?? 'Nieznany')),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(role)),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(share)),
                      ],
                    );
                  }).toList(),
                ),
            ],
            pw.SizedBox(height: 12),
            pw.Text('Punkty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (points.isEmpty)
              pw.Text('Brak danych')
            else
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    children: ['ID', 'Nr', 'X', 'Y', 'SPD', 'ISD', 'Operat']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ...points.map((p) => pw.TableRow(
                        children: [
                          p.displayFullId,
                          p.displayNumer,
                          p.x ?? '-',
                          p.y ?? '-',
                          p.spd ?? '-',
                          p.isd ?? '-',
                          p.operat ?? '-',
                        ].map((txt) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(txt))).toList(),
                      )),
                ],
              ),
          ],
        ),
      );
    }
    return doc.save();
  }
}
