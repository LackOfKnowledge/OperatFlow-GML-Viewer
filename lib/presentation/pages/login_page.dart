import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/secure_storage_service.dart';
import '../theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  final Future<void> Function() onSignedIn;
  final String? initialMessage;

  const LoginPage({super.key, required this.onSignedIn, this.initialMessage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final SecureStorageService _secureStorage = SecureStorageService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberMe = false;
   bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _prefillSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _prefillSavedCredentials() async {
    final creds = await _secureStorage.getCredentials();
    if (creds['email'] != null || creds['password'] != null) {
      setState(() {
        _emailController.text = creds['email'] ?? '';
        _passwordController.text = creds['password'] ?? '';
        _rememberMe = true;
      });
    }
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Jeśli była poprzednia sesja, zamknij ją przed nowym logowaniem (tylko raz).
      if (_authService.client.auth.currentSession != null) {
        await _authService.signOut();
        await _secureStorage.clearSession();
      }
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (_rememberMe) {
        await _secureStorage.saveCredentials(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _secureStorage.clearCredentials();
      }
      await widget.onSignedIn();
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Logowanie nie powiodlo sie. Sprobuj ponownie.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openRegister() async {
    const url = 'https://operatflow.pl/auth/register';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      setState(() => _errorMessage = 'Nie udalo sie otworzyc strony rejestracji.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zaloguj sie', style: textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        'Dostep do OperatFlow po rejestracji i zalogowaniu.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Wpisz email';
                          }
                          if (!value.contains('@')) {
                            return 'Nieprawidlowy adres email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Haslo',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        validator: (value) => (value == null || value.isEmpty) ? 'Wpisz haslo' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: _isLoading
                                ? null
                                : (val) => setState(() => _rememberMe = val ?? false),
                          ),
                          const Text('Zapamietaj dane logowania'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (widget.initialMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            widget.initialMessage!,
                            style: textTheme.bodyMedium?.copyWith(color: AppColors.warning),
                          ),
                        ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _errorMessage!,
                            style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignIn,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Zaloguj'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _openRegister,
                          child: const Text('Zarejestruj sie'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
