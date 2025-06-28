import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final _supabase = Supabase.instance.client;

 AuthNotifier() : super(const AsyncValue.loading()) {
  final user = _supabase.auth.currentUser;
  state = AsyncValue.data(user);

  _supabase.auth.onAuthStateChange.listen((data) {
    final session = data.session;
    state = AsyncValue.data(session?.user);
  });
}


  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _supabase.auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authStateProvider = Provider<AsyncValue<User?>>((ref) {
  return ref.watch(authProvider);
});
