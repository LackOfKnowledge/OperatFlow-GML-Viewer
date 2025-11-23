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
    this.surveyorName = '',
    this.surveyorLicense = '',
    this.defaultPlace = '',
    this.defaultMeetingPlace = '',
    this.rodoAdministrator = '',
    this.rodoContact = '',
  });

  String senderCompany;
  String senderName;
  String senderAddressLine1;
  String senderAddressLine2;
  String senderPhone;
  String surveyorName;
  String surveyorLicense;
  String defaultPlace;
  String defaultMeetingPlace;
  String rodoAdministrator;
  String rodoContact;

  Map<String, dynamic> toJson() => {
        'senderCompany': senderCompany,
        'senderName': senderName,
        'senderAddressLine1': senderAddressLine1,
        'senderAddressLine2': senderAddressLine2,
        'senderPhone': senderPhone,
        'surveyorName': surveyorName,
        'surveyorLicense': surveyorLicense,
        'defaultPlace': defaultPlace,
        'defaultMeetingPlace': defaultMeetingPlace,
        'rodoAdministrator': rodoAdministrator,
        'rodoContact': rodoContact,
      };

  factory CompanyDefaults.fromJson(Map<String, dynamic> json) => CompanyDefaults(
        senderCompany: json['senderCompany']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? '',
        senderAddressLine1: json['senderAddressLine1']?.toString() ?? '',
        senderAddressLine2: json['senderAddressLine2']?.toString() ?? '',
        senderPhone: json['senderPhone']?.toString() ?? '',
        surveyorName: json['surveyorName']?.toString() ?? '',
        surveyorLicense: json['surveyorLicense']?.toString() ?? '',
        defaultPlace: json['defaultPlace']?.toString() ?? '',
        defaultMeetingPlace: json['defaultMeetingPlace']?.toString() ?? '',
        rodoAdministrator: json['rodoAdministrator']?.toString() ?? '',
        rodoContact: json['rodoContact']?.toString() ?? '',
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
