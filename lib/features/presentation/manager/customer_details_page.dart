// lib/pages/customer_details_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alruba_waterapp/providers/customers_provider.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';
import 'package:alruba_waterapp/models/location.dart';

class CustomerDetailsPage extends ConsumerStatefulWidget {
  const CustomerDetailsPage({super.key});

  @override
  ConsumerState<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends ConsumerState<CustomerDetailsPage> {
  String _searchText = '';
  String? _locationFilter;
  String? _customerTypeFilter;
  final List<String> _customerTypes = ['ALL', 'regular', 'distributor'];

  Future<void> _makeCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  Future<void> _openMap(String address) async {
    final query = Uri.encodeComponent(address);
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  String _getLocationName(String? locationId, List<Location> locations) {
    try {
      return locations.firstWhere(
        (loc) => loc.id == locationId,
        orElse: () => Location(id: '', name: 'Unknown'),
      ).name;
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildFilterSection(ThemeData theme) {
    final locationsAsync = ref.watch(locationsProvider);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Customer or Product',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchText = val.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildLocationFilter(locationsAsync, theme),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCustomerTypeFilter(theme),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCustomerCount(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationFilter(AsyncValue<List<Location>> locationsAsync, ThemeData theme) {
    return locationsAsync.when(
      data: (locations) => DropdownButtonFormField<String>(
        isExpanded: true,
        value: _locationFilter ?? 'ALL',
        items: [
          const DropdownMenuItem<String>(
            value: 'ALL',
            child: Text('All Locations'),
          ),
          ...locations.map((loc) => DropdownMenuItem<String>(
            value: loc.id,
            child: Text(loc.name),
          ))
        ],
        decoration: InputDecoration(
          labelText: 'Location',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (val) => setState(() => _locationFilter = val == 'ALL' ? null : val),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error: $err'),
    );
  }

  Widget _buildCustomerTypeFilter(ThemeData theme) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _customerTypeFilter ?? 'ALL',
      items: _customerTypes.map((type) => DropdownMenuItem<String>(
        value: type,
        child: Text(type == 'ALL' ? 'All Types' : type.toUpperCase()),
      )).toList(),
      decoration: InputDecoration(
        labelText: 'Type',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onChanged: (val) => setState(() => _customerTypeFilter = val == 'ALL' ? null : val),
    );
  }

  Widget _buildCustomerCount() {
    final customers = ref.watch(customersProvider).value ?? [];
    final filteredCount = _filterCustomers(customers).length;
    
    return Text(
      '$filteredCount customers found',
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.secondary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  List<Map<String, dynamic>> _filterCustomers(List<Map<String, dynamic>> customers) {
    return customers.where((customer) {
      if (_locationFilter != null && customer['location_id'] != _locationFilter) return false;
      if (_customerTypeFilter != null && customer['type'] != _customerTypeFilter) return false;
      if (_searchText.isNotEmpty && 
          !(customer['name']?.toString().toLowerCase().contains(_searchText) ?? false)) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildCustomerList() {
    final customersAsync = ref.watch(customersProvider);
    final locations = ref.watch(locationsProvider).value ?? [];
    
    return customersAsync.when(
      data: (customers) {
        final filtered = _filterCustomers(customers);
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final customer = filtered[index];
            return _CustomerCard(
              customer: customer,
              locationName: _getLocationName(customer['location_id'], locations),
              onCall: () => _makeCall(customer['phone']),
              onMap: () => _openMap(customer['address']),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        centerTitle: true,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildFilterSection(Theme.of(context))),
        ],
        body: _buildCustomerList(),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final String locationName;
  final VoidCallback onCall;
  final VoidCallback onMap;

  const _CustomerCard({
    required this.customer,
    required this.locationName,
    required this.onCall,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  customer['name'] ?? 'Unknown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Chip(
                  label: Text((customer['type'] ?? 'unknown').toUpperCase()),
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.phone, text: customer['phone'] ?? 'N/A'),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_on, text: locationName),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.map, text: customer['address'] ?? 'No address'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                  onPressed: onCall,
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Map'),
                  onPressed: onMap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
