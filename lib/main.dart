import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'presentation/pages/home_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/secure_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initialize();
  
  String? initialFilePath;
  
  // if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
  //   final List<SharedMediaFile> initialMedia = await ReceiveSharingIntent.getInitialMedia();
  //   if (initialMedia.isNotEmpty) {
  //     initialFilePath = initialMedia.first.path;
  //   }
  // }

  runApp(
    ProviderScope(
      child: OperatFlowApp(initialFilePath: initialFilePath),
    ),
  );
}

class OperatFlowApp extends StatelessWidget {
  final String? initialFilePath;
  const OperatFlowApp({super.key, this.initialFilePath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OperatFlow GML Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(initialFilePath: initialFilePath),
    );
  }
}

class AuthGate extends StatefulWidget {
  final String? initialFilePath;
  const AuthGate({super.key, this.initialFilePath});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  final SecureStorageService _secureStorage = SecureStorageService();
  StreamSubscription<AuthState>? _authSub;
  Session? _session;
  LicenseInfo? _license;
  bool _licenseLoading = false;
  bool _initializing = true;
  String? _licenseError;
  String? _sessionBlockMessage;
  Timer? _logoutTimer;
  DateTime? _loginAt;
  String? _deviceId;
  DateTime? _lastDeviceLockUpdate;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _authSub = _authService.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      setState(() {
        _session = session;
        _license = null;
        _licenseError = null;
        _sessionBlockMessage = null;
      });
      if (session != null) {
        _recordLoginTime();
        _loadLicense(session.user.id);
        _startLogoutTimer();
      }
    });
  }

  Future<void> _bootstrap() async {
    final currentSession = _authService.client.auth.currentSession;
    final storedLogin = await _secureStorage.getLoginTimestamp();
    _deviceId = await _secureStorage.getOrCreateDeviceId();
    setState(() {
      _session = currentSession;
      _loginAt = storedLogin;
    });

    if (currentSession != null) {
      if (_isSessionExpired()) {
        await _handleSignOut();
      } else {
        await _loadLicense(currentSession.user.id);
        _startLogoutTimer();
      }
    }

    if (mounted) {
      setState(() => _initializing = false);
    }
  }

  Future<void> _loadLicense(String userId) async {
    setState(() {
      _licenseLoading = true;
      _licenseError = null;
    });
    try {
      final fetched = await _authService.fetchLatestLicense(userId);
      if (mounted) {
        setState(() => _license = fetched);
      }
      if (fetched != null) {
        await _enforceDeviceLock(fetched);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _licenseError = 'Nie udało się pobrać danych licencji. Spróbuj ponownie.');
      }
    } finally {
      if (mounted) setState(() => _licenseLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    _logoutTimer?.cancel();
    _logoutTimer = null;
    await _secureStorage.clearSession();
    if (mounted) {
      setState(() {
        _license = null;
        _licenseError = null;
        _session = null;
        _loginAt = null;
      });
    }
  }

  Future<void> _handleSignedIn() async {
    final currentSession = _authService.client.auth.currentSession;
    if (mounted) setState(() => _session = currentSession);

    if (currentSession != null) {
      _recordLoginTime();
      _startLogoutTimer();
      await _loadLicense(currentSession.user.id);
    }
  }

  void _recordLoginTime() {
    final now = DateTime.now().toUtc();
    _loginAt = now;
    _secureStorage.saveLoginTimestamp(now);
  }

  Future<void> _enforceDeviceLock(LicenseInfo license) async {
    final plan = (license.plan ?? '').toLowerCase();
    // Enterprise: multi-device allowed.
    if (plan.contains('enterprise')) return;

    // Throttle updateUser to avoid rate limits.
    final now = DateTime.now().toUtc();
    if (_lastDeviceLockUpdate != null && now.difference(_lastDeviceLockUpdate!).inSeconds < 90) {
      return;
    }
    // Apply lock for lifetime / tester / pro (and any non-enterprise).
    final deviceId = _deviceId ?? await _secureStorage.getOrCreateDeviceId();
    final userResp = await _authService.client.auth.getUser();
    // Always prefer current device; overwrite stale metadata instead of logging out.

    try {
      await _authService.client.auth.updateUser(
        UserAttributes(data: {
          'active_device_id': deviceId,
          'active_device_platform': Platform.operatingSystem,
          'active_device_updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      _lastDeviceLockUpdate = now;
    } catch (e) {
      // Jeśli nie uda się zapisać blokady, nie blokujemy użytkownika, ale logujemy błąd.
      debugPrint('Device lock update failed: $e');
    }
  }

  bool _isSessionExpired() {
    if (_loginAt == null) return false;
    final now = DateTime.now().toUtc();
    return now.difference(_loginAt!).inHours >= 8;
  }

  void _startLogoutTimer() {
    _logoutTimer?.cancel();
    final now = DateTime.now().toUtc();
    final start = _loginAt ?? now;
    final remaining = Duration(hours: 8) - now.difference(start);
    final effective = remaining.isNegative ? Duration.zero : remaining;
    _logoutTimer = Timer(effective, () async {
      await _handleSignOut();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _logoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return LoginPage(onSignedIn: _handleSignedIn, initialMessage: _sessionBlockMessage);
    }

    return HomePage(
      initialFilePath: widget.initialFilePath,
      licenseInfo: _license,
      licenseError: _licenseError,
      licenseLoading: _licenseLoading,
      onSignOut: _handleSignOut,
      onRefreshLicense: () {
        final userId = _authService.client.auth.currentUser?.id;
        if (userId != null) {
          _loadLicense(userId);
        }
      },
      userEmail: _session?.user.email ?? '',
    );
  }
}
