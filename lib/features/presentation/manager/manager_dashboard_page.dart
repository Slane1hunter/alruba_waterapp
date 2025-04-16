import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';

class ManagerDashboardPage extends ConsumerStatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  ConsumerState<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends ConsumerState<ManagerDashboardPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchText = '';
  String? _locationFilter;
  String? _soldByFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default date range: today (from midnight to 23:59)
    _startDate = DateTime(now.year, now.month, now.day, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        centerTitle: true,
        elevation: 4,
        backgroundColor: theme.colorScheme.primary,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // The filter section will scroll away when the list is scrolled.
            SliverToBoxAdapter(
              child: _buildFilterSection(theme),
            ),
            // Extra spacing
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ];
        },
        body: _buildSalesList(theme),
      ),
    );
  }

  /// Returns the select columns for the view.
  String _buildSelectColumns() {
    return 'id, quantity, price_per_unit, total_amount, payment_status, created_at, '
           'location:locations!sales_location_id_fkey(name), '
           'customer:customers!fk_sales_customer(name), '
           'product:products!sales_product_id_fkey(name), '
           'sold_by, sold_by_first_name, sold_by_last_name';
  }

  /// Fetch sales data from the 'sales_with_profiles' view.
  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    final columns = _buildSelectColumns();
    debugPrint('[DEBUG] Selecting columns: $columns');
    try {
      final result = await SupabaseService.client
          .from('sales_with_profiles')
          .select(columns)
          .order('created_at', ascending: false);
     // debugPrint('[DEBUG] raw sales => $result');
      var sales = List<Map<String, dynamic>>.from(result);

      // Client-side date filtering.
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

      // Client-side sold-by filtering.
      if (_soldByFilter != null && _soldByFilter != 'ALL') {
        sales = sales.where((sale) => sale['sold_by'] == _soldByFilter).toList();
      }

      // Client-side search filtering.
      if (_searchText.isNotEmpty) {
        sales = sales.where((sale) {
          final cust = _parseName(sale['customer']);
          final prod = _parseName(sale['product']);
          return cust.toLowerCase().contains(_searchText) ||
              prod.toLowerCase().contains(_searchText);
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

  /// Build the Sold By filter widget.
  Widget _buildSoldByFilter(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.client
          .from('profiles')
          .select('user_id, first_name, last_name, role')
          .inFilter('role', ['distributor', 'manager'])
          .order('first_name')
          .then((data) => List<Map<String, dynamic>>.from(data)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          debugPrint('Error fetching sellers: ${snapshot.error}');
          return const Text('Error loading sellers');
        }
        final sellers = snapshot.data ?? [];
        debugPrint('Fetched sellers: ${sellers.length}');
        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text('Sold By:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _soldByFilter ?? 'ALL',
              items: [
                const DropdownMenuItem(
                  value: 'ALL',
                  child: Text('All Sellers'),
                ),
                ...sellers.map((seller) {
                  final fullName = '${seller['first_name']} ${seller['last_name']}';
                  debugPrint('Seller ${seller['first_name']}: ${seller['role']}');
                  return DropdownMenuItem(
                    value: seller['user_id'],
                    child: Text(fullName),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _soldByFilter = val == 'ALL' ? null : val),
              underline: Container(
                height: 2,
                color: theme.colorScheme.primary,
              ),
              icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
            ),
          ],
        );
      },
    );
  }

  /// Build the complete filter section.
  Widget _buildFilterSection(ThemeData theme) {
    final locationsAsync = ref.watch(locationsProvider);
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field.
            TextField(
              decoration: InputDecoration(
                labelText: 'Search by customer or product',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) => setState(() => _searchText = val.trim().toLowerCase()),
            ),
            const SizedBox(height: 20),
            // Date range row.
            Row(
              children: [
                Expanded(
                  child: Text(
                    (_startDate != null && _endDate != null)
                        ? 'Date: ${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}'
                        : 'Select date range',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_month, size: 28, color: theme.colorScheme.primary),
                  onPressed: () => _pickDateRange(context),
                  tooltip: 'Select date range',
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Location filter row.
            Row(
              children: [
                const Text('Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
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
                      underline: Container(
                        height: 2,
                        color: theme.colorScheme.primary,
                      ),
                      icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) {
                    debugPrint('[DEBUG] Locations error: $e');
                    return Text('Error: $e');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Sold By filter row.
            _buildSoldByFilter(theme),
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
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        var salesData = snapshot.data ?? [];

        // Apply client-side location filtering.
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
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final sale in salesData) {
          final raw = sale['created_at'] ?? '';
          final dt = DateTime.tryParse(raw.toString()) ?? DateTime.now();
          final dateKey = DateFormat('yyyy-MM-dd').format(dt);
          grouped.putIfAbsent(dateKey, () => []).add(sale);
        }
        final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: sortedKeys.length,
          itemBuilder: (ctx, idx) {
            final dateKey = sortedKeys[idx];
            final daySales = grouped[dateKey]!;
            double dailyTotal = 0.0;
            for (final s in daySales) {
              final tot = num.tryParse(s['total_amount']?.toString() ?? '') ?? 0.0;
              dailyTotal += tot;
            }
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExpansionTile(
                iconColor: theme.colorScheme.primary,
                collapsedIconColor: theme.colorScheme.onSurface,
                title: Text(
                  '$dateKey  |  Day Total: \$${dailyTotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                children: daySales.map((sale) => _buildSaleItem(sale, theme)).toList(),
              ),
            );
          },
        );
      },
    );
  }

  /// Build an individual sale item.
  Widget _buildSaleItem(Map<String, dynamic> sale, ThemeData theme) {
    final custName = _parseName(sale['customer']);
    final prodName = _parseName(sale['product']);
    final locName = _parseName(sale['location']);
    final qty = num.tryParse(sale['quantity']?.toString() ?? '') ?? 0;
    final ppu = num.tryParse(sale['price_per_unit']?.toString() ?? '') ?? 0;
    final totPrice = num.tryParse(sale['total_amount']?.toString() ?? '') ?? (qty * ppu);
    final payStatus = sale['payment_status']?.toString() ?? 'unknown';
    final firstName = sale['sold_by_first_name']?.toString() ?? '';
    final lastName = sale['sold_by_last_name']?.toString() ?? '';
    final distName = '$firstName $lastName'.trim();
    final rawCreated = sale['created_at']?.toString() ?? '';
    final dtSale = DateTime.tryParse(rawCreated) ?? DateTime.now();
    final formattedTime = DateFormat('HH:mm').format(dtSale);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text('$custName - $prodName', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qty: $qty, Price: \$${ppu.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium),
              Text('Total: \$${totPrice.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Status: ${payStatus.toUpperCase()}', style: theme.textTheme.bodyMedium?.copyWith(color: payStatus.toLowerCase() == 'paid' ? Colors.green : Colors.red)),
              Text('Distributor: ${distName.isNotEmpty ? distName : "unknown"}', style: theme.textTheme.bodySmall),
              Text('Location: $locName', style: theme.textTheme.bodySmall),
              Text('Time: $formattedTime', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
        onTap: () => _showSaleDetails(context, sale),
      ),
    );
  }

  /// Helper to parse a "name" from a field.
  String _parseName(dynamic field) {
    if (field is Map) {
      return field['name']?.toString() ?? 'Unknown';
    }
    return 'Unknown';
  }

  /// Display sale details in a dialog.
  void _showSaleDetails(BuildContext context, Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sale Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Customer:', _parseName(sale['customer'])),
              _buildDetailRow('Product:', _parseName(sale['product'])),
              _buildDetailRow('Quantity:', sale['quantity'].toString()),
              _buildDetailRow('Price/Unit:', '\$${sale['price_per_unit']}'),
              _buildDetailRow('Total:', '\$${sale['total_amount']}'),
              _buildDetailRow('Payment:', sale['payment_status'].toString().toUpperCase()),
              _buildDetailRow('Location:', _parseName(sale['location'])),
              _buildDetailRow('Seller:', '${sale['sold_by_first_name']} ${sale['sold_by_last_name']}'),
              _buildDetailRow(
                'Time:',
                DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(sale['created_at'].toString()))
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Helper to build a detail row.
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Flexible(child: Text(value)),
        ],
      ),
    );
  }
}
