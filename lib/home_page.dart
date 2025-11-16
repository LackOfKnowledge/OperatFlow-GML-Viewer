import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'gml_service.dart';

enum DetailView { dane, podmioty, punkty }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GmlService _gmlService = GmlService();
  Parcel? _selectedParcel;
  bool _isLoading = false;
  String? _fileName;
  final Set<String> _markedParcelIds = <String>{};
  bool _isDragging = false;
  DetailView _currentView = DetailView.dane;

  Future<void> _pickAndParseGml() async {
    setState(() {
      _isLoading = true;
      _selectedParcel = null;
      _fileName = null;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['gml', 'xml'],
        withData: false,
      );

      if (result != null && result.files.single.path != null) {
        final String path = result.files.single.path!;
        final String fileName = result.files.single.name;

        final Uint8List fileBytes = await File(path).readAsBytes();
        await _gmlService.parseGml(fileBytes);

        setState(() {
          _fileName = fileName;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Błąd wczytywania pliku: $e');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Wystąpił błąd podczas parsowania pliku: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _printSelectedParcel() async {
    final List<Parcel> parcelsToPrint;
    if (_markedParcelIds.isNotEmpty) {
      parcelsToPrint = _gmlService.parcels
          .where((Parcel p) => _markedParcelIds.contains(p.gmlId))
          .toList();
    } else if (_selectedParcel != null) {
      parcelsToPrint = <Parcel>[_selectedParcel!];
    } else {
      return;
    }

    await Printing.layoutPdf(onLayout: (format) async => _buildParcelsPdf(parcelsToPrint));
  }

  Future<void> _exportSelectedParcelPdf() async {
    if (_selectedParcel == null) return;

    final String safeNumber = _selectedParcel!.pelnyNumerDzialki.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    final Uint8List bytes = await _buildParcelsPdf(<Parcel>[_selectedParcel!]);
    await _savePdf(bytes, 'OperatFlow_GML_$safeNumber.pdf');
  }

  Future<void> _exportMarkedParcelsPdf() async {
    final List<Parcel> selectedParcels = _gmlService.parcels
        .where((Parcel p) => _markedParcelIds.contains(p.gmlId))
        .toList();
    if (selectedParcels.isEmpty) return;

    final Uint8List bytes = await _buildParcelsPdf(selectedParcels);
    await _savePdf(bytes, 'OperatFlow_GML_zbiorczy.pdf');
  }

  String _formatAddress(Address address) {
    return address.toSingleLine();
  }

  String _toAscii(String text) {
    const Map<String, String> map = <String, String>{
      'ą': 'a',
      'Ą': 'A',
      'ć': 'c',
      'Ć': 'C',
      'ę': 'e',
      'Ę': 'E',
      'ł': 'l',
      'Ł': 'L',
      'ń': 'n',
      'Ń': 'N',
      'ó': 'o',
      'Ó': 'O',
      'ś': 's',
      'Ś': 'S',
      'ź': 'z',
      'Ź': 'Z',
      'ż': 'z',
      'Ż': 'Z',
    };
    var result = text;
    map.forEach((String from, String to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }

  Future<Uint8List> _buildParcelsPdf(List<Parcel> parcels) async {
    final pw.Font baseFont = await PdfGoogleFonts.robotoRegular();
    final pw.Font boldFont = await PdfGoogleFonts.robotoBold();

    final pw.ThemeData theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);

    final pw.Document doc = pw.Document(theme: theme);
    final pw.TextStyle headerStyle = pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
    final pw.TextStyle labelStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);

    pw.TableRow detailRow(String label, String value) {
      return pw.TableRow(
        children: <pw.Widget>[
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(label, style: labelStyle),
          ),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(value)),
        ],
      );
    }

    for (final Parcel parcel in parcels) {
      final List<MapEntry<OwnershipShare, Subject?>> subjectsWithShares = _gmlService
          .getSubjectsForParcel(parcel);
      final List<BoundaryPoint> points = _gmlService.getPointsForParcel(parcel);
      final List<Address> parcelAddresses = _gmlService.getAddressesForParcel(parcel);
      final String adresNieruchomosci = parcelAddresses.isEmpty
          ? 'Brak danych adresowych.'
          : parcelAddresses.map(_formatAddress).join('\n');
      final String jednostkaLabel = parcel.jednostkaNazwa != null && parcel.jednostkaId != null
          ? '${_toAscii(parcel.jednostkaNazwa!)} [${parcel.jednostkaId}]'
          : parcel.jednostkaEwidencyjna;
      final String obrebCode = parcel.obrebId?.split('.').last ?? parcel.obreb;
      final String obrebLabel = parcel.obrebNazwa != null
          ? '${_toAscii(parcel.obrebNazwa!)} [$obrebCode]'
          : obrebCode;

      doc.addPage(
        pw.MultiPage(
          build: (pw.Context context) => <pw.Widget>[
            pw.Text(
              'Działka ${parcel.pelnyNumerDzialki}',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Dane działki', style: headerStyle),
            pw.SizedBox(height: 4),
            pw.Table(
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
              },
              border: pw.TableBorder.all(width: 0.3),
              children: <pw.TableRow>[
                detailRow('Jednostka', jednostkaLabel),
                detailRow('Obreb', obrebLabel),
                detailRow('Dzialka', parcel.numerDzialki),
                detailRow('Numer KW', parcel.numerKW ?? 'Brak'),
                detailRow('Pole ewidencyjne', '${parcel.pole?.toString() ?? '?'} ha'),
                detailRow('Adres nieruchomosci', adresNieruchomosci),
              ],
            ),
            if (parcel.uzytki.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 12),
              pw.Text('Klasouzytki', style: headerStyle),
              pw.SizedBox(height: 4),
              pw.Table(
                columnWidths: const <int, pw.TableColumnWidth>{
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                },
                border: pw.TableBorder.all(width: 0.3),
                children: <pw.TableRow>[
                  pw.TableRow(
                    children: <pw.Widget>[
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Klasa', style: labelStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Powierzchnia [ha]', style: labelStyle),
                      ),
                    ],
                  ),
                  ...parcel.uzytki.map(
                    (LandUse u) => pw.TableRow(
                      children: <pw.Widget>[
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${u.ofu} (${u.ozu})${u.ozk != null ? '/${u.ozk}' : ''}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(u.powierzchnia?.toString() ?? '?'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            pw.SizedBox(height: 16),
            pw.Text('Właściciele', style: headerStyle),
            pw.SizedBox(height: 4),
            if (subjectsWithShares.isEmpty)
              pw.Text('Brak powiązanych podmiotów.')
            else
              pw.Table(
                border: pw.TableBorder.all(width: 0.3),
                columnWidths: const <int, pw.TableColumnWidth>{
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(1),
                },
                children: <pw.TableRow>[
                  pw.TableRow(
                    children: <pw.Widget>[
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Nazwa', style: labelStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Rodzaj', style: labelStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Udziały', style: labelStyle),
                      ),
                    ],
                  ),
                  ...subjectsWithShares.map((MapEntry<OwnershipShare, Subject?> entry) {
                    final OwnershipShare share = entry.key;
                    final Subject? subject = entry.value;
                    return pw.TableRow(
                      children: <pw.Widget>[
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(subject?.name ?? 'Nieznany podmiot'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(subject?.type ?? 'Brak'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(share.share),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 16),
            pw.Text('Punkty graniczne', style: headerStyle),
            pw.SizedBox(height: 4),
            if (points.isEmpty)
              pw.Text('Brak danych o punktach granicznych.')
            else
              pw.Table(
                border: pw.TableBorder.all(width: 0.3),
                columnWidths: const <int, pw.TableColumnWidth>{
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1),
                  6: pw.FlexColumnWidth(2),
                },
                children: <pw.TableRow>[
                  pw.TableRow(
                    children: <pw.Widget>[
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Numer', style: labelStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('X', style: labelStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Y', style: labelStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('ISD', style: labelStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('STB', style: labelStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('SPD', style: labelStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Operat', style: labelStyle),
                      ),
                    ],
                  ),
                  ...points.map(
                    (BoundaryPoint p) => pw.TableRow(
                      children: <pw.Widget>[
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(p.numer ?? '-'),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(p.x ?? '-')),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(p.y ?? '-')),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(p.isd ?? '-'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(p.stb ?? '-'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(p.spd ?? '-'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(p.operat ?? '-'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return doc.save();
  }

  Future<void> _savePdf(Uint8List bytes, String suggestedFileName) async {
    final String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Zapisz raport PDF',
      fileName: suggestedFileName,
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
    );
    if (path == null) return;

    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Plik PDF został zapisany.')));
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() {
      _isDragging = false;
    });

    if (details.files.isEmpty) return;

    final file = details.files.firstWhere((f) {
      final String name = f.name.toLowerCase();
      return name.endsWith('.gml') || name.endsWith('.xml');
    }, orElse: () => details.files.first);

    setState(() {
      _isLoading = true;
      _selectedParcel = null;
      _fileName = null;
    });

    try {
      final Uint8List bytes = await file.readAsBytes();
      await _gmlService.parseGml(bytes);
      setState(() {
        _fileName = file.name;
      });
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Błąd wczytywania pliku przez drag&drop: $e');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Wystąpił błąd podczas parsowania pliku: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _fileName != null ? 'OperatFlow GML Viewer $_fileName' : 'OperatFlow GML Viewer',
        ),
        actions: <Widget>[
          if (_markedParcelIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Eksportuj zaznaczone działki (PDF)',
              onPressed: _exportMarkedParcelsPdf,
            ),
          if (_selectedParcel != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Drukuj dane działki',
              onPressed: _printSelectedParcel,
            ),
          if (_selectedParcel != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Eksportuj dane działki (PDF)',
              onPressed: _exportSelectedParcelPdf,
            ),
          IconButton(
            icon: const Icon(Icons.file_open),
            tooltip: 'Otwórz plik GML',
            onPressed: _pickAndParseGml,
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (_) {
          setState(() {
            _isDragging = false;
          });
        },
        onDragDone: _handleDrop,
        child: Stack(
          children: <Widget>[
            if (_isLoading)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Przetwarzanie pliku GML...'),
                  ],
                ),
              )
            else if (_gmlService.parcels.isEmpty)
              const Center(
                child: Text(
                  'Wybierz plik GML (kliknij ikonę folderu lub upuść plik w oknie), aby rozpocząć.',
                  style: TextStyle(fontSize: 18, color: Color(0xFF4B5B70)),
                  textAlign: TextAlign.center,
                ),
              )
            else
              _buildDesktopLayout(),
            if (_isDragging) _buildDropOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropOverlay() {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: primary.withOpacity(0.06),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.file_upload, size: 32, color: primary),
                  const SizedBox(height: 12),
                  const Text('Upuść swój plik GML tutaj', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    'Obsługiwane rozszerzenia: .gml, .xml',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4B5B70)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Działki', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          _gmlService.parcels.length.toString(),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4B5B70)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _buildParcelList()),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _selectedParcel == null
                ? Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Wybierz działkę z listy po lewej stronie.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4B5B70)),
                        ),
                      ),
                    ),
                  )
                : _buildDetailsView(_selectedParcel!),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelList() {
    return ListView.builder(
      itemCount: _gmlService.parcels.length,
      itemBuilder: (BuildContext context, int index) {
        final Parcel parcel = _gmlService.parcels[index];
        final bool isCurrent = _selectedParcel?.gmlId == parcel.gmlId;
        final bool isMarked = _markedParcelIds.contains(parcel.gmlId);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Material(
            color: isCurrent
                ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _selectedParcel = parcel;
                  _currentView = DetailView.dane;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        parcel.pelnyNumerDzialki,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Checkbox(
                      value: isMarked,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _markedParcelIds.add(parcel.gmlId);
                          } else {
                            _markedParcelIds.remove(parcel.gmlId);
                          }
                        });
                      },
                    ),
                    if (isCurrent)
                      Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsView(Parcel parcel) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SegmentedButton<DetailView>(
            segments: const <ButtonSegment<DetailView>>[
              ButtonSegment<DetailView>(
                value: DetailView.dane,
                label: Text('Dane działki'),
                icon: Icon(Icons.map),
              ),
              ButtonSegment<DetailView>(
                value: DetailView.podmioty,
                label: Text('Właściciele'),
                icon: Icon(Icons.people),
              ),
              ButtonSegment<DetailView>(
                value: DetailView.punkty,
                label: Text('Punkty graniczne'),
                icon: Icon(Icons.pin_drop),
              ),
            ],
            selected: <DetailView>{_currentView},
            onSelectionChanged: (Set<DetailView> newSelection) {
              setState(() {
                _currentView = newSelection.first;
              });
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: switch (_currentView) {
              DetailView.dane => _buildParcelDetails(parcel),
              DetailView.podmioty => _buildSubjectDetailsWithAddress(parcel),
              DetailView.punkty => _buildPointDetails(parcel),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParcelDetails(Parcel parcel) {
    final List<Address> parcelAddresses = _gmlService.getAddressesForParcel(parcel);
    final String adresNieruchomosci = parcelAddresses.isEmpty
        ? 'Brak danych adresowych.'
        : parcelAddresses.map(_formatAddress).join('\n');
    final String jednostkaLabel = parcel.jednostkaNazwa != null && parcel.jednostkaId != null
        ? '${_toAscii(parcel.jednostkaNazwa!)} [${parcel.jednostkaId}]'
        : parcel.jednostkaEwidencyjna;
    final String obrebCode = parcel.obrebId != null
        ? parcel.obrebId!.split('.').last
        : parcel.obreb;
    final String obrebLabel = parcel.obrebNazwa != null
        ? '${_toAscii(parcel.obrebNazwa!)} [$obrebCode]'
        : obrebCode;

    return Column(
      children: <Widget>[
        _buildSectionCard(
          title: 'Dane dzialki',
          children: <Widget>[
            _buildDetailRow('Jednostka:', jednostkaLabel),
            _buildDetailRow('Obreb:', obrebLabel),
            _buildDetailRow('Dzialka:', parcel.numerDzialki),
            _buildDetailRow('Numer KW:', parcel.numerKW ?? 'Brak'),
            _buildDetailRow('Pole ewidencyjne:', '${parcel.pole?.toString() ?? '?'} ha'),
            _buildDetailRow('Adres nieruchomosci', adresNieruchomosci),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Klasouzytki',
          children: parcel.uzytki.isEmpty
              ? <Widget>[_buildDetailRow('Brak', 'danych o uzytkach.')]
              : parcel.uzytki
                    .map(
                      (LandUse uzytek) => _buildDetailRow(
                        '${uzytek.ofu} (${uzytek.ozu})'
                            '${uzytek.ozk != null ? '/${uzytek.ozk}' : ''}:',
                        '${uzytek.powierzchnia?.toString() ?? '?'} ha',
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }

  Widget _buildSubjectDetailsWithAddress(Parcel parcel) {
    final List<MapEntry<OwnershipShare, Subject?>> subjectsWithShares = _gmlService
        .getSubjectsForParcel(parcel);

    return _buildSectionCard(
      title: 'Dane podmiotowe',
      children: subjectsWithShares.isEmpty
          ? <Widget>[_buildDetailRow('Brak', 'Powiązanych podmiotów')]
          : subjectsWithShares.map((MapEntry<OwnershipShare, Subject?> entry) {
              final OwnershipShare share = entry.key;
              final Subject? subject = entry.value;
              final List<Address> addresses = subject != null
                  ? _gmlService.getAddressesForSubject(subject)
                  : <Address>[];
              final String adresPodmiotu = addresses.isEmpty
                  ? 'Brak danych adresowych.'
                  : addresses.map(_formatAddress).join('\n');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildDetailRow('Podmiot:', subject?.name ?? 'Nieznany podmiot'),
                    _buildDetailRow('Rodzaj:', subject?.type ?? 'Brak'),
                    _buildDetailRow('Udzial:', share.share),
                    _buildDetailRow('Adres:', adresPodmiotu),
                  ],
                ),
              );
            }).toList(),
    );
  }

  Widget _buildSubjectDetails(Parcel parcel) {
    final List<MapEntry<OwnershipShare, Subject?>> subjectsWithShares = _gmlService
        .getSubjectsForParcel(parcel);
    return _buildSectionCard(
      title: 'Dane podmiotowe',
      children: subjectsWithShares.isEmpty
          ? <Widget>[_buildDetailRow('Brak', 'Powiązanych podmiotów')]
          : subjectsWithShares.map((MapEntry<OwnershipShare, Subject?> entry) {
              final OwnershipShare share = entry.key;
              final Subject? subject = entry.value;
              final List<Address> addresses = subject != null
                  ? _gmlService.getAddressesForSubject(subject)
                  : <Address>[];
              final String adresPodmiotu = addresses.isEmpty
                  ? 'Brak danych adresowych.'
                  : addresses.map(_formatAddress).join('\n');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildDetailRow('Podmiot:', subject?.name ?? 'Nieznany podmiot'),
                    _buildDetailRow('Rodzaj:', subject?.type ?? 'Brak'),
                    _buildDetailRow('Udzial:', share.share),
                  ],
                ),
              );
            }).toList(),
    );
  }

  Widget _buildPointDetails(Parcel parcel) {
    final List<BoundaryPoint> points = _gmlService.getPointsForParcel(parcel);
    return _buildSectionCard(
      title: 'Punkty graniczne (${points.length})',
      children: <Widget>[
        if (points.isEmpty)
          _buildDetailRow('Brak', 'danych o punktach granicznych.')
        else
          SizedBox(
            width: double.infinity,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('Numer')),
                DataColumn(label: Text('X')),
                DataColumn(label: Text('Y')),
                DataColumn(label: Text('ISD')),
                DataColumn(label: Text('STB')),
                DataColumn(label: Text('SPD')),
                DataColumn(label: Text('Operat')),
              ],
              rows: points.map((BoundaryPoint p) {
                return DataRow(
                  cells: <DataCell>[
                    DataCell(SelectableText(p.numer ?? '-')),
                    DataCell(SelectableText(p.x ?? '-')),
                    DataCell(SelectableText(p.y ?? '-')),
                    DataCell(SelectableText(p.isd ?? '-')),
                    DataCell(SelectableText(p.stb ?? '-')),
                    DataCell(SelectableText(p.spd ?? '-')),
                    DataCell(SelectableText(p.operat ?? '-')),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText(
            '$title ',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(child: SelectableText(value, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
