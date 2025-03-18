import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location.dart';
import '../repositories/location_repository.dart';

final locationsProvider = FutureProvider<List<Location>>((ref) async {
  final repo = ref.watch(locationRepositoryProvider);
  final locations = await repo.fetchLocations();
  return locations;
});
