import 'package:supabase_flutter/supabase_flutter.dart';

class LicenseInfo {
  final String status;
  final String? plan;
  final DateTime? expiresAt;
  final DateTime? startsAt;

  LicenseInfo({
    required this.status,
    this.plan,
    this.expiresAt,
    this.startsAt,
  });

  bool get isActive {
    final normalizedNow = DateTime.now().toUtc();
    final notExpired = expiresAt == null || expiresAt!.isAfter(normalizedNow);
    return (status == 'active' || status == 'trial') && notExpired;
  }

  String get label {
    if (status == 'active') return 'Aktywna';
    if (status == 'trial') return 'Trial';
    if (status == 'expired') return 'Wygasła';
    if (status == 'canceled') return 'Anulowana';
    return status;
  }

  factory LicenseInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) =>
        value == null ? null : DateTime.tryParse(value)?.toUtc();

    return LicenseInfo(
      status: json['status'] as String? ?? 'unknown',
      plan: json['plan'] as String?,
      expiresAt: parseDate(json['expires_at'] as String?),
      startsAt: parseDate(json['starts_at'] as String?),
    );
  }
}

class AuthService {
  static const String supabaseUrl = 'https://addchmpbmqzbhpjzxaes.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_Bq9GojD8RBTf3WGyAmIX1A_bSN7ts85';

  final SupabaseClient client = Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  Future<AuthResponse> signIn(String email, String password) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return client.auth.signOut();
  }

  Future<LicenseInfo?> fetchLatestLicense(String userId) async {
    final response = await client
        .from('licenses')
        .select()
        .eq('user_id', userId)
        .order('starts_at', ascending: false)
        .limit(1);

    if (response.isEmpty) return null;
    return LicenseInfo.fromJson(response.first as Map<String, dynamic>);
  }
}
