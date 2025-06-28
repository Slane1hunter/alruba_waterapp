import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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

/// Widget for fetching and displaying the current (exact) location entirely offline.
/// Shows a loading indicator while obtaining GPS fix, then displays latitude/longitude.
class ExactLocationWidget extends StatefulWidget {
  /// Called when a new location string is available (lat,lon).
  final ValueChanged<String>? onLocationSelected;

  const ExactLocationWidget({super.key, this.onLocationSelected});

  @override
  State<ExactLocationWidget> createState() => _ExactLocationWidgetState();
}

class _ExactLocationWidgetState extends State<ExactLocationWidget> {
  final TextEditingController _exactLocationCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _loading = true);
    try {
      // Ensure GPS is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled.");
      }

      // Permissions
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

      // Get GPS fix
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final coords =
          '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';

      if (!mounted) return;
      setState(() {
        _exactLocationCtrl.text = coords;
        _loading = false;
      });

      widget.onLocationSelected?.call(coords);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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
        ElevatedButton.icon(
          icon: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.my_location),
          label: Text(_loading ? 'Locating...' : 'Get Current Location'),
          onPressed: _loading ? null : _getCurrentLocation,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _exactLocationCtrl,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Exact Location',
            hintText: 'Tap "Get Current Location" to fill this',
            border: const OutlineInputBorder(),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          validator: (_) {
            if (_exactLocationCtrl.text.isEmpty) {
              return 'Please tap to fetch location';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _exactLocationCtrl.dispose();
    super.dispose();
  }
}
