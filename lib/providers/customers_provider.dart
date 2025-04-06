import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final customersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('customers')
      .select('*');

  print("Response runtimeType: ${response.runtimeType}");
  
  print("Fetched customers count: ${response.length}");
  return response.cast<Map<String, dynamic>>();
});
