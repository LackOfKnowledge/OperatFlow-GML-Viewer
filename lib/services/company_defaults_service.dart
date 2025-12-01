import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CompanyDefaults {
  CompanyDefaults({
    this.senderCompany = '',
    this.senderName = '',
    this.senderAddressLine1 = '',
    this.senderAddressLine2 = '',
    this.senderPhone = '',
    this.senderEmail = '',
    this.surveyorName = '',
    this.surveyorLicense = '',
    this.surveyorTitle = '',
    this.defaultPlace = '',
    this.defaultMeetingPlace = '',
    this.rodoAdministrator = '',
    this.rodoContact = '',
    this.companyRodo = '',
    this.inspectorEmail = '',
    this.inspectorPhone = '',
  });

  String senderCompany;
  String senderName;
  String senderAddressLine1;
  String senderAddressLine2;
  String senderPhone;
  String senderEmail;
  String surveyorName;
  String surveyorLicense;
  String surveyorTitle;
  String defaultPlace;
  String defaultMeetingPlace;
  String rodoAdministrator;
  String rodoContact;
  String companyRodo;
  String inspectorEmail;
  String inspectorPhone;

  Map<String, dynamic> toJson() => {
        'senderCompany': senderCompany,
        'senderName': senderName,
        'senderAddressLine1': senderAddressLine1,
        'senderAddressLine2': senderAddressLine2,
        'senderPhone': senderPhone,
        'senderEmail': senderEmail,
        'surveyorName': surveyorName,
        'surveyorLicense': surveyorLicense,
        'surveyorTitle': surveyorTitle,
        'defaultPlace': defaultPlace,
        'defaultMeetingPlace': defaultMeetingPlace,
        'rodoAdministrator': rodoAdministrator,
        'rodoContact': rodoContact,
        'companyRodo': companyRodo,
        'inspectorEmail': inspectorEmail,
        'inspectorPhone': inspectorPhone,
      };

  factory CompanyDefaults.fromJson(Map<String, dynamic> json) => CompanyDefaults(
        senderCompany: json['senderCompany']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? '',
        senderAddressLine1: json['senderAddressLine1']?.toString() ?? '',
        senderAddressLine2: json['senderAddressLine2']?.toString() ?? '',
        senderPhone: json['senderPhone']?.toString() ?? '',
        senderEmail: json['senderEmail']?.toString() ?? '',
        surveyorName: json['surveyorName']?.toString() ?? '',
        surveyorLicense: json['surveyorLicense']?.toString() ?? '',
        surveyorTitle: json['surveyorTitle']?.toString() ?? '',
        defaultPlace: json['defaultPlace']?.toString() ?? '',
        defaultMeetingPlace: json['defaultMeetingPlace']?.toString() ?? '',
        rodoAdministrator: json['rodoAdministrator']?.toString() ?? '',
        rodoContact: json['rodoContact']?.toString() ?? '',
        companyRodo: json['companyRodo']?.toString() ?? '',
        inspectorEmail: json['inspectorEmail']?.toString() ?? '',
        inspectorPhone: json['inspectorPhone']?.toString() ?? '',
      );
}

class CompanyDefaultsService {
  static const String _fileName = 'company_defaults.json';

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<CompanyDefaults> load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return CompanyDefaults();
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return CompanyDefaults.fromJson(data);
    } catch (_) {
      return CompanyDefaults();
    }
  }

  Future<void> save(CompanyDefaults defaults) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(defaults.toJson()));
  }
}
