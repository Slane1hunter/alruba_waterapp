import 'package:alruba_waterapp/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocationListPage extends ConsumerWidget {
  const LocationListPage({super.key});

  Future<List<dynamic>> fetchLocations() async {
    // Query locations from Supabase.
    final data = await SupabaseService.client.from('locations').select('*');
    return data as List<dynamic>;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<dynamic>>(
      future: fetchLocations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          debugPrint('Error fetching locations: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          final locations = snapshot.data!;
          return Scaffold(
            body: ListView.builder(
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return ListTile(
                  title: Text(location['name'].toString()),
                );
              },
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                // Navigate to add/edit location page (to be implemented)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add Location pressed')),
                );
              },
              child: const Icon(Icons.add),
            ),
          );
        }
        return const Center(child: Text('No locations found'));
      },
    );
  }
}
