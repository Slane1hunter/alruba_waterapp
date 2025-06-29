import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final customersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  
  try {
    final response = await client.from('customers').select('*');
    return response;
  } catch (e) {
    throw Exception('Failed to load customers: $e');
  }
});