import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'presentation/pages/home_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/local_storage.dart' as OfStorage;

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

  runApp(OperatFlowApp(initialFilePath: initialFilePath));
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
  StreamSubscription<AuthState>? _authSub;
  Session? _session;
  LicenseInfo? _license;
  bool _licenseLoading = false;
  bool _initializing = true;
  String? _licenseError;
  Timer? _logoutTimer;
  DateTime? _loginAt;

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
    final storedLogin = await OfStorage.LocalStorage.loadLoginTimestamp();
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
      if (mounted) setState(() => _license = fetched);
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
    await OfStorage.LocalStorage.clearSessionInfo();
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
    OfStorage.LocalStorage.saveLoginTimestamp(now);
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
      return LoginPage(onSignedIn: _handleSignedIn);
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
