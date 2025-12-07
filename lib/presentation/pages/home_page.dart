import 'dart:async';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_filex/open_filex.dart';
import 'package:gmlviewer/data/models/parcel.dart';
import '../../data/models/address.dart';
import '../../providers/gml_provider.dart';
import '../../repositories/gml_repository.dart';
import '../../services/auth_service.dart';
import '../../services/company_defaults_service.dart';
import '../../services/parcel_report_service.dart';
import '../theme/app_theme.dart';
import '../theme/widgets/parcel_geometry_preview.dart';
import '../theme/widgets/parcel_details_panel.dart';
import 'notification_form_page.dart';

class HomePage extends ConsumerStatefulWidget {
  final String? initialFilePath;
  final LicenseInfo? licenseInfo;
  final bool licenseLoading;
  final String? licenseError;
  final VoidCallback onSignOut;
  final VoidCallback? onRefreshLicense;
  final String userEmail;

  const HomePage({
    super.key,
    this.initialFilePath,
    required this.licenseInfo,
    required this.licenseLoading,
    required this.onSignOut,
    this.onRefreshLicense,
    this.licenseError,
    required this.userEmail,
  });

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final GmlRepository _gmlRepository;
  late final ParcelReportService _reportService;
  final CompanyDefaultsService _defaultsService = CompanyDefaultsService();
  
  List<Parcel> _selectedParcels = [];
  Parcel? _activeParcel;
  String? _fileName;
  bool _isDragging = false;
  ParcelDetailView _detailView = ParcelDetailView.parcel;
  
  StreamSubscription? _intentDataStreamSubscription;

  bool get _hasPaidAccess => widget.licenseInfo?.isActive ?? false;
  String get _licenseLabel =>
      widget.licenseInfo != null ? widget.licenseInfo!.label : 'Brak licencji';

  @override
  void initState() {
    super.initState();
    _gmlRepository = ref.read(gmlRepositoryProvider);
    _reportService = ParcelReportService(_gmlRepository);
    
    _initSharing();
  }

  void _initSharing() {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      if (widget.initialFilePath != null) {
        _loadFileFromPath(widget.initialFilePath!);
      }

      // _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> value) {
      //   if (value.isNotEmpty) {
      //     _loadFileFromPath(value.first.path);
      //   }
      // });
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFileFromPath(String path) async {
    if (!path.endsWith('.gml') && !path.endsWith('.xml')) {
      _showError('Nieprawidłowy format pliku. Proszę wybrać plik .gml lub .xml');
      return;
    }

    setState(() { 
      _selectedParcels.clear(); 
      _activeParcel = null; 
      _fileName = null;
    });

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      await ref.read(gmlStateProvider.notifier).loadFile(bytes);
      if (!mounted) return;
      setState(() { 
        _fileName = file.path.split(Platform.pathSeparator).last;
      });
    } catch (e) {
      if (mounted) _showError('Blad podczas parsowania pliku: $e');
    }
  }

  Future<void> _pickAndParseGml() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gml', 'xml'],
    );

    if (result != null && result.files.single.path != null) {
      await _loadFileFromPath(result.files.single.path!);
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDragging = false);
    if (details.files.isEmpty) return;
    await _loadFileFromPath(details.files.first.path);
  }

  Future<ParcelReportMode?> _askReportMode() async {
    return showDialog<ParcelReportMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Wybierz rodzaj raportu"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Dane dzialki (pelne)'),
              subtitle: const Text('Atrybuty, uzytki, wlasciciele, adresy, budynki/lokale, podstawy prawne'),
              onTap: () => Navigator.of(ctx).pop(ParcelReportMode.full),
            ),
            ListTile(
              title: const Text('Wypis graficzny'),
              subtitle: const Text('Geometria i punkty graniczne z atrybutami'),
              onTap: () => Navigator.of(ctx).pop(ParcelReportMode.graphic),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSelectedParcels() async {
    if (!_hasPaidAccess) {
      _showLicenseRequired();
      return;
    }

    if (_selectedParcels.isEmpty) return;
    final mode = await _askReportMode();
    if (mode == null) return;
    try {
      final pdfBytes = await _reportService.generatePdfBytes(_selectedParcels, mode: mode);
      final fileName = 'OperatFlow - Raport ' + mode.name + ' z ' + _selectedParcels.length.toString() + ' dzialek.pdf';
      
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Zapisz raport PDF',
        fileName: fileName,
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsBytes(pdfBytes);
        final finalPath = outputPath;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Raport zapisano w: ' + finalPath),
              action: SnackBarAction(
                label: 'Otworz',
                onPressed: () => OpenFilex.open(finalPath),
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Blad eksportu PDF: ' + e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showLicenseRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ta funkcja jest dostępna tylko z aktywną licencją.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _formatObreb(Parcel parcel) {
    final reg = RegExp(r'^\\d+_\\d\\.(\\d{4})');
    final match = reg.firstMatch(parcel.idDzialki);
    final obrebNumber = match != null ? match.group(1) : parcel.obrebId ?? '-';
    final name = parcel.obrebNazwa ?? '';
    if (name.isNotEmpty) {
      return '$name ${obrebNumber ?? ''}'.trim();
    }
    return obrebNumber ?? '-';
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
                  TextField(controller: controllers['company'], decoration: const InputDecoration(labelText: 'Firma')),
                  TextField(controller: controllers['name'], decoration: const InputDecoration(labelText: 'Imię i nazwisko (nadawca)')),
                  TextField(controller: controllers['addr1'], decoration: const InputDecoration(labelText: 'Adres linia 1')),
                  TextField(controller: controllers['addr2'], decoration: const InputDecoration(labelText: 'Adres linia 2')),
                  TextField(controller: controllers['phone'], decoration: const InputDecoration(labelText: 'Telefon')),
                  const Divider(),
                  TextField(controller: controllers['surveyor'], decoration: const InputDecoration(labelText: 'Geodeta uprawniony')),
                  TextField(controller: controllers['license'], decoration: const InputDecoration(labelText: 'Numer uprawnień')),
                  TextField(controller: controllers['place'], decoration: const InputDecoration(labelText: 'Miejscowość domyślna')),
                  TextField(controller: controllers['meeting'], decoration: const InputDecoration(labelText: 'Domyślne miejsce spotkania')),
                  const Divider(),
                  TextField(controller: controllers['rodoAdmin'], decoration: const InputDecoration(labelText: 'Administrator danych (RODO)')),
                  TextField(controller: controllers['rodoContact'], decoration: const InputDecoration(labelText: 'Kontakt IOD')),
                ].map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: e)).toList(),
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
    final gmlState = ref.watch(gmlStateProvider);
    final parcels = gmlState.value ?? <Parcel>[];
    final isParsing = gmlState.isLoading;
    final parseError = gmlState.hasError ? gmlState.error : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset('assets/logo.svg', height: 28),
            const SizedBox(width: 12),
            Text(_fileName != null ? ' - $_fileName' : 'GML Viewer'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.business_center_outlined),
            tooltip: 'Ustaw dane firmowe',
            onPressed: _openDefaultsEditor,
          ),
          if (_selectedParcels.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Eksportuj zaznaczone działki do PDF',
              onPressed: _exportSelectedParcels,
            ),
            IconButton(
              icon: const Icon(Icons.notification_add_outlined),
              tooltip: 'Stwórz zawiadomienia dla zaznaczonych działek',
              onPressed: () {
                if (!_hasPaidAccess) {
                  _showLicenseRequired();
                  return;
                }
                showDialog(
                  context: context,
                  builder: (_) => NotificationFormPage(
                    parcels: _selectedParcels,
                    gmlRepository: _gmlRepository,
                    isLicensed: _hasPaidAccess,
                    onLicenseBlocked: _showLicenseRequired,
                  ),
                );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: _pickAndParseGml,
            tooltip: 'Otwórz plik GML',
          ),
          PopupMenuButton<String>(
            tooltip: 'Konto',
            icon: const Icon(Icons.person_outline),
            onSelected: (value) {
              if (value == 'refresh') {
                widget.onRefreshLicense?.call();
              } else if (value == 'logout') {
                widget.onSignOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.userEmail.isEmpty ? 'Zalogowany użytkownik' : widget.userEmail,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Licencja: $_licenseLabel', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 8),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Text('Odśwież licencję'),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Wyloguj'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (widget.licenseLoading) const LinearProgressIndicator(minHeight: 2),
          _buildLicenseBanner(),
          Expanded(
            child: DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: _handleDrop,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isParsing)
                    const Center(child: CircularProgressIndicator())
                  else if (parseError != null)
                    _buildErrorState(parseError)
                  else if (parcels.isEmpty)
                    _buildEmptyState()
                  else
                    _buildContentLayout(parcels),
                    
                  if (_isDragging)
                    Container(
                      color: AppColors.info.withOpacity(0.1),
                      child: const Center(
                        child: Icon(Icons.cloud_upload_outlined, size: 100, color: AppColors.info),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseBanner() {
    final textTheme = Theme.of(context).textTheme;
    if (widget.licenseLoading && widget.licenseInfo == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.baseBackground,
        child: Row(
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Sprawdzam status licencji...',
              style: textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }

    if (_hasPaidAccess) {
      final label = widget.licenseInfo?.plan ?? _licenseLabel;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.baseBackground,
        child: Row(
          children: [
            const Icon(Icons.verified_outlined, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              'Licencja aktywna',
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.secondaryText)),
            const Spacer(),
            if (widget.onRefreshLicense != null)
              TextButton.icon(
                onPressed: widget.onRefreshLicense,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Odśwież'),
              ),
          ],
        ),
      );
    }

    final message = widget.licenseError ??
        'Brak aktywnej licencji. Dostęp tylko do podglądu danych GML.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.warning.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),
          if (widget.onRefreshLicense != null)
            TextButton(
              onPressed: widget.onRefreshLicense,
              child: const Text('Odśwież licencję'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 12),
          Text('Nie udało się przetworzyć pliku', style: textTheme.bodyMedium),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_outlined, size: 80, color: AppColors.border),
          const SizedBox(height: 24),
          Text('Witaj w OperatFlow', style: textTheme.headlineSmall?.copyWith(color: AppColors.secondaryText)),
          const SizedBox(height: 8),
          Text(
            'Upuść plik GML tutaj lub użyj przycisku w prawym górnym rogu.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.tertiaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildContentLayout(List<Parcel> parcels) {
    final activeParcel = parcels.contains(_activeParcel) ? _activeParcel : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 980;
        final listWidth = constraints.maxWidth < 720 ? constraints.maxWidth * 0.45 : 320.0;
        if (activeParcel == null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: listWidth,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.list_alt_outlined, size: 20, color: AppColors.secondaryText),
                            const SizedBox(width: 8),
                            Text(
                              'DZIALKI (${parcels.length})',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                    color: AppColors.secondaryText,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: _buildParcelList(parcels)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Wybierz dzialke, aby wyswietlic szczegoly',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
                  ),
                ),
              ),
            ],
          );
        }
        final detailPanel = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dzialka ${activeParcel!.numerDzialki}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Obreb: ${_formatObreb(activeParcel)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ParcelDetailView.values.map((v) {
                final selected = _detailView == v;
                final label = {
                  ParcelDetailView.parcel: 'Dzialka',
                  ParcelDetailView.parties: 'Podmioty, adresy i udzialy',
                  ParcelDetailView.points: 'Punkty graniczne',
                  ParcelDetailView.buildings: 'Budynki',
                }[v]!;
                return ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(label),
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _detailView = v),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_selectedParcels.isNotEmpty)
              Text(
                'Zaznaczone do raportu: ${_selectedParcels.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            ParcelDetailsPanel(
              parcel: activeParcel!,
              gmlRepository: _gmlRepository,
              view: _detailView,
            ),
          ],
        );
        final geometryPreview = ParcelGeometryPreview(parcel: activeParcel!, height: isStacked ? 240 : 200);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: listWidth,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.list_alt_outlined, size: 20, color: AppColors.secondaryText),
                          const SizedBox(width: 8),
                          Text(
                            'DZIALKI (${parcels.length})',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildParcelList(parcels)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: activeParcel == null
                  ? Center(
                      child: Text(
                        'Wybierz dzialke, aby wyswietlic szczegoly',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isStacked)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                detailPanel,
                                const SizedBox(height: 16),
                                geometryPreview,
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: detailPanel),
                                const SizedBox(width: 24),
                                Expanded(flex: 2, child: geometryPreview),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParcelList(List<Parcel> parcels) {
    return ListView.separated(
      itemCount: parcels.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final p = parcels[index];
        final isSelected = _selectedParcels.contains(p);
        final isActive = _activeParcel == p;
        return Material(
          color: isActive ? AppColors.info.withOpacity(0.08) : Colors.transparent,
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    if (!_selectedParcels.contains(p)) _selectedParcels.add(p);
                    _activeParcel ??= p;
                  } else {
                    _selectedParcels.remove(p);
                  }
                });
              },
            ),
            title: Text(
              p.numerDzialki,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal
              ),
            ),
            subtitle: Text('${p.pole ?? '-'} ha', style: Theme.of(context).textTheme.bodySmall),
            onTap: () => setState(() => _activeParcel = p),
          ),
        );
      },
    );
  }

  Widget _buildMainInfo(Parcel parcel) {
    final addresses = _gmlRepository.getAddressesForParcel(parcel);
    final addressStr = addresses.isNotEmpty ? addresses.map((a) => a.toSingleLine()).join('\n') : 'Brak danych';

    return _buildCard(
      title: 'Dane Ewidencyjne',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _buildRow('Identyfikator', parcel.idDzialki),
          _buildRow('Numer KW', parcel.numerKW ?? '-'),
          _buildRow('Powierzchnia', '${parcel.pole} ha'),
          _buildRow('Adres', addressStr),
          const Divider(height: 24),
          if (parcel.uzytki.isNotEmpty) ...[
             Align(
              alignment: Alignment.centerLeft, 
              child: Text(
                'Klasoużytki', 
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.secondaryText),
              )
            ),
             const SizedBox(height: 8),
             ...parcel.uzytki.map((u) {
                final parts = [u.ofu, u.ozu];
                if (u.ozk != null && u.ozk!.isNotEmpty) {
                  parts.add(u.ozk!);
                }
                final label = parts.where((s) => s != null && s.isNotEmpty && s != '?').join(' / ');
                return _buildRow(label.isEmpty ? '-' : label, '${u.powierzchnia ?? '-'} ha');
             }),
          ]
        ],
      ),
    );
  }

  Widget _buildOwnersSection(Parcel parcel) {
    final owners = _gmlRepository.getSubjectsForParcel(parcel);
    return _buildCard(
      title: 'Właściciele / Władający',
      icon: Icons.people_outline,
      child: owners.isEmpty 
        ? Text('Brak danych', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText))
        : Column(
            children: owners.map((e) {
              final subject = e.value;
              final addresses = subject != null ? _gmlRepository.getAddressesForSubject(subject) : <Address>[];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      label: Text(e.key.share),
                      labelStyle: Theme.of(context).textTheme.bodySmall,
                      backgroundColor: AppColors.baseBackground,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject?.name ?? 'Nieznany', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          Text(subject?.type ?? '-', style: Theme.of(context).textTheme.bodySmall),
                          if (addresses.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...addresses.map((a) => Text(a.toSingleLine(), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
                          ] else
                            Text('Brak adresu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.tertiaryText)),
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
    final points = _gmlRepository.getPointsForParcel(parcel);
    final textTheme = Theme.of(context).textTheme;

    return _buildCard(
      title: 'Punkty Graniczne',
      icon: Icons.gps_fixed,
      child: points.isEmpty
          ? Text('Brak danych o punktach', style: textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText))
          : SizedBox(
              width: double.infinity,
              child: DataTable(
                headingTextStyle: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                dataTextStyle: textTheme.bodySmall,
                columns: const [
                  DataColumn(label: Text('Numer')),
                  DataColumn(label: Text('X')),
                  DataColumn(label: Text('Y')),
                  DataColumn(label: Text('SPD')),
                  DataColumn(label: Text('ISD')),
                  DataColumn(label: Text('STB')),
                ],
                rows: points.map((p) => DataRow(cells: [
                  DataCell(Text(p.displayNumer, style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                  DataCell(Text(p.x ?? '-')),
                  DataCell(Text(p.y ?? '-')),
                  DataCell(Text(p.spd ?? '-')),
                  DataCell(Text(p.isd ?? '-')),
                  DataCell(Text(p.stb ?? '-')),
                ])).toList(),
              ),
            ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
               Icon(icon, color: AppColors.secondaryText), 
               const SizedBox(width: 12),
               Text(title.toUpperCase(), style: textTheme.bodySmall?.copyWith(
                 fontWeight: FontWeight.w600, 
                 letterSpacing: 1.1,
                 color: AppColors.secondaryText,
               ))
            ]),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
  
  Widget _buildRow(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText))),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

