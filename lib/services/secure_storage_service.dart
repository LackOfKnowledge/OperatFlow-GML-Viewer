import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';

/// Secure wrapper around platform keychains for persisting sensitive data.
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyEmail = 'user_email';
  static const _keyPassword = 'user_password';
  static const _keyToken = 'auth_token';
  static const _keyLoginAt = 'login_timestamp';
  static const _keyDeviceId = 'device_id';

  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<Map<String, String?>> getCredentials() async {
    try {
      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      return {'email': email, 'password': password};
    } catch (e) {
      // Corrupt store or access issue – return empty to let the app continue.
      return {'email': null, 'password': null};
    }
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
  }

  Future<void> saveSessionToken(String token) {
    return _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getSessionToken() {
    return _storage.read(key: _keyToken);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyLoginAt);
  }

  Future<void> saveLoginTimestamp(DateTime timestamp) {
    return _storage.write(key: _keyLoginAt, value: timestamp.toIso8601String());
  }

  Future<DateTime?> getLoginTimestamp() async {
    final value = await _storage.read(key: _keyLoginAt);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<String> getOrCreateDeviceId() async {
    try {
      final existing = await _storage.read(key: _keyDeviceId);
      if (existing != null && existing.isNotEmpty) return existing;
    } catch (_) {
      // Ignore corruption/locking; fall through to generate a new id.
    }

    final newId = _generateDeviceId();
    try {
      await _storage.write(key: _keyDeviceId, value: newId);
    } catch (_) {
      // Best-effort; still return the generated ID to continue.
    }
    return newId;
  }

  String _generateDeviceId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

}
