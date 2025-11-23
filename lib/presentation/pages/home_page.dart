import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../services/gml_service.dart';
import '../../services/parcel_report_service.dart'; // <-- Import serwisu raportów
import '../../data/models/parcel.dart';
import '../../data/models/address.dart';
import '../theme/widgets/parcel_geometry_preview.dart';
import '../pages/notification_form_page.dart';
import '../../services/company_defaults_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GmlService _gmlService = GmlService();
  late final ParcelReportService _reportService;
  final CompanyDefaultsService _defaultsService = CompanyDefaultsService();
  
  List<Parcel> _selectedParcels = [];
  Parcel? _activeParcel;
  bool _isLoading = false;
  String? _fileName;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _reportService = ParcelReportService(_gmlService);
  }

  Future<void> _pickAndParseGml() async {
    setState(() { 
      _isLoading = true; 
      _selectedParcels.clear(); 
      _activeParcel = null; 
      _fileName = null; 
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gml', 'xml'],
        withData: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final bytes = await File(path).readAsBytes();
        await _gmlService.parseGml(bytes);
        setState(() { _fileName = result.files.single.name; });
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) return;
    final file = details.files.first;
    if (!file.name.endsWith('.gml') && !file.name.endsWith('.xml')) return;

    setState(() { 
      _isLoading = true; 
      _selectedParcels.clear(); 
      _activeParcel = null; 
    });
    try {
      final bytes = await File(file.path).readAsBytes();
      await _gmlService.parseGml(bytes);
      setState(() { _fileName = file.name; });
    } catch (e) {
       if (mounted) _showError(e.toString());
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // --- Metody Raportowania ---
  
  Future<void> _printSelectedParcels() async {
    if (_selectedParcels.isEmpty) return;
    try {
      await _reportService.printParcels(_selectedParcels);
    } catch (e) {
      _showError('Błąd drukowania: $e');
    }
  }

  Future<void> _exportSelectedParcels() async {
    if (_selectedParcels.isEmpty) return;
    try {
      final pdfBytes = await _reportService.generatePdfBytes(_selectedParcels);
      final fileName = 'OperatFlow - Raport z ${_selectedParcels.length} działek.pdf';
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Zapisz raport PDF',
        fileName: fileName,
        bytes: pdfBytes,
      );

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Raport zapisano w: $result')),
        );
      }
    } catch (e) {
      _showError('Błąd eksportu PDF: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _openDefaultsEditor() async {
    final current = await _defaultsService.load();
    final controllers = {
      'company': TextEditingController(text: current.senderCompany),
      'name': TextEditingController(text: current.senderName),
      'addr1': TextEditingController(text: current.senderAddressLine1),
      'addr2': TextEditingController(text: current.senderAddressLine2),
      'phone': TextEditingController(text: current.senderPhone),
      'surveyor': TextEditingController(text: current.surveyorName),
      'license': TextEditingController(text: current.surveyorLicense),
      'place': TextEditingController(text: current.defaultPlace),
      'meeting': TextEditingController(text: current.defaultMeetingPlace),
      'rodoAdmin': TextEditingController(text: current.rodoAdministrator),
      'rodoContact': TextEditingController(text: current.rodoContact),
    };

    final result = await showDialog<CompanyDefaults>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dane firmy / geodety'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controllers['company'],
                    decoration: const InputDecoration(labelText: 'Firma'),
                  ),
                  TextField(
                    controller: controllers['name'],
                    decoration: const InputDecoration(labelText: 'Imię i nazwisko (nadawca)'),
                  ),
                  TextField(
                    controller: controllers['addr1'],
                    decoration: const InputDecoration(labelText: 'Adres linia 1'),
                  ),
                  TextField(
                    controller: controllers['addr2'],
                    decoration: const InputDecoration(labelText: 'Adres linia 2'),
                  ),
                  TextField(
                    controller: controllers['phone'],
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                  const Divider(),
                  TextField(
                    controller: controllers['surveyor'],
                    decoration: const InputDecoration(labelText: 'Geodeta uprawniony'),
                  ),
                  TextField(
                    controller: controllers['license'],
                    decoration: const InputDecoration(labelText: 'Numer uprawnień'),
                  ),
                  TextField(
                    controller: controllers['place'],
                    decoration: const InputDecoration(labelText: 'Miejscowość domyślna'),
                  ),
                  TextField(
                    controller: controllers['meeting'],
                    decoration: const InputDecoration(labelText: 'Domyślne miejsce spotkania'),
                  ),
                  const Divider(),
                  TextField(
                    controller: controllers['rodoAdmin'],
                    decoration: const InputDecoration(labelText: 'Administrator danych (RODO)'),
                  ),
                  TextField(
                    controller: controllers['rodoContact'],
                    decoration: const InputDecoration(labelText: 'Kontakt IOD'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(
                  CompanyDefaults(
                    senderCompany: controllers['company']!.text,
                    senderName: controllers['name']!.text,
                    senderAddressLine1: controllers['addr1']!.text,
                    senderAddressLine2: controllers['addr2']!.text,
                    senderPhone: controllers['phone']!.text,
                    surveyorName: controllers['surveyor']!.text,
                    surveyorLicense: controllers['license']!.text,
                    defaultPlace: controllers['place']!.text,
                    defaultMeetingPlace: controllers['meeting']!.text,
                    rodoAdministrator: controllers['rodoAdmin']!.text,
                    rodoContact: controllers['rodoContact']!.text,
                  ),
                );
              },
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _defaultsService.save(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dane firmowe zapisane')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName != null ? 'OperatFlow - $_fileName' : 'OperatFlow GML Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.business),
            tooltip: 'Ustaw dane firmowe',
            onPressed: _openDefaultsEditor,
          ),
          if (_selectedParcels.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Drukuj zaznaczone działki',
              onPressed: _printSelectedParcels,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Eksportuj zaznaczone działki do PDF',
              onPressed: _exportSelectedParcels,
            ),
            IconButton(
              icon: const Icon(Icons.notification_add),
              tooltip: 'Stwórz zawiadomienia dla zaznaczonych działek',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => NotificationFormPage(
                    parcels: _selectedParcels,
                    gmlService: _gmlService,
                  ),
                );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndParseGml,
            tooltip: 'Otwórz plik GML',
          )
        ],
      ),
      body: SelectableRegion(
        focusNode: FocusNode(),
        selectionControls: MaterialTextSelectionControls(),
        child: DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: _handleDrop,
          child: Stack(
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_gmlService.parcels.isEmpty)
                _buildEmptyState()
              else
                _buildContentLayout(),
                
              if (_isDragging)
                Container(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                  child: const Center(
                    child: Icon(Icons.cloud_upload, size: 100, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            'Witaj w OperatFlow',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Upuść plik GML tutaj lub użyj przycisku w prawym górnym rogu.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildContentLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEWA KOLUMNA (Lista)
        SizedBox(
          width: 320,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.list, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'DZIAŁKI (${_gmlService.parcels.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0),
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
        // PRAWA KOLUMNA (szczegóły)
        Expanded(
          child: _gmlService.parcels.isEmpty
              ? const Center(child: Text('Wybierz działkę z listy po lewej stronie'))
              : _activeParcel == null
                  ? const Center(child: Text('Kliknij działkę, aby wyświetlić szczegóły'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dzialka ${_activeParcel!.pelnyNumerDzialki}',
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Obreb: ${_activeParcel!.obrebNazwa ?? '-'} [${_activeParcel!.obrebId ?? '-'}]',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_selectedParcels.isNotEmpty)
                                      Text('Zaznaczone do raportu: ${_selectedParcels.length}', style: const TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 24),
                                    _buildMainInfo(_activeParcel!),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: ParcelGeometryPreview(parcel: _activeParcel!),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _buildOwnersSection(_activeParcel!),
                          const SizedBox(height: 32),
                          _buildPointsSection(_activeParcel!),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildParcelList() {
    return ListView.separated(
      itemCount: _gmlService.parcels.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final p = _gmlService.parcels[index];
        final isSelected = _selectedParcels.contains(p);
        final isActive = _activeParcel == p;
        return Material(
          color: isActive ? Colors.blue.shade50 : Colors.transparent,
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    if (!_selectedParcels.contains(p)) {
                      _selectedParcels.add(p);
                    }
                    _activeParcel ??= p;
                  } else {
                    _selectedParcels.remove(p);
                  }
                });
              },
            ),
            title: Text(
              p.pelnyNumerDzialki,
              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: Text('${p.pole ?? '-'} ha', style: const TextStyle(fontSize: 12)),
            onTap: () {
              setState(() {
                _activeParcel = p;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildMainInfo(Parcel parcel) {
    final p = parcel;
    final addresses = _gmlService.getAddressesForParcel(p);
    final addressStr = addresses.isNotEmpty ? addresses.map((a) => a.toSingleLine()).join('\n') : 'Brak danych';

    return _buildCard(
      title: 'Dane Ewidencyjne',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _buildRow('Identyfikator', p.idDzialki),
          _buildRow('Numer KW', p.numerKW ?? '-'),
          _buildRow('Powierzchnia', '${p.pole} ha'),
          _buildRow('Adres', addressStr),
          const Divider(height: 24),
          if (p.uzytki.isNotEmpty) ...[
             const Align(alignment: Alignment.centerLeft, child: Text('Klasouzytki', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
             const SizedBox(height: 8),
             ...p.uzytki.map((u) => _buildRow('${u.ofu} (${u.ozu})', '${u.powierzchnia} ha')),
          ]
        ],
      ),
    );
  }

  Widget _buildOwnersSection(Parcel parcel) {
    final owners = _gmlService.getSubjectsForParcel(parcel);
    return _buildCard(
      title: 'Wlasciciele',
      icon: Icons.people,
      child: owners.isEmpty 
        ? const Text('Brak danych')
        : Column(
            children: owners.map((e) {
              final subject = e.value;
              final addresses = subject != null ? _gmlService.getAddressesForSubject(subject) : <Address>[];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(label: Text(e.key.share, style: const TextStyle(fontSize: 10))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject?.name ?? 'Nieznany', style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text(subject?.type ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (addresses.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...addresses.map((a) => Text(a.toSingleLine(), style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic))),
                          ] else
                            const Text('Brak adresu', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList()
          ),
    );
  }

  Widget _buildPointsSection(Parcel parcel) {
    final points = _gmlService.getPointsForParcel(parcel);
    return _buildCard(
      title: 'Punkty Graniczne',
      icon: Icons.gps_fixed,
      child: points.isEmpty
          ? const Text('Brak punktow')
          : SizedBox(
              width: double.infinity,
              child: DataTable(
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                columns: const [
                  DataColumn(label: Text('Pelne ID')),
                  DataColumn(label: Text('Numer')),
                  DataColumn(label: Text('X')),
                  DataColumn(label: Text('Y')),
                  DataColumn(label: Text('SPD')),
                  DataColumn(label: Text('ISD')),
                  DataColumn(label: Text('STB')),
                  DataColumn(label: Text('Operat')),
                ],
                rows: points.map((p) => DataRow(cells: [
                  DataCell(Text(p.pelneId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text(p.displayNumer)),
                  DataCell(Text(p.x ?? '-')),
                  DataCell(Text(p.y ?? '-')),
                  DataCell(Text(p.spd ?? '-')),
                  DataCell(Text(p.isd ?? '-')),
                  DataCell(Text(p.stb ?? '-')),
                  DataCell(Text(p.operat ?? '-')),
                ])).toList(),
              ),
            ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
               Icon(icon, color: Theme.of(context).primaryColor), 
               const SizedBox(width: 8),
               Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            ]),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
  
  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

