import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final customersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('customers')
      .select('*');

  print("Response runtimeType: ${response.runtimeType}");
  
  if (response is List) {
    print("Fetched customers count: ${response.length}");
    return response.cast<Map<String, dynamic>>();
  } else {
    print("Unexpected response format: $response");
    throw Exception('Unexpected response format: ${response.runtimeType}');
  }
});
