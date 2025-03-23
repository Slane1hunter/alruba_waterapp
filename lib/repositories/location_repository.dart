import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location.dart';
import '../services/supabase_service.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

class LocationRepository {
  // Fetch all locations
  Future<List<Location>> fetchLocations() async {
    final response = await SupabaseService.client
        .from('locations')
        .select('*');

    return response.map((item) => Location.fromMap(item)).toList();
  }

  // Add a new location
  Future<Location> addLocation(String name) async {
    // Force returning
    final inserted = await SupabaseService.client
        .from('locations')
        .insert({'name': name})
        .select()
        .single();
    return Location.fromMap(inserted);
  }

  // Update existing location
  Future<Location> updateLocation(String locationId, String newName) async {
    final updated = await SupabaseService.client
        .from('locations')
        .update({'name': newName})
        .eq('id', locationId)
        .select()
        .maybeSingle();

    if (updated == null) {
      throw Exception('No data returned from location update');
    }
    return Location.fromMap(updated);
  }
}
