import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: true,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
