import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

final roleProvider = FutureProvider.autoDispose<String>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) throw Exception('No authenticated user');

  try {
    final response = await SupabaseService.client
        .from('profiles')
        .select('role')
        .eq('user_id', userId)
        .single()
        .timeout(const Duration(seconds: 5));

    return response['role'] as String;
  } catch (e) {
    // Auto-signout if role fetch fails
    await SupabaseService.client.auth.signOut();
    throw Exception('Role fetch failed: $e');
  }
});