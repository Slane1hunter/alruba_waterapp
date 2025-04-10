import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';

class ManagerDashboardPage extends ConsumerStatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  ConsumerState<ManagerDashboardPage> createState() =>
      _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends ConsumerState<ManagerDashboardPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchText = '';
  String? _locationFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to "today" as the initial range.
    _startDate = DateTime(now.year, now.month, now.day, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59);
  }

  /// Returns the select columns for the view without extra query parameters.
  String _buildSelectColumns() {
    return 'id, quantity, price_per_unit, total_amount, payment_status, created_at, '
           'location:locations!sales_location_id_fkey(name), '
           'customer:customers!fk_sales_customer(name), '
           'product:products!sales_product_id_fkey(name), '
           'sold_by_first_name, sold_by_last_name';
  }

  /// Fetch sales data from the view 'sales_with_profiles'
  /// Apply ordering by created_at and then filter on date client-side.
  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    final columns = _buildSelectColumns();
    debugPrint('[DEBUG] Selecting columns: $columns');

    try {
      final result = await SupabaseService.client
          .from('sales_with_profiles')
          .select(columns)
          .order('created_at', ascending: false);
      debugPrint('[DEBUG] raw sales => $result');

      var sales = List<Map<String, dynamic>>.from(result);

      // Apply client-side date filtering.
      if (_startDate != null || _endDate != null) {
        sales = sales.where((sale) {
          final rawDate = sale['created_at'];
          if (rawDate == null) return false;
          final createdAt = DateTime.tryParse(rawDate.toString());
          if (createdAt == null) return false;
          if (_startDate != null && createdAt.isBefore(_startDate!)) return false;
          if (_endDate != null && createdAt.isAfter(_endDate!)) return false;
          return true;
        }).toList();
      }

      return sales;
    } catch (e, st) {
      debugPrint('[DEBUG] _fetchSalesData error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Let the manager pick a date range.
  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: _startDate ?? now.subtract(const Duration(days: 7)),
      end: _endDate ?? now,
    );
    final newRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (newRange != null) {
      setState(() {
        _startDate = newRange.start;
        _endDate = newRange.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}), // Rebuild for re-fetching data.
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildFilterSection(theme),
            _buildSalesList(theme),
          ],
        ),
      ),
    );
  }

  /// Build the filter section: search, date range, and location.
  Widget _buildFilterSection(ThemeData theme) {
    final locationsAsync = ref.watch(locationsProvider);
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search field.
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by customer or product',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  _searchText = val.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            // Date range row.
            Row(
              children: [
                Expanded(
                  child: Text(
                    _startDate != null && _endDate != null
                        ? 'Date: ${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
                        : 'Select date range',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('Pick Date'),
                  onPressed: () => _pickDateRange(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Location filter.
            Row(
              children: [
                const Text(
                  'Location:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                locationsAsync.when(
                  data: (locations) {
                    final dropItems = [
                      const DropdownMenuItem<String>(
                        value: 'ALL',
                        child: Text('All Locations'),
                      ),
                      ...locations.map((loc) => DropdownMenuItem<String>(
                            value: loc.name,
                            child: Text(loc.name),
                          )),
                    ];
                    return DropdownButton<String>(
                      value: _locationFilter ?? 'ALL',
                      items: dropItems,
                      onChanged: (val) {
                        setState(() {
                          _locationFilter = (val == 'ALL') ? null : val;
                        });
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, st) {
                    debugPrint('[DEBUG] Locations error: $err');
                    return Text('Error: $err');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build the sales list using data from the view.
  Widget _buildSalesList(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchSalesData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint('[DEBUG] Sales list error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var salesData = snapshot.data ?? [];

        // Apply client-side location filter.
        if (_locationFilter != null && _locationFilter != 'ALL') {
          salesData = salesData.where((sale) {
            final loc = sale['location'];
            final locName = (loc is Map)
                ? (loc['name']?.toString().toLowerCase() ?? '')
                : '';
            return locName == _locationFilter!.toLowerCase();
          }).toList();
        }

        // Apply client-side search filtering.
        if (_searchText.isNotEmpty) {
          salesData = salesData.where((sale) {
            final cust = _parseName(sale['customer']);
            final prod = _parseName(sale['product']);
            return cust.toLowerCase().contains(_searchText) ||
                prod.toLowerCase().contains(_searchText);
          }).toList();
        }

        if (salesData.isEmpty) {
          return const Center(child: Text('No sales data available'));
        }

        // Group sales by date.
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final sale in salesData) {
          final raw = sale['created_at'] ?? '';
          final dt = DateTime.tryParse(raw.toString()) ?? DateTime.now();
          final dateKey = DateFormat('yyyy-MM-dd').format(dt);
          grouped.putIfAbsent(dateKey, () => []).add(sale);
        }
        final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedKeys.length,
          itemBuilder: (ctx, idx) {
            final dateKey = sortedKeys[idx];
            final daySales = grouped[dateKey] ?? [];
            double dailyTotal = 0.0;
            for (final s in daySales) {
              final tot = num.tryParse(s['total_amount']?.toString() ?? '') ?? 0.0;
              dailyTotal += tot;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '$dateKey  |  Day Total: \$${dailyTotal.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: daySales.length,
                  itemBuilder: (ctx2, sdx) {
                    final sale = daySales[sdx];
                    final custName = _parseName(sale['customer']);
                    final prodName = _parseName(sale['product']);
                    final locName  = _parseName(sale['location']);
                    final qty = num.tryParse(sale['quantity']?.toString() ?? '') ?? 0;
                    final ppu = num.tryParse(sale['price_per_unit']?.toString() ?? '') ?? 0;
                    final totPrice = num.tryParse(sale['total_amount']?.toString() ?? '')
                        ?? (qty * ppu);
                    final payStatus = sale['payment_status']?.toString() ?? 'unknown';

                    final firstName = sale['sold_by_first_name']?.toString() ?? '';
                    final lastName = sale['sold_by_last_name']?.toString() ?? '';
                    final distName = '$firstName $lastName'.trim();

                    final rawCreated = sale['created_at']?.toString() ?? '';
                    final dtSale = DateTime.tryParse(rawCreated) ?? DateTime.now();
                    final formattedTime = DateFormat('HH:mm').format(dtSale);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Text('$custName - $prodName', style: theme.textTheme.bodyLarge),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Qty: $qty, Price: \$${ppu.toStringAsFixed(2)}'),
                            Text('Total: \$${totPrice.toStringAsFixed(2)}'),
                            Text('Status: ${payStatus.toUpperCase()}'),
                            Text('Distributor: ${distName.isNotEmpty ? distName : "unknown"}'),
                            Text('Location: $locName'),
                            Text('Time: $formattedTime'),
                          ],
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Sale Details'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Customer: $custName'),
                                  Text('Product: $prodName'),
                                  Text('Quantity: $qty'),
                                  Text('Price/Unit: \$${ppu.toStringAsFixed(2)}'),
                                  Text('Total: \$${totPrice.toStringAsFixed(2)}'),
                                  Text('Payment: ${payStatus.toUpperCase()}'),
                                  Text('Distributor: ${distName.isNotEmpty ? distName : "unknown"}'),
                                  Text('Location: $locName'),
                                  Text('Time: $formattedTime'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                )
              ],
            );
          },
        );
      },
    );
  }

  /// Helper to parse a "name" from a field (for customer, product, or location).
  String _parseName(dynamic field) {
    if (field is Map) {
      return field['name']?.toString() ?? 'unknown';
    }
    return 'unknown';
  }
}
