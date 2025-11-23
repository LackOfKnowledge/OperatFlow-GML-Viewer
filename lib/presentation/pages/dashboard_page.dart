import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../services/gml_service.dart';
import '../../services/parcel_report_service.dart';
import '../../data/models/parcel.dart';
import '../../data/models/boundary_point.dart';
import '../../data/models/subject.dart';
import '../../data/models/ownership_share.dart';
import '../widgets/parcel_geometry_preview.dart';
import 'notification_form_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GmlService _gmlService = GmlService();
  late final ParcelReportService _reportService;
  final Set<Parcel> _selectedParcels = {};
  Parcel? _lastSelectedParcel;
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
      _lastSelectedParcel = null;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e')));
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
      _lastSelectedParcel = null;
    });
    try {
      final bytes = await File(file.path).readAsBytes();
      await _gmlService.parseGml(bytes);
      setState(() { _fileName = file.name; });
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _showPrintDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Wybierz rodzaj wydruku'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Informacje o działkach'),
                onTap: () {
                  Navigator.of(context).pop();
                  _printParcelInfo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.mail),
                title: const Text('Zawiadomienia'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showNotificationTypeDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _printParcelInfo() {
    if (_selectedParcels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie wybrano żadnych działek.')),
      );
      return;
    }
    _reportService.printParcels(_selectedParcels.toList());
  }

  void _showNotificationTypeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Wybierz rodzaj zawiadomienia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Wznowienie znaków granicznych'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showSubjectParcelDialog('Wznowienie');
                },
              ),
              ListTile(
                title: const Text('Ustalenie przebiegu granic'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showSubjectParcelDialog('Ustalenie');
                },
              ),
              ListTile(
                title: const Text('Rozgraniczenie nieruchomości'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showSubjectParcelDialog('Rozgraniczenie');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubjectParcelDialog(String notificationType) {
    if (_selectedParcels.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz co najmniej dwie działki (jedną przedmiotową i co najmniej jedną sąsiednią).')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Wybierz działkę przedmiotową'),
          children: _selectedParcels.map((parcel) {
            return SimpleDialogOption(
              onPressed: () {
                final subjectParcel = parcel;
                final neighborParcels = _selectedParcels.where((p) => p != subjectParcel).toList();
                Navigator.of(context).pop(); // Close the dialog
                
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NotificationFormPage(
                      notificationType: notificationType,
                      subjectParcel: subjectParcel,
                      neighborParcels: neighborParcels,
                      gmlService: _gmlService,
                    ),
                  ),
                );
              },
              child: Text(parcel.pelnyNumerDzialki),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Jasnoszare tło dashboardu
      appBar: AppBar(
        title: Text(_fileName != null ? 'OperatFlow - $_fileName' : 'OperatFlow GML Viewer'),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndParseGml,
            tooltip: 'Otwórz GML',
          )
        ],
      ),
      floatingActionButton: _selectedParcels.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showPrintDialog,
              label: Text('Drukuj (${_selectedParcels.length})'),
              icon: const Icon(Icons.print),
              backgroundColor: const Color(0xFF2C3E50),
              foregroundColor: Colors.white,
            ),
      body: DropTarget(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEWA KOLUMNA - LISTA
                  SizedBox(
                    width: 350,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(right: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.grey.shade50,
                            child: Row(
                              children: [
                                const Icon(Icons.list, size: 20, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'Działki (${_gmlService.parcels.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
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
                  // PRAWA KOLUMNA - SZCZEGÓŁY
                  Expanded(
                    child: _lastSelectedParcel == null
                        ? const Center(child: Text("Wybierz działkę z listy"))
                        : SelectionArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeader(),
                                  const SizedBox(height: 24),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 3, child: _buildMainInfo()),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 2, child: ParcelGeometryPreview(parcel: _lastSelectedParcel!)),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildOwnersSection(),
                                  const SizedBox(height: 24),
                                  _buildPointsSection(),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              
            if (_isDragging)
              Container(
                color: const Color(0xFF3498DB).withOpacity(0.2),
                child: const Center(
                  child: Icon(Icons.cloud_upload, size: 100, color: Color(0xFF3498DB)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Upuść plik GML tutaj\nlub kliknij ikonę folderu w rogu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _toggleParcelSelection(Parcel parcel) {
    setState(() {
      if (_selectedParcels.contains(parcel)) {
        _selectedParcels.remove(parcel);
        _lastSelectedParcel = _selectedParcels.isNotEmpty ? _selectedParcels.last : null;
      } else {
        _selectedParcels.add(parcel);
        _lastSelectedParcel = parcel;
      }
    });
  }

  Widget _buildParcelList() {
    return ListView.builder(
      itemCount: _gmlService.parcels.length,
      itemBuilder: (context, index) {
        final p = _gmlService.parcels[index];
        final isSelected = _selectedParcels.contains(p);
        return Material(
          color: isSelected ? const Color(0xFF3498DB).withOpacity(0.1) : Colors.transparent,
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                _toggleParcelSelection(p);
              },
              activeColor: const Color(0xFF3498DB),
            ),
            title: Text(
              p.pelnyNumerDzialki,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF2980B9) : Colors.black87,
              ),
            ),
            subtitle: Text('${p.pole ?? '-'} ha'),
            dense: true,
            onTap: null,
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2C3E50),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.landscape, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Działka ${_lastSelectedParcel!.pelnyNumerDzialki}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            Text(
              '${_lastSelectedParcel!.obrebNazwa ?? "Obręb nieznany"} [${_lastSelectedParcel!.obrebId ?? "-"}]',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainInfo() {
    final p = _lastSelectedParcel!;
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
          const Align(alignment: Alignment.centerLeft, child: Text("Użytki", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          const SizedBox(height: 8),
          ...p.uzytki.map((u) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                  child: Text(u.ofu, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                ),
                const SizedBox(width: 8),
                Text('${u.ozu} ${u.ozk != null ? "/ ${u.ozk}" : ""}'),
                const Spacer(),
                Text('${u.powierzchnia ?? "-"} ha'),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildOwnersSection() {
    final subjects = _gmlService.getSubjectsForParcel(_lastSelectedParcel!);
    return _buildCard(
      title: 'Właściciele / Władający',
      icon: Icons.people_outline,
      child: subjects.isEmpty 
          ? const Text("Brak danych o właścicielach")
          : Column(
              children: subjects.map((entry) {
                final share = entry.key;
                final subject = entry.value;

                if (subject == null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.red.shade50,
                          child: const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text("Brak danych o podmiocie dla udziału."),
                        ),
                      ],
                    ),
                  );
                }
                
                final addresses = _gmlService.getAddressesForSubject(subject);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.orange.shade50,
                        child: Text(share.share, style: const TextStyle(fontSize: 10, color: Colors.orange)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(subject.type, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            if (addresses.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              ...addresses.map((addr) => Padding(
                                padding: const EdgeInsets.only(left: 4.0, top: 2.0),
                                child: Text(
                                  '• ${addr.toSingleLine()}',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
                                ),
                              )),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPointsSection() {
    final points = _gmlService.getPointsForParcel(_lastSelectedParcel!);
    return _buildCard(
      title: 'Punkty Graniczne',
      icon: Icons.gps_fixed,
      child: points.isEmpty
          ? const Text("Brak punktów granicznych")
          : SizedBox(
              width: double.infinity,
              child: Theme(
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                  dataRowMinHeight: 20,
                  dataRowMaxHeight: 40,
                  columnSpacing: 20,
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
                  rows: points.map((p) {
                    return DataRow(cells: [
                      DataCell(Text(p.pelneId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DataCell(Text(p.displayNumer, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(p.x ?? '-', style: const TextStyle(fontSize: 12, fontFamily: 'Monospace'))),
                      DataCell(Text(p.y ?? '-', style: const TextStyle(fontSize: 12, fontFamily: 'Monospace'))),
                      DataCell(Text(p.spd ?? '-', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(p.isd ?? '-', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(p.stb ?? '-', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(p.operat ?? '-', style: const TextStyle(fontSize: 12))),
                    ]);
                  }).toList(),
                ),
              ),
              ),
            ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF3498DB), size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}