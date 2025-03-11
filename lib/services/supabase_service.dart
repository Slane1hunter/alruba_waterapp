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
      url: 'https://iqjknqbjrbouicdanjjm.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxamtucWJqcmJvdWljZGFuamptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDExOTg1MDAsImV4cCI6MjA1Njc3NDUwMH0.6aOm7o3FKypk72T6hXACsi0odzDsF9I-FLpo9krmDIM',      // For web compatibility, use:
      debug: true, // Remove storage configuration
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}  