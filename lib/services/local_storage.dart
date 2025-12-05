import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStorage {
  static const _credsFile = 'of_creds.json';
  static const _sessionFile = 'of_session.json';
  static const _xorKey = 'operatflow-key';

  static Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$name');
  }

  static String _xor(String input) {
    final key = _xorKey.codeUnits;
    final data = utf8.encode(input);
    final res = List<int>.generate(
      data.length,
      (i) => data[i] ^ key[i % key.length],
    );
    return base64.encode(res);
  }

  static String _xorDecode(String encoded) {
    final key = _xorKey.codeUnits;
    final data = base64.decode(encoded);
    final res = List<int>.generate(
      data.length,
      (i) => data[i] ^ key[i % key.length],
    );
    return utf8.decode(res);
  }

  static Future<void> saveCredentials(String email, String password) async {
    final file = await _file(_credsFile);
    final payload = {
      'email': _xor(email),
      'password': _xor(password),
    };
    await file.writeAsString(jsonEncode(payload));
  }

  static Future<Map<String, String>?> loadCredentials() async {
    try {
      final file = await _file(_credsFile);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return {
        'email': _xorDecode(data['email'] as String),
        'password': _xorDecode(data['password'] as String),
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCredentials() async {
    final file = await _file(_credsFile);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> saveLoginTimestamp(DateTime time) async {
    final file = await _file(_sessionFile);
    await file.writeAsString(jsonEncode({'loginAt': time.toIso8601String()}));
  }

  static Future<DateTime?> loadLoginTimestamp() async {
    try {
      final file = await _file(_sessionFile);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final ts = data['loginAt'] as String?;
      return ts != null ? DateTime.tryParse(ts) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSessionInfo() async {
    final file = await _file(_sessionFile);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
