import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roleProvider = FutureProvider<String>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return ''; // Not logged in
  }

  final response = await Supabase.instance.client
      .from('profiles')
      .select('role')
      .eq('user_id', user.id)
      .maybeSingle();
      print('User: $user');
print('Profile response: $response');


  if (response == null || response['role'] == null) {
    return '';
  }

  return response['role'] as String;
});
