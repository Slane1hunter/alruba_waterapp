import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:alruba_waterapp/providers/distributor_sales_provider.dart';
import 'package:alruba_waterapp/providers/location_provider.dart'; // Ensure this returns List<Location> objects

class DistributorSalesPage extends ConsumerStatefulWidget {
  const DistributorSalesPage({super.key});

  @override
  ConsumerState<DistributorSalesPage> createState() =>
      _DistributorSalesPageState();
}

class _DistributorSalesPageState extends ConsumerState<DistributorSalesPage> {
  // ------------------- Filters -------------------
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchText = '';
  String _locationFilter = ''; // empty means "All Locations"

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(distributorSalesProvider);
    final locationsAsync = ref.watch(locationsProvider); // This should return List<Location> objects

    return Scaffold(
      appBar: AppBar(title: const Text('My Sales')),
      body: Column(
        children: [
          _buildFilterSection(context, locationsAsync),
          Expanded(
            child: salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
              data: (allSales) {
                // Apply filters
                final filteredSales = _applyFilters(allSales);
                if (filteredSales.isEmpty) {
                  return const Center(child: Text('No matching sales.'));
                }
                // Group sales by day and display them
                return _buildGroupedSalesList(filteredSales);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build filter section with search field, location dropdown, and date range picker.
  Widget _buildFilterSection(
      BuildContext ctx, AsyncValue<List<dynamic>> locationsAsync) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search Field
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by customer name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() => _searchText = val.trim().toLowerCase());
              },
            ),
            const SizedBox(height: 12),
            // Row with Location Dropdown and Date Range Button
            Row(
              children: [
                const Text('Location: '),
                const SizedBox(width: 8),
                Expanded(
                  child: locationsAsync.when(
                    data: (locations) {
                      // Build dropdown items using your Location model's dot notation.
                      final items = <DropdownMenuItem<String>>[
                        const DropdownMenuItem(
                            value: '', child: Text('All Locations'))
                      ];
                      items.addAll(locations.map<DropdownMenuItem<String>>((loc) {
                        // Assuming loc is an instance of your Location model with a 'name' property.
                        return DropdownMenuItem(
                          value: loc.name,
                          child: Text(loc.name),
                        );
                      }));
                      return DropdownButton<String>(
                        isExpanded: true,
                        value: _locationFilter,
                        items: items,
                        onChanged: (val) {
                          setState(() {
                            _locationFilter = val ?? '';
                          });
                        },
                      );
                    },
                    loading: () => const SizedBox(
                      width: 50,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (err, st) => Text('Error: $err'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('Date Range'),
                  onPressed: () => _pickDateRange(ctx),
                ),
              ],
            ),
            if (_startDate != null && _endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Filtering: ${DateFormat('yyyy-MM-dd').format(_startDate!)} → ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Date range picker
  Future<void> _pickDateRange(BuildContext ctx) async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: _startDate ?? now.subtract(const Duration(days: 30)),
      end: _endDate ?? now,
    );
    final newRange = await showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      initialDateRange: initialRange,
    );
    if (newRange != null) {
      setState(() {
        _startDate = newRange.start;
        _endDate = newRange.end;
      });
    }
  }

  // Filter logic: applies search, location, and date range filters.
  List<DistributorSale> _applyFilters(List<DistributorSale> all) {
    return all.where((sale) {
      // Filter by customer name
      if (_searchText.isNotEmpty &&
          !sale.customerName.toLowerCase().contains(_searchText)) {
        return false;
      }
      // Filter by location if selected
      if (_locationFilter.isNotEmpty &&
          sale.location.toLowerCase() != _locationFilter.toLowerCase()) {
        return false;
      }
      // Filter by date range
      if (_startDate != null && _endDate != null) {
        if (sale.date.isBefore(_startDate!) || sale.date.isAfter(_endDate!)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Group sales by day (yyyy-MM-dd) and display in an ExpansionTile
  Widget _buildGroupedSalesList(List<DistributorSale> sales) {
    final Map<String, List<DistributorSale>> grouped = {};
    for (var sale in sales) {
      final dayKey = DateFormat('yyyy-MM-dd').format(sale.date);
      grouped.putIfAbsent(dayKey, () => []).add(sale);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final day = sortedKeys[index];
        final daySales = grouped[day]!;
        return Card(
          margin: const EdgeInsets.all(8),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text(
              day,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Total Sales: ${daySales.length}'),
            children: daySales.map((sale) => _buildSaleTile(sale)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSaleTile(DistributorSale sale) {
    return ListTile(
      title: Text(
        sale.customerName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Product: ${sale.productName}\n'
        'Qty: ${sale.quantity}\n'
        'Total: \$${sale.totalPrice.toStringAsFixed(2)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showSaleDetailsDialog(sale),
    );
  }

  // Details dialog when tapping a sale. It shows product, quantity, unit price, and more.
  void _showSaleDetailsDialog(DistributorSale sale) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Sale for ${sale.customerName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.date)}'),
                const SizedBox(height: 4),
                Text('Product: ${sale.productName}'),
                const SizedBox(height: 4),
                Text('Quantity: ${sale.quantity}'),
                const SizedBox(height: 4),
                Text('Price/Unit: \$${sale.pricePerUnit.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                Text('Total: \$${sale.totalPrice.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                Text('Phone: ${sale.phone.isNotEmpty ? sale.phone : 'N/A'}'),
                const SizedBox(height: 4),
                Text('Location: ${sale.location}'),
                if (sale.preciseLocation != null)
                  Text('Precise: ${sale.preciseLocation}'),
                const SizedBox(height: 12),
                if (sale.phone.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('Call Customer'),
                    onPressed: () => _openDialer(sale.phone),
                  ),
                if (sale.preciseLocation != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('Open in Maps'),
                    onPressed: () => _openInMaps(sale.preciseLocation!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Launch phone dialer
  Future<void> _openDialer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Could not launch $uri");
    }
  }

  // Launch Google Maps
  Future<void> _openInMaps(String locationString) async {
    final googleUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$locationString');
    if (await canLaunchUrl(googleUri)) {
      await launchUrl(googleUri);
    } else {
      debugPrint("Could not launch $googleUri");
    }
  }
}
