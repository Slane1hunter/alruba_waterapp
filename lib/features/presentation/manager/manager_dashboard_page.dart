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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = now;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _selectColumns =>
      'id, quantity, price_per_unit, total_amount, payment_status, created_at, '
      'location:locations!sales_location_id_fkey(name), '
      'customer:customers!fk_sales_customer(name), '
      'product:products!sales_product_id_fkey(name), '
      'sold_by, sold_by_first_name, sold_by_last_name';

  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    try {
      final result = await SupabaseService.client
          .from('sales_with_profiles')
          .select(_selectColumns)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(result).where((sale) {
        final createdAt = _parseDateTime(sale['created_at']);
        final matchesDate = _startDate != null && _endDate != null
            ? createdAt.isAfter(_startDate!) && createdAt.isBefore(_endDate!)
            : true;
        final matchesSoldBy = _soldByFilter == null || sale['sold_by'] == _soldByFilter;
        final matchesSearch = _searchText.isEmpty ||
            _parseName(sale['customer']).toLowerCase().contains(_searchText) ||
            _parseName(sale['product']).toLowerCase().contains(_searchText);
        final matchesLocation = _locationFilter == null ||
            _parseName(sale['location']).toLowerCase() == _locationFilter!.toLowerCase();

        return matchesDate && matchesSoldBy && matchesSearch && matchesLocation;
      }).toList();
    } catch (e, st) {
      debugPrint('Sales fetch error: $e\n$st');
      rethrow;
    }
  }

  DateTime _parseDateTime(dynamic date) =>
      DateTime.tryParse(date.toString()) ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 260,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _buildFilterSection(theme),
              ),
            ),
            _buildSalesContent(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSearchField(theme),
          const SizedBox(height: 16),
          _buildDateFilter(theme),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildLocationFilter(theme)),
              const SizedBox(width: 16),
              Expanded(child: _buildSoldByFilter(theme)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by customer or product...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _searchController.clear();
            setState(() => _searchText = '');
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
      ),
      onChanged: (value) => setState(() => _searchText = value.toLowerCase()),
    );
  }

  Widget _buildDateFilter(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(Icons.calendar_month, color: theme.colorScheme.primary),
        title: Text(
          _startDate != null && _endDate != null
              ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
              : 'Select Date Range',
          style: theme.textTheme.bodyLarge,
        ),
        trailing: const Icon(Icons.arrow_drop_down),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _pickDateRange(context),
      ),
    );
  }

  Widget _buildLocationFilter(ThemeData theme) {
    return ref.watch(locationsProvider).when(
      data: (locations) => _FilterDropdown<String>(
        value: _locationFilter,
        hint: 'All Locations',
        items: locations.map((loc) => loc.name).toList(),
        onChanged: (value) => setState(() => _locationFilter = value),
        icon: Icons.location_on_outlined,
        theme: theme,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e', style: TextStyle(color: theme.colorScheme.error)),
    );
  }

  Widget _buildSoldByFilter(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.client
          .from('profiles')
          .select('user_id, first_name, last_name')
          .inFilter('role', ['distributor', 'manager']),
      builder: (context, snapshot) {
        final sellers = snapshot.data ?? [];
        return _FilterDropdown<String>(
          value: _soldByFilter,
          hint: 'All Sellers',
          items: sellers.map((s) => '${s['first_name']} ${s['last_name']}').toList(),
          onChanged: (value) => setState(() => _soldByFilter = value),
          icon: Icons.person_outline,
          theme: theme,
        );
      },
    );
  }

  Widget _buildSalesContent(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchSalesData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Text('Error loading sales: ${snapshot.error}',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          );
        }
        final salesData = snapshot.data ?? [];
        if (salesData.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text('No sales found', style: theme.textTheme.bodyLarge),
            ),
          );
        }

        // Group sales by date
        final Map<String, List<Map<String, dynamic>>> groupedSales = {};
        for (final sale in salesData) {
          final date = DateFormat('yyyy-MM-dd').format(_parseDateTime(sale['created_at']));
          groupedSales.putIfAbsent(date, () => []).add(sale);
        }

        // Sort dates in descending order
        final sortedDates = groupedSales.keys.toList()..sort((a, b) => b.compareTo(a));

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final date = sortedDates[index];
              final dailySales = groupedSales[date]!;
              final dailyTotal = dailySales.fold(0.0,
                  (sum, sale) => sum + (sale['total_amount'] as num));
              final productCounts = <String, int>{};

              for (final sale in dailySales) {
                final productName = _parseName(sale['product']);
                productCounts[productName] =
                    (productCounts[productName] ?? 0) + 1;
              }

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  iconColor: theme.colorScheme.primary,
                  collapsedIconColor: theme.colorScheme.onSurface,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('MMM dd, yyyy')
                          .format(DateTime.parse(date))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildSummaryChip(
                            icon: Icons.attach_money,
                            value: '\$${dailyTotal.toStringAsFixed(2)}',
                            theme: theme,
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryChip(
                            icon: Icons.shopping_cart,
                            value: '${dailySales.length} Items',
                            theme: theme,
                          ),
                        ],
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Products Sold:',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final entry in productCounts.entries)
                                Chip(
                                  label:
                                      Text('${entry.value}x ${entry.key}'),
                                  backgroundColor: theme
                                      .colorScheme.surfaceContainerHighest,
                                )
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    ...dailySales.map((sale) => _SaleItem(
                          sale: sale,
                          theme: theme,
                          onTap: () => _showSaleDetails(context, sale),
                        )),
                  ],
                ),
              );
            },
            childCount: sortedDates.length,
          ),
        );
      },
    );
  }

  Widget _buildSummaryChip({
    required IconData icon,
    required String value,
    required ThemeData theme,
  }) {
    return Chip(
      avatar: Icon(icon, size: 18, color: theme.colorScheme.primary),
      label: Text(value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          )),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final initialRange = DateTimeRange(
      start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
      end: _endDate ?? DateTime.now(),
    );
    final newRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (newRange != null) {
      setState(() {
        _startDate = newRange.start;
        _endDate = newRange.end;
      });
    }
  }

  String _parseName(dynamic field) {
    if (field is Map) return field['name']?.toString() ?? 'Unknown';
    return 'Unknown';
  }

  void _showSaleDetails(
      BuildContext context, Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sale Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: 'Customer:',
                value: _parseName(sale['customer']),
              ),
              _DetailRow(
                label: 'Product:',
                value: _parseName(sale['product']),
              ),
              _DetailRow(
                label: 'Quantity:',
                value: sale['quantity'].toString(),
              ),
              _DetailRow(
                label: 'Price/Unit:',
                value:
                    '\$${num.parse(sale['price_per_unit'].toString()).toStringAsFixed(2)}',
              ),
              _DetailRow(
                label: 'Total:',
                value:
                    '\$${num.parse(sale['total_amount'].toString()).toStringAsFixed(2)}',
              ),
              _DetailRow(
                label: 'Status:',
                value: sale['payment_status'].toString().toUpperCase(),
                valueColor: sale['payment_status']
                            .toString()
                            .toLowerCase() ==
                        'paid'
                    ? Colors.green
                    : Colors.red,
              ),
              _DetailRow(
                label: 'Location:',
                value: _parseName(sale['location']),
              ),
              _DetailRow(
                label: 'Seller:',
                value:
                    '${sale['sold_by_first_name']} ${sale['sold_by_last_name']}',
              ),
              _DetailRow(
                label: 'Time:',
                value: DateFormat('MMM dd, yyyy HH:mm')
                    .format(_parseDateTime(sale['created_at'])),
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
}

class _FilterDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;
  final ThemeData theme;

  const _FilterDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text(hint, style: theme.textTheme.bodyMedium),
            ),
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString(),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurface)),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SaleItem extends StatelessWidget {
  final Map<String, dynamic> sale;
  final ThemeData theme;
  final VoidCallback onTap;

  const _SaleItem({
    super.key,
    required this.sale,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final customer = _parseName(sale['customer']);
    final product = _parseName(sale['product']);
    final total = num.tryParse(sale['total_amount']!.toString()) ?? 0;
    final status = sale['payment_status']?.toString().toLowerCase() ?? 'unknown';
    final time = DateFormat.Hm().format(_parseDateTime(sale['created_at']));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(product, style: theme.textTheme.titleMedium),
                  Chip(
                    label: Text('\$${total.toStringAsFixed(2)}'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(customer, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(time, style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status, theme),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status, ThemeData theme) =>
      status == 'paid' ? theme.colorScheme.tertiaryContainer : theme.colorScheme.errorContainer;

  DateTime _parseDateTime(dynamic date) =>
      DateTime.tryParse(date.toString()) ?? DateTime.now();

  String _parseName(dynamic field) {
    if (field is Map) return field['name']?.toString() ?? 'Unknown';
    return 'Unknown';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
