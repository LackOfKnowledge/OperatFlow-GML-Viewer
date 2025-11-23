import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/parcel.dart';
import '../../data/teryt_data.dart';
import '../../services/company_defaults_service.dart';
import '../../services/gml_service.dart';
import '../../services/notification_service.dart';

class NotificationFormPage extends StatefulWidget {
  final List<Parcel> parcels;
  final GmlService gmlService;

  const NotificationFormPage({
    super.key,
    required this.parcels,
    required this.gmlService,
  });

  @override
  State<NotificationFormPage> createState() => _NotificationFormPageState();
}

class _NotificationFormPageState extends State<NotificationFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final NotificationService _notificationService;
  final CompanyDefaultsService _defaultsService = CompanyDefaultsService();

  String _notificationType = 'Wznowienie granic';
  final _kergController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _surveyorNameController = TextEditingController();
  final _surveyorLicenseController = TextEditingController();
  final _placeController = TextEditingController();
  final _meetingPlaceController = TextEditingController();
  final _senderCompanyController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderAddress1Controller = TextEditingController();
  final _senderAddress2Controller = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientAddress1Controller = TextEditingController();
  final _recipientAddress2Controller = TextEditingController();
  final _rodoAdministratorController = TextEditingController();
  final _rodoContactController = TextEditingController();
  String? _selectedPowiatCode;
  Parcel? _subjectParcel;

  static const String _defaultsJson = '''
{
  "company": "ZENIT Usługi Geodezyjne",
  "address1": "ul. Poznańska 1A",
  "address2": "76-200 Słupsk",
  "nip": "0000000000",
  "surveyorName": "Jan Kowalski",
  "surveyorLicense": "20093",
  "place": "Słupsk"
}
''';

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(widget.gmlService);
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _timeController.text = '10:00';
    _placeController.text = 'Słupsk';
    _meetingPlaceController.text = 'Słupsk';
    if (widget.parcels.isNotEmpty) {
      _subjectParcel = widget.parcels.first;
    }
    _loadSavedDefaults();
  }

  @override
  void dispose() {
    _kergController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _surveyorNameController.dispose();
    _surveyorLicenseController.dispose();
    _placeController.dispose();
    _meetingPlaceController.dispose();
    _senderCompanyController.dispose();
    _senderNameController.dispose();
    _senderAddress1Controller.dispose();
    _senderAddress2Controller.dispose();
    _senderPhoneController.dispose();
    _recipientNameController.dispose();
    _recipientAddress1Controller.dispose();
    _recipientAddress2Controller.dispose();
    _rodoAdministratorController.dispose();
    _rodoContactController.dispose();
    super.dispose();
  }

  void _applyDefaults() {
    try {
      final defaults = jsonDecode(_defaultsJson) as Map<String, dynamic>;
      _surveyorNameController.text =
          defaults['surveyorName']?.toString() ?? _surveyorNameController.text;
      _surveyorLicenseController.text =
          defaults['surveyorLicense']?.toString() ?? _surveyorLicenseController.text;
      _placeController.text = defaults['place']?.toString() ?? _placeController.text;
    } catch (_) {
      // pomijamy błędy parsowania domyślnych danych
    }
  }

  Future<void> _loadSavedDefaults() async {
    final saved = await _defaultsService.load();
    if (!mounted) return;
    setState(() {
      if (saved.surveyorName.isNotEmpty) {
        _surveyorNameController.text = saved.surveyorName;
      }
      if (saved.surveyorLicense.isNotEmpty) {
        _surveyorLicenseController.text = saved.surveyorLicense;
      }
      if (saved.defaultPlace.isNotEmpty) {
        _placeController.text = saved.defaultPlace;
      }
      if (saved.defaultMeetingPlace.isNotEmpty) {
        _meetingPlaceController.text = saved.defaultMeetingPlace;
      }
      _senderCompanyController.text = saved.senderCompany;
      _senderNameController.text = saved.senderName;
      _senderAddress1Controller.text = saved.senderAddressLine1;
      _senderAddress2Controller.text = saved.senderAddressLine2;
      _senderPhoneController.text = saved.senderPhone;
      _rodoAdministratorController.text = saved.rodoAdministrator;
      _rodoContactController.text = saved.rodoContact;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Stwórz zawiadomienia'),
          TextButton.icon(
            onPressed: _openDefaultsEditor,
            icon: const Icon(Icons.settings_suggest),
            label: const Text('Dane firmy'),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _notificationType,
                  decoration: const InputDecoration(
                    labelText: 'Rodzaj zawiadomienia',
                  ),
                  items: const [
                    'Wznowienie granic',
                    'Ustalenie granic',
                    'Rozgraniczenie',
                  ]
                      .map(
                        (label) => DropdownMenuItem(
                          value: label,
                          child: Text(label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _notificationType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Parcel>(
                  value: _subjectParcel,
                  decoration: const InputDecoration(
                    labelText: 'Działka przedmiotowa',
                  ),
                  items: widget.parcels
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.pelnyNumerDzialki),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _subjectParcel = value),
                  validator: (val) => val == null ? 'Wybierz działkę przedmiotową' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _selectedPowiatCode,
                  decoration: const InputDecoration(
                    labelText: 'Powiat (opcjonalnie nadpisz)',
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Automatycznie z TERYT'),
                    ),
                    ...powiaty.entries.map(
                      (e) => DropdownMenuItem<String?>(
                        value: e.key,
                        child: Text('${e.value} (${e.key})'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedPowiatCode = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _kergController,
                  decoration: const InputDecoration(labelText: 'KERG pracy'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: 'Data czynności',
                        ),
                        readOnly: true,
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _selectedDate = pickedDate;
                              _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _timeController,
                        decoration: const InputDecoration(labelText: 'Godzina'),
                        readOnly: true,
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedDate),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _timeController.text = pickedTime.format(context);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _placeController,
                  decoration: const InputDecoration(
                    labelText: 'Miejscowość (dokument)',
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
                ),
                TextFormField(
                  controller: _meetingPlaceController,
                  decoration: const InputDecoration(
                    labelText: 'Miejsce spotkania',
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
                ),
                TextFormField(
                  controller: _surveyorNameController,
                  decoration: const InputDecoration(
                    labelText: 'Imię i nazwisko geodety',
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
                ),
                TextFormField(
                  controller: _surveyorLicenseController,
                  decoration: const InputDecoration(
                    labelText: 'Numer uprawnień geodety',
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _applyDefaults,
                    icon: const Icon(Icons.download_done),
                    label: const Text('Wstaw dane firmowe (domyślne)'),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInstructionSection(),
                const SizedBox(height: 16),
                _buildSenderRecipientSection(),
                const SizedBox(height: 16),
                _buildRodoSection(),
              ],
            ),
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
            if (_formKey.currentState!.validate()) {
              final timeParts = _timeController.text.split(':');
              final hour = int.tryParse(timeParts.first) ?? 0;
              final minute = int.tryParse(timeParts.length > 1 ? timeParts[1].replaceAll(RegExp(r'\\D'), '') : '0') ?? 0;
              final finalDate = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                hour,
                minute,
              );

              if (_subjectParcel != null) {
                final reordered = [
                  _subjectParcel!,
                  ...widget.parcels.where((p) => p != _subjectParcel),
                ];

                _notificationService.generateNotifications(
                  parcels: reordered,
                  notificationType: _notificationType,
                  kergId: _kergController.text,
                  date: finalDate,
                  surveyorName: _surveyorNameController.text,
                  surveyorLicense: _surveyorLicenseController.text,
                  place: _placeController.text,
                  meetingPlace: _meetingPlaceController.text,
                  senderCompany: _senderCompanyController.text,
                  senderName: _senderNameController.text,
                  senderAddressLine1: _senderAddress1Controller.text,
                  senderAddressLine2: _senderAddress2Controller.text,
                  senderPhone: _senderPhoneController.text,
                  recipientName: _recipientNameController.text,
                  recipientAddressLine1: _recipientAddress1Controller.text,
                  recipientAddressLine2: _recipientAddress2Controller.text,
                  rodoAdministrator: _rodoAdministratorController.text,
                  rodoContact: _rodoContactController.text,
                  powiatManual: _selectedPowiatCode != null ? powiaty[_selectedPowiatCode] : null,
                );
              }
              Navigator.of(context).pop();
            }
          },
          child: const Text('Generuj'),
        ),
      ],
    );
  }

  Widget _buildInstructionSection() {
    return ExpansionTile(
      title: const Text('Pouczenia i klauzule', style: TextStyle(fontSize: 14)),
      children: const [
        SizedBox(height: 8),
        Text(
          'Pouczenie:\n'
          '1. Nieusprawiedliwione niestawiennictwo stron nie wstrzymuje czynności geodety.\n'
          '2. W przypadku niemożności osobistego stawiennictwa strona może wyznaczyć pełnomocnika na podstawie pisemnego pełnomocnictwa.\n'
          '3. Strony i pełnomocnicy proszeni są o posiadanie dokumentu tożsamości.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        SizedBox(height: 16),
        Text(
          'Klauzula informacyjna RODO:\n'
          'Zgodnie z art. 13 ust. 1 i 2 RODO informuję, że administratorem Pani/Pana danych osobowych jest...',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSenderRecipientSection() {
    return ExpansionTile(
      title: const Text('Nadawca / Adresat', style: TextStyle(fontSize: 14)),
      children: [
        TextFormField(
          controller: _senderCompanyController,
          decoration: const InputDecoration(labelText: 'Firma (nadawca)'),
        ),
        TextFormField(
          controller: _senderNameController,
          decoration: const InputDecoration(
            labelText: 'Imię i nazwisko (nadawca)',
          ),
        ),
        TextFormField(
          controller: _senderAddress1Controller,
          decoration: const InputDecoration(
            labelText: 'Adres linia 1 (nadawca)',
          ),
        ),
        TextFormField(
          controller: _senderAddress2Controller,
          decoration: const InputDecoration(
            labelText: 'Adres linia 2 (nadawca)',
          ),
        ),
        TextFormField(
          controller: _senderPhoneController,
          decoration: const InputDecoration(labelText: 'Telefon (nadawca)'),
        ),
        const Divider(height: 24),
        TextFormField(
          controller: _recipientNameController,
          decoration: const InputDecoration(
            labelText: 'Adresat - imię i nazwisko',
          ),
        ),
        TextFormField(
          controller: _recipientAddress1Controller,
          decoration: const InputDecoration(
            labelText: 'Adresat - adres linia 1',
          ),
        ),
        TextFormField(
          controller: _recipientAddress2Controller,
          decoration: const InputDecoration(
            labelText: 'Adresat - adres linia 2',
          ),
        ),
      ],
    );
  }

  Widget _buildRodoSection() {
    return ExpansionTile(
      title: const Text('RODO', style: TextStyle(fontSize: 14)),
      children: [
        TextFormField(
          controller: _rodoAdministratorController,
          decoration: const InputDecoration(labelText: 'Administrator danych'),
        ),
        TextFormField(
          controller: _rodoContactController,
          decoration: const InputDecoration(labelText: 'Kontakt IOD'),
        ),
      ],
    );
  }

  Future<void> _openDefaultsEditor() async {
    final current = await _defaultsService.load();
    if (!mounted) return;
    final working = CompanyDefaults(
      senderCompany: _senderCompanyController.text.isNotEmpty ? _senderCompanyController.text : current.senderCompany,
      senderName: _senderNameController.text.isNotEmpty ? _senderNameController.text : current.senderName,
      senderAddressLine1: _senderAddress1Controller.text.isNotEmpty ? _senderAddress1Controller.text : current.senderAddressLine1,
      senderAddressLine2: _senderAddress2Controller.text.isNotEmpty ? _senderAddress2Controller.text : current.senderAddressLine2,
      senderPhone: _senderPhoneController.text.isNotEmpty ? _senderPhoneController.text : current.senderPhone,
      surveyorName: _surveyorNameController.text.isNotEmpty ? _surveyorNameController.text : current.surveyorName,
      surveyorLicense: _surveyorLicenseController.text.isNotEmpty ? _surveyorLicenseController.text : current.surveyorLicense,
      defaultPlace: _placeController.text.isNotEmpty ? _placeController.text : current.defaultPlace,
      defaultMeetingPlace: _meetingPlaceController.text.isNotEmpty ? _meetingPlaceController.text : current.defaultMeetingPlace,
      rodoAdministrator: _rodoAdministratorController.text.isNotEmpty ? _rodoAdministratorController.text : current.rodoAdministrator,
      rodoContact: _rodoContactController.text.isNotEmpty ? _rodoContactController.text : current.rodoContact,
    );

    final controllers = {
      'company': TextEditingController(text: working.senderCompany),
      'name': TextEditingController(text: working.senderName),
      'addr1': TextEditingController(text: working.senderAddressLine1),
      'addr2': TextEditingController(text: working.senderAddressLine2),
      'phone': TextEditingController(text: working.senderPhone),
      'surveyor': TextEditingController(text: working.surveyorName),
      'license': TextEditingController(text: working.surveyorLicense),
      'place': TextEditingController(text: working.defaultPlace),
      'meeting': TextEditingController(text: working.defaultMeetingPlace),
      'rodoAdmin': TextEditingController(text: working.rodoAdministrator),
      'rodoContact': TextEditingController(text: working.rodoContact),
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
                    decoration: const InputDecoration(
                      labelText: 'Imię i nazwisko (nadawca)',
                    ),
                  ),
                  TextField(
                    controller: controllers['addr1'],
                    decoration: const InputDecoration(
                      labelText: 'Adres linia 1',
                    ),
                  ),
                  TextField(
                    controller: controllers['addr2'],
                    decoration: const InputDecoration(
                      labelText: 'Adres linia 2',
                    ),
                  ),
                  TextField(
                    controller: controllers['phone'],
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                  const Divider(),
                  TextField(
                    controller: controllers['surveyor'],
                    decoration: const InputDecoration(
                      labelText: 'Geodeta uprawniony',
                    ),
                  ),
                  TextField(
                    controller: controllers['license'],
                    decoration: const InputDecoration(
                      labelText: 'Numer uprawnień',
                    ),
                  ),
                  TextField(
                    controller: controllers['place'],
                    decoration: const InputDecoration(
                      labelText: 'Miejscowość domyślna',
                    ),
                  ),
                  TextField(
                    controller: controllers['meeting'],
                    decoration: const InputDecoration(
                      labelText: 'Domyślne miejsce spotkania',
                    ),
                  ),
                  const Divider(),
                  TextField(
                    controller: controllers['rodoAdmin'],
                    decoration: const InputDecoration(
                      labelText: 'Administrator danych (RODO)',
                    ),
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
      setState(() {
        _senderCompanyController.text = result.senderCompany;
        _senderNameController.text = result.senderName;
        _senderAddress1Controller.text = result.senderAddressLine1;
        _senderAddress2Controller.text = result.senderAddressLine2;
        _senderPhoneController.text = result.senderPhone;
        _surveyorNameController.text = result.surveyorName;
        _surveyorLicenseController.text = result.surveyorLicense;
        _placeController.text = result.defaultPlace;
        _meetingPlaceController.text = result.defaultMeetingPlace;
        _rodoAdministratorController.text = result.rodoAdministrator;
        _rodoContactController.text = result.rodoContact;
      });
    }
  }
}
