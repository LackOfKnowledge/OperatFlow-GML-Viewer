import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../data/models/parcel.dart';
import '../../data/teryt_data.dart';
import '../../services/company_defaults_service.dart';
import '../../repositories/gml_repository.dart';
import '../../services/notification_service.dart';

class NotificationFormPage extends StatefulWidget {
  final List<Parcel> parcels;
  final GmlRepository gmlRepository;
  final bool isLicensed;
  final VoidCallback onLicenseBlocked;

  const NotificationFormPage({
    super.key,
    required this.parcels,
    required this.gmlRepository,
    required this.isLicensed,
    required this.onLicenseBlocked,
  });

  @override
  State<NotificationFormPage> createState() => _NotificationFormPageState();
}

class _NotificationFormPageState extends State<NotificationFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final NotificationService _notificationService;
  final CompanyDefaultsService _defaultsService = CompanyDefaultsService();

  // Common fields
  String _notificationType = 'Wznowienie granic';
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _placeController = TextEditingController();
  final _meetingPlaceController = TextEditingController();
  final _surveyorNameController = TextEditingController();
  final _surveyorLicenseController = TextEditingController();
  Parcel? _subjectParcel;
  String? _selectedPowiatCode;
  DateTime _selectedDate = DateTime.now();

  // Renewal specific
  final _kergController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _rodoContactController = TextEditingController();
  final _docSourceController = TextEditingController();

  // Demarcation specific
  final _caseNumberController = TextEditingController();
  final _decisionDateController = TextEditingController();
  final _decisionNumberController = TextEditingController();
  final _authorityNameController = TextEditingController();
  final _surveyorTitleController = TextEditingController();
  final _inspectorEmailController = TextEditingController();
  final _inspectorPhoneController = TextEditingController();
  final _companyRodoController = TextEditingController();
  final _senderEmailController = TextEditingController();
  String _authorityType = 'Wójta Gminy';
  DateTime _decisionSelectedDate = DateTime.now();
  // Akceptujemy pe‘'ny identyfikator EGB (WWPPGG_R.XXXX.NDZ[/...]) lub prosty numer dzia‘'ki (np. 60/5).
  final RegExp _parcelFullIdPattern = RegExp(r'^\d{4,}_\d{1,2}\.\d{1,4}\.\d+(?:/\d+)?$');
  final RegExp _parcelSimplePattern = RegExp(r'^\d+(?:[./]\d+)*$');
  final RegExp _kwPattern = RegExp(r'^[A-Z0-9]{3,4}/\d{8}/\d$');

  // Universal sender/company and recipient fields
  final _senderCompanyController = TextEditingController();
  final _senderAddress1Controller = TextEditingController();
  final _senderAddress2Controller = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientAddress1Controller = TextEditingController();
  final _recipientAddress2Controller = TextEditingController();
  final _rodoAdministratorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(widget.gmlRepository);
    final now = DateTime.now();
    _selectedDate = now;
    _decisionSelectedDate = now;
    _dateController.text = DateFormat('yyyy-MM-dd').format(now);
    _decisionDateController.text = DateFormat('yyyy-MM-dd').format(now);
    _timeController.text = '10:00';
    _placeController.text = 'Słupsk';
    
    if (widget.parcels.isNotEmpty) {
      _subjectParcel = widget.parcels.first;
      final place = widget.parcels.first.jednostkaNazwa;
      if (place != null) {
        _placeController.text = place;
        _meetingPlaceController.text = 'na gruncie dz. nr ${widget.parcels.first.numerDzialki}';
      }
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
    _docSourceController.dispose();
    _caseNumberController.dispose();
    _decisionDateController.dispose();
    _decisionNumberController.dispose();
    _authorityNameController.dispose();
    _surveyorTitleController.dispose();
    _inspectorEmailController.dispose();
    _inspectorPhoneController.dispose();
    _companyRodoController.dispose();
    _senderEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDefaults() async {
    final saved = await _defaultsService.load();
    if (!mounted) return;
    setState(() {
      _surveyorNameController.text = saved.surveyorName;
      _surveyorLicenseController.text = saved.surveyorLicense;
      if (saved.defaultPlace.isNotEmpty) _placeController.text = saved.defaultPlace;
      if (saved.defaultMeetingPlace.isNotEmpty) _meetingPlaceController.text = saved.defaultMeetingPlace;
      _senderCompanyController.text = saved.senderCompany;
      _senderNameController.text = saved.senderName;
      _senderAddress1Controller.text = saved.senderAddressLine1;
      _senderAddress2Controller.text = saved.senderAddressLine2;
      _senderPhoneController.text = saved.senderPhone;
      _senderEmailController.text = saved.senderEmail;
      _rodoAdministratorController.text = saved.rodoAdministrator;
      _rodoContactController.text = saved.rodoContact;
      _surveyorTitleController.text = saved.surveyorTitle;
      _companyRodoController.text = saved.companyRodo;
      _inspectorEmailController.text = saved.inspectorEmail;
      _inspectorPhoneController.text = saved.inspectorPhone;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDemarcation = _notificationType == 'Rozgraniczenie';

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
                if (isDemarcation) _buildDemarcationFields() else _buildRenewalFields(),
                const SizedBox(height: 12),
                _buildCommonFields(),
                const SizedBox(height: 16),
                _buildSenderRecipientSection(isDemarcation),
                const SizedBox(height: 16),
                _buildRodoSection(isDemarcation),
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
          onPressed: widget.isLicensed ? _generate : widget.onLicenseBlocked,
          child: const Text('Generuj'),
        ),
      ],
    );
  }

  void _generate() async {
    void showFormError(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    if (!widget.isLicensed) {
      widget.onLicenseBlocked();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    for (final parcel in widget.parcels) {
      final fullMatch = _parcelFullIdPattern.hasMatch(parcel.idDzialki);
      final simpleMatch = _parcelSimplePattern.hasMatch(parcel.numerDzialki);
      final isValid = fullMatch || simpleMatch;
      debugPrint(
        'Parcel check before generate -> id=${parcel.idDzialki} numer=${parcel.numerDzialki} '
        'fullMatch=$fullMatch simpleMatch=$simpleMatch valid=$isValid',
      );
      if (!isValid) {
        showFormError('Niepoprawny numer działki: ${parcel.numerDzialki}');
        return;
      }
      final kw = parcel.numerKW;
      if (kw != null && kw.isNotEmpty && !_kwPattern.hasMatch(kw)) {
        showFormError('Niepoprawny numer KW: $kw');
        return;
      }
    }

    final timeParts = _timeController.text.split(':');
    final hour = int.tryParse(timeParts.first) ?? 0;
    final minute =
        int.tryParse(timeParts.length > 1 ? timeParts[1].split(' ').first : '0') ??
            0;
    final finalDate = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);

    if (_subjectParcel == null) return;
    final reorderedParcels = [
      _subjectParcel!,
      ...widget.parcels.where((p) => p != _subjectParcel)
    ];

    final buildContext = context;

    if (_notificationType == 'Rozgraniczenie') {
      await _notificationService.generateDemarcationNotification(
        parcels: reorderedParcels,
        caseNumber: _caseNumberController.text,
        creationDate: _selectedDate,
        meetingDate: finalDate,
        surveyorTitle: _surveyorTitleController.text,
        surveyorName: _surveyorNameController.text,
        surveyorLicense: _surveyorLicenseController.text,
        placeOfCreation: _placeController.text,
        meetingPlace: _meetingPlaceController.text,
        companyName: _senderCompanyController.text,
        companyAddressLine1: _senderAddress1Controller.text,
        companyAddressLine2: _senderAddress2Controller.text,
        companyPhone: _senderPhoneController.text,
        companyEmail: _senderEmailController.text,
        companyRodo: _companyRodoController.text,
        decisionDate: _decisionSelectedDate,
        decisionNumber: _decisionNumberController.text,
        authority: _authorityType,
        authorityName: _authorityNameController.text,
        inspectorEmail: _inspectorEmailController.text,
        inspectorPhone: _inspectorPhoneController.text,
        powiatManual:
            _selectedPowiatCode != null ? powiaty[_selectedPowiatCode] : null,
        recipientName: _recipientNameController.text,
        recipientAddressLine1: _recipientAddress1Controller.text,
        recipientAddressLine2: _recipientAddress2Controller.text,
      );
    } else {
      await _notificationService.generateRenewalNotification(
        parcels: reorderedParcels,
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
        powiatManual:
            _selectedPowiatCode != null ? powiaty[_selectedPowiatCode] : null,
      );
    }
    
    if (!buildContext.mounted) return;

    final bool? printProtocol = await showDialog<bool>(
      context: buildContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Drukować protokół?'),
          content: const Text('Czy chcesz teraz wygenerować i wydrukować protokół?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Nie, zakończ'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Tak'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (printProtocol == true) {
      if (_notificationType == 'Rozgraniczenie') {
        _notificationService.generateDemarcationProtocol(
          parcels: reorderedParcels,
          caseNumber: _caseNumberController.text,
          date: finalDate,
          place: _placeController.text,
          surveyorName: _surveyorNameController.text,
          surveyorLicense: _surveyorLicenseController.text,
          companyName: _senderCompanyController.text,
          authorityName: _authorityNameController.text,
          decisionNumber: _decisionNumberController.text,
          decisionDate: _decisionSelectedDate,
        );
      } else if (_notificationType == 'Ustalenie granic') {
        _notificationService.generateDeterminationProtocol(
          parcels: reorderedParcels,
          kergId: _kergController.text,
          date: finalDate,
          place: _placeController.text,
          surveyorName: _surveyorNameController.text,
          surveyorLicense: _surveyorLicenseController.text,
          companyName: _senderCompanyController.text,
        );
      } else {
        _notificationService.generateRenewalProtocol(
            parcels: reorderedParcels,
            kergId: _kergController.text,
            date: finalDate,
            docSource: _docSourceController.text,
            surveyorName: _surveyorNameController.text,
            surveyorLicense: _surveyorLicenseController.text);
      }
    } else {
      Navigator.of(buildContext).pop();
    }
  }
  Widget _buildDemarcationFields() {
    return Column(
      children: [
        TextFormField(
          controller: _caseNumberController,
          decoration: const InputDecoration(labelText: 'Znak sprawy'),
          validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _decisionNumberController,
          decoration: const InputDecoration(labelText: 'Numer postanowienia'),
          validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _decisionDateController,
          decoration: const InputDecoration(labelText: 'Data postanowienia'),
          readOnly: true,
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: _decisionSelectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (pickedDate != null) {
              setState(() {
                _decisionSelectedDate = pickedDate;
                _decisionDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
              });
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _authorityType,
                decoration: const InputDecoration(labelText: 'Organ'),
                items: const ['Wójta Gminy', 'Burmistrza Miasta', 'Prezydenta Miasta']
                    .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _authorityType = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _authorityNameController,
                decoration: const InputDecoration(labelText: 'Nazwa miejscowości organu'),
                validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRenewalFields() {
    return Column(
      children: [
        TextFormField(
          controller: _kergController,
          decoration: const InputDecoration(labelText: 'KERG pracy'),
          validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _docSourceController,
          decoration: const InputDecoration(labelText: 'Dokumenty źródłowe (do protokołu)'),
          validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
        ),
      ],
    );
  }

  Widget _buildCommonFields() {
    return Column(
      children: [
        DropdownButtonFormField<Parcel>(
          value: _subjectParcel,
          decoration: const InputDecoration(labelText: 'Działka przedmiotowa'),
          items: widget.parcels.map((p) => DropdownMenuItem(value: p, child: Text(p.numerDzialki))).toList(),
          onChanged: (value) => setState(() => _subjectParcel = value),
          validator: (val) {
            if (val == null) return 'Wybierz działkę przedmiotową';
            final id = val.idDzialki;
            final numer = val.numerDzialki;
            final fullMatch = _parcelFullIdPattern.hasMatch(id);
            final simpleMatch = _parcelSimplePattern.hasMatch(numer);
            final isValid = fullMatch || simpleMatch;
            debugPrint('Parcel validator -> id=$id numer=$numer fullMatch=$fullMatch simpleMatch=$simpleMatch valid=$isValid');
            if (!isValid) return 'Niepoprawny numer działki (np. 221208_2.0026.60/5 lub 60/5)';
            final kw = val.numerKW;
            if (kw != null && kw.isNotEmpty && !_kwPattern.hasMatch(kw)) {
              return 'Niepoprawny numer KW (np. AB1C/00000000/0)';
            }
            return null;
          },
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
                    initialTime: TimeOfDay.fromDateTime(DateTime.now()),
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
        if (_notificationType == 'Rozgraniczenie') ... [
           const SizedBox(height: 12),
           TextFormField(
            controller: _surveyorTitleController,
            decoration: const InputDecoration(labelText: 'Tytuł zawodowy geodety (opcjonalnie)'),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _surveyorLicenseController,
          decoration: const InputDecoration(labelText: 'Numer uprawnień geodety'),
          validator: (value) => (value == null || value.isEmpty) ? 'Pole wymagane' : null,
        ),
      ],
    );
  }

  Widget _buildSenderRecipientSection(bool isDemarcation) {
    return ExpansionTile(
      title: Text('Nadawca / Adresat (dane domyślne)', style: Theme.of(context).textTheme.bodyMedium),
      initiallyExpanded: false,
      children: [
        TextFormField(controller: _senderCompanyController, decoration: const InputDecoration(labelText: 'Firma (nadawca)')),
        if (!isDemarcation)
          TextFormField(controller: _senderNameController, decoration: const InputDecoration(labelText: 'Imię i nazwisko (nadawca)')),
        TextFormField(controller: _senderAddress1Controller, decoration: const InputDecoration(labelText: 'Adres linia 1 (nadawca)')),
        TextFormField(controller: _senderAddress2Controller, decoration: const InputDecoration(labelText: 'Adres linia 2 (nadawca)')),
        TextFormField(controller: _senderPhoneController, decoration: const InputDecoration(labelText: 'Telefon (nadawca)')),
        if (isDemarcation)
          TextFormField(controller: _senderEmailController, decoration: const InputDecoration(labelText: 'Email (nadawca)')),
        const Divider(height: 24),
        const Text('Adresat jeśli brak w GML'),
        TextFormField(controller: _recipientNameController, decoration: const InputDecoration(labelText: 'Adresat - imię i nazwisko')),
        TextFormField(controller: _recipientAddress1Controller, decoration: const InputDecoration(labelText: 'Adresat - adres linia 1')),
        TextFormField(controller: _recipientAddress2Controller, decoration: const InputDecoration(labelText: 'Adresat - adres linia 2')),
      ].map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: e)).toList(),
    );
  }

  Widget _buildRodoSection(bool isDemarcation) {
    return ExpansionTile(
      title: Text('RODO (dane domyślne)', style: Theme.of(context).textTheme.bodyMedium),
      initiallyExpanded: false,
      children: [
        if (isDemarcation) ...[
          TextFormField(controller: _companyRodoController, decoration: const InputDecoration(labelText: 'Administrator danych (firma)'), validator: (v) => v!.isEmpty ? 'Wymagane': null,),
          TextFormField(controller: _inspectorEmailController, decoration: const InputDecoration(labelText: 'Email inspektora'), validator: (v) => v!.isEmpty ? 'Wymagane': null),
          TextFormField(controller: _inspectorPhoneController, decoration: const InputDecoration(labelText: 'Telefon inspektora'), validator: (v) => v!.isEmpty ? 'Wymagane': null),
        ] else ...[
          TextFormField(controller: _rodoAdministratorController, decoration: const InputDecoration(labelText: 'Administrator danych')),
          TextFormField(controller: _rodoContactController, decoration: const InputDecoration(labelText: 'Kontakt IOD')),
        ]
      ].map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: e)).toList(),
    );
  }
}
