import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location.dart';
import '../services/supabase_service.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

class LocationRepository {
  Future<List<Location>> fetchLocations() async {
    // In the new Supabase Flutter client, select() returns a List directly.
    final response = await SupabaseService.client.from('locations').select();
    // response is expected to be a List<dynamic>
    final List<dynamic> data = response as List<dynamic>;
    // Map each item to our Location model
    return data.map((e) => Location.fromMap(e)).toList();
  }
}
