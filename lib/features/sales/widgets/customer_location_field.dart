import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Widget for displaying a dropdown of pre-defined locations.
class CustomerLocationDropdown extends StatelessWidget {
  final String? selectedLocation;
  final ValueChanged<String?> onLocationChanged;
  final List<Map<String, String>> locations; // Each with 'id' and 'name'

  const CustomerLocationDropdown({
    super.key,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.locations,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Select Customer Location',
        border: OutlineInputBorder(),
      ),
      value: selectedLocation,
      items: locations.map((loc) {
        return DropdownMenuItem<String>(
          value: loc['id'],
          child: Text(loc['name']!),
        );
      }).toList(),
      onChanged: onLocationChanged,
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Please select a location';
        }
        return null;
      },
    );
  }
}

/// Widget for fetching and displaying the current (exact) location.
class ExactLocationWidget extends StatefulWidget {
  const ExactLocationWidget({super.key});

  @override
  State<ExactLocationWidget> createState() => _ExactLocationWidgetState();
}

class _ExactLocationWidgetState extends State<ExactLocationWidget> {
  String? _exactLocation;
  final TextEditingController _exactLocationCtrl = TextEditingController();

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled.");
      }

      // Check and request permissions.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permissions are denied.");
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied.");
      }

      // Use the updated API with LocationSettings.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Reverse geocode to get address details.
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        if (!mounted) return;
        setState(() {
          _exactLocation =
              '${placemark.street}, ${placemark.locality}, ${placemark.country}';
          _exactLocationCtrl.text = _exactLocation!;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error getting location: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Button to fetch current location.
        ElevatedButton.icon(
          icon: const Icon(Icons.my_location),
          label: const Text('Get Current Location'),
          onPressed: _getCurrentLocation,
        ),
        const SizedBox(height: 16),
        // Read-only field displaying the exact location.
        TextFormField(
          controller: _exactLocationCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Exact Location',
            hintText: 'Tap "Get Current Location" to fill this',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
