import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class CustomerLocationField extends StatefulWidget {
  final String? selectedLocation;
  final ValueChanged<String?> onLocationChanged;
  final List<Map<String, String>> locations; // Each with 'id' and 'name'

  const CustomerLocationField({
    super.key,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.locations,
  });

  @override
  State<CustomerLocationField> createState() => _CustomerLocationFieldState();
}

class _CustomerLocationFieldState extends State<CustomerLocationField> {
  String? _exactLocation;

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled.
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled.");
      }
      // Check and request location permissions.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permissions are denied.");
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied.");
      }
      // Get the current position.
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      // Reverse geocode to get address details.
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        setState(() {
          _exactLocation =
              '${placemark.street}, ${placemark.locality}, ${placemark.country}';
        });
      }
    } catch (e) {
      // Show an error message if location cannot be fetched.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error getting location: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown for pre-defined locations.
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Select Customer Location',
            border: OutlineInputBorder(),
          ),
          value: widget.selectedLocation,
          items: widget.locations.map((loc) {
            return DropdownMenuItem<String>(
              value: loc['id'],
              child: Text(loc['name']!),
            );
          }).toList(),
          onChanged: widget.onLocationChanged,
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Please select a location';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Row with a text display for exact location and a button to get current location.
        Row(
          children: [
            Expanded(
              child: Text(
                _exactLocation ?? 'Exact location not set',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: const Text("Get Current Location"),
            ),
          ],
        ),
      ],
    );
  }
}
