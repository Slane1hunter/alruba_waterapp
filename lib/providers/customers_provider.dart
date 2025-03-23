import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


final customersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('customers')
      .select('id, name, phone, type');

  final data = response as List; 
  return data.map((e) => e as Map<String, dynamic>).toList();
});
