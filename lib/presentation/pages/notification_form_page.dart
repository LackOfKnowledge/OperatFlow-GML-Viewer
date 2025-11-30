import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gmlviewer/presentation/theme/app_theme.dart';
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

  Future<void> _loadSavedDefaults() async {
    final saved = await _defaultsService.load();
    if (!mounted) return;
    setState(() {
      if (saved.surveyorName.isNotEmpty) _surveyorNameController.text = saved.surveyorName;
      if (saved.surveyorLicense.isNotEmpty) _surveyorLicenseController.text = saved.surveyorLicense;
      if (saved.defaultPlace.isNotEmpty) _placeController.text = saved.defaultPlace;
      if (saved.defaultMeetingPlace.isNotEmpty) _meetingPlaceController.text = saved.defaultMeetingPlace;
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
          Text('Stwórz zawiadomienia', style: Theme.of(context).textTheme.titleLarge),
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
                  decoration: const InputDecoration(labelText: 'Rodzaj zawiadomienia'),
                  items: const ['Wznowienie granic', 'Ustalenie granic', 'Rozgraniczenie']
                      .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _notificationType = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Parcel>(
                  value: _subjectParcel,
                  decoration: const InputDecoration(labelText: 'Działka przedmiotowa'),
                  items: widget.parcels.map((p) => DropdownMenuItem(value: p, child: Text(p.numerDzialki))).toList(),
                  onChanged: (value) => setState(() => _subjectParcel = value),
                  validator: (val) => val == null ? 'Wybierz działkę przedmiotową' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _selectedPowiatCode,
                  decoration: const InputDecoration(labelText: 'Powiat (opcjonalnie nadpisz)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Automatycznie z TERYT')),
                    ...powiaty.entries.map(
                      (e) => DropdownMenuItem<String?>(value: e.key, child: Text('${e.value} (${e.key})')),
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
                        decoration: const InputDecoration(labelText: 'Data czynności'),
                        readOnly: true,
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
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
                            setState(() => _timeController.text = pickedTime.format(context));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _placeController,
                  decoration: const InputDecoration(labelText: 'Miejscowość (dokument)'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
                ),
                TextFormField(
                  controller: _meetingPlaceController,
                  decoration: const InputDecoration(labelText: 'Miejsce spotkania'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
                ),
                TextFormField(
                  controller: _surveyorNameController,
                  decoration: const InputDecoration(labelText: 'Imię i nazwisko geodety'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
                ),
                TextFormField(
                  controller: _surveyorLicenseController,
                  decoration: const InputDecoration(labelText: 'Numer uprawnień geodety'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
                ),
                const SizedBox(height: 16),
                _buildSenderRecipientSection(),
                const SizedBox(height: 16),
                _buildRodoSection(),
              ].map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: e)).toList(),
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
              final minute = int.tryParse(timeParts.length > 1 ? timeParts[1].split(' ').first : '0') ?? 0;
              final finalDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);

              if (_subjectParcel != null) {
                final reordered = [_subjectParcel!, ...widget.parcels.where((p) => p != _subjectParcel)];
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

  Widget _buildSenderRecipientSection() {
    return ExpansionTile(
      title: Text('Nadawca / Adresat', style: Theme.of(context).textTheme.bodyMedium),
      children: [
        TextFormField(controller: _senderCompanyController, decoration: const InputDecoration(labelText: 'Firma (nadawca)')),
        TextFormField(controller: _senderNameController, decoration: const InputDecoration(labelText: 'Imię i nazwisko (nadawca)')),
        TextFormField(controller: _senderAddress1Controller, decoration: const InputDecoration(labelText: 'Adres linia 1 (nadawca)')),
        TextFormField(controller: _senderAddress2Controller, decoration: const InputDecoration(labelText: 'Adres linia 2 (nadawca)')),
        TextFormField(controller: _senderPhoneController, decoration: const InputDecoration(labelText: 'Telefon (nadawca)')),
        const Divider(height: 24),
        TextFormField(controller: _recipientNameController, decoration: const InputDecoration(labelText: 'Adresat - imię i nazwisko')),
        TextFormField(controller: _recipientAddress1Controller, decoration: const InputDecoration(labelText: 'Adresat - adres linia 1')),
        TextFormField(controller: _recipientAddress2Controller, decoration: const InputDecoration(labelText: 'Adresat - adres linia 2')),
      ].map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: e)).toList(),
    );
  }

  Widget _buildRodoSection() {
    return ExpansionTile(
      title: Text('RODO', style: Theme.of(context).textTheme.bodyMedium),
      children: [
        TextFormField(controller: _rodoAdministratorController, decoration: const InputDecoration(labelText: 'Administrator danych')),
        TextFormField(controller: _rodoContactController, decoration: const InputDecoration(labelText: 'Kontakt IOD')),
      ].map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: e)).toList(),
    );
  }
}
