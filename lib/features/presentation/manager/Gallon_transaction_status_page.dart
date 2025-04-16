import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:alruba_waterapp/services/payment_service.dart';

class GallonTransactionStatusPage extends ConsumerStatefulWidget {
  const GallonTransactionStatusPage({super.key});

  @override
  ConsumerState<GallonTransactionStatusPage> createState() =>
      _GallonTransactionStatusPageState();
}

class _GallonTransactionStatusPageState extends ConsumerState<GallonTransactionStatusPage> {
  // All transaction data once loaded.
  List<Map<String, dynamic>> _allTransactions = [];

  // UI filter states.
  bool _isLoading = false;
  String _searchText = '';              // For dynamic name filtering
  String _selectedStatusFilter = 'all'; // 'all', 'paid', 'unpaid'
  DateTime? _startDate;
  DateTime? _endDate;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  /// Fetch all transactions from Supabase once.
  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.client
          .from('gallon_transactions')
          .select('*, customer:customers!customer_id(id, name), sale_id')
          .order('created_at', ascending: false);
      _allTransactions = List<Map<String, dynamic>>.from(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Filter in-memory by name, status, and date.
  List<Map<String, dynamic>> _filterTransactions() {
    return _allTransactions.where((tx) {
      // 1) Payment Status
      if (_selectedStatusFilter != 'all') {
        final status = (tx['status'] ?? '').toString().trim().toLowerCase();
        if (status != _selectedStatusFilter) return false;
      }

      // 2) Date Range
      final createdAtStr = (tx['created_at'] ?? '').toString();
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt != null) {
        if (_startDate != null && createdAt.isBefore(_startDate!)) return false;
        if (_endDate != null && createdAt.isAfter(_endDate!)) return false;
      }

      // 3) Search by Customer Name
      final customer = tx['customer'];
      final customerName = (customer is Map)
          ? (customer['name'] ?? '').toString().toLowerCase()
          : '';
      // If _searchText is non-empty, ensure the name contains it
      if (_searchText.isNotEmpty && !customerName.contains(_searchText)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Group the filtered list by customer.
  Map<String, List<Map<String, dynamic>>> _groupByCustomer(List<Map<String, dynamic>> list) {
    return groupBy(list, (Map<String, dynamic> tx) {
      final customer = tx['customer'];
      if (customer is Map && customer['id'] != null) {
        return customer['id'].toString();
      }
      return 'unknown';
    });
  }

  /// Toggle the status of a transaction to "paid."
  Future<void> _toggleStatus(Map<String, dynamic> transaction) async {
    final transactionId = transaction['id'].toString();
    final saleId = transaction['sale_id']?.toString();
    final currentStatus = (transaction['status'] ?? '').toString().trim().toLowerCase();

    if (currentStatus == 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already marked as paid.')),
      );
      return;
    }
    if (saleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale ID not found; cannot update.')),
      );
      return;
    }

    try {
      await PaymentService.markAsPaid(
        saleId: saleId,
        gallonTransactionId: transactionId,
      );
      // Reflect the "paid" status locally.
      setState(() {
        transaction['status'] = 'paid';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as paid successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  /// Pick a date range.
  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterTransactions();
    final grouped = _groupByCustomer(filteredList);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallon Transactions'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : grouped.isEmpty
              ? Column(
                  children: [
                    _buildFilters(),
                    const Expanded(child: Center(child: Text('No transactions found'))),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _loadTransactions,
                  child: ListView(
                    children: [
                      _buildFilters(),
                      for (final entry in grouped.entries)
                        _buildCustomerGroupTile(entry.key, entry.value),
                    ],
                  ),
                ),
    );
  }

  /// The filter panel at the top — no explicit "Search" button; we filter on every keystroke.
  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Live search: onChanged
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by Customer Name',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) {
                setState(() {
                  _searchText = val.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),

            // Reload data button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reload Data'),
                onPressed: _loadTransactions,
              ),
            ),
            const SizedBox(height: 16),

            // Payment status + date range
            Row(
              children: [
                const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedStatusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedStatusFilter = val ?? 'all';
                    });
                  },
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    (_startDate != null && _endDate != null)
                        ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                        : 'Select Date Range',
                  ),
                ),
                if (_startDate != null || _endDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerGroupTile(String customerId, List<Map<String, dynamic>> transactions) {
    // Identify the customer name from the first transaction
    String customerName = 'Unknown Customer';
    if (transactions.isNotEmpty) {
      final firstTx = transactions.first;
      final cust = firstTx['customer'];
      if (cust is Map && cust['name'] != null) {
        customerName = cust['name'].toString();
      }
    }

    // Summaries
    final totalQty = transactions.fold<int>(0, (sum, tx) {
      return sum + (int.tryParse(tx['quantity']?.toString() ?? '0') ?? 0);
    });
    final totalAmt = transactions.fold<double>(0, (sum, tx) {
      return sum + (double.tryParse(tx['amount']?.toString() ?? '0') ?? 0);
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          customerName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text('Total Qty: $totalQty', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 16),
              Text('Total Amount: \$${totalAmt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
        children: transactions.map(_buildTransactionItem).toList(),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final type = (tx['transaction_type'] ?? 'Unknown').toString();
    final qty = (tx['quantity'] ?? '0').toString();
    final amt = (tx['amount'] ?? '0').toString();
    final status = (tx['status'] ?? '').toString().trim().toLowerCase();
    final isPaid = status == 'paid';

    final createdAtStr = (tx['created_at'] ?? '').toString();
    final createdAt = DateTime.tryParse(createdAtStr);
    final dateFormatted = (createdAt != null)
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt)
        : 'Unknown date';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        title: Text('Type: ${_capitalize(type)}', style: const TextStyle(fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quantity: $qty', style: const TextStyle(fontSize: 16)),
            Text('Amount: \$$amt', style: const TextStyle(fontSize: 16)),
            Text('Date: $dateFormatted', style: const TextStyle(fontSize: 16)),
          ],
        ),
        trailing: !isPaid
            ? IconButton(
                icon: const Icon(Icons.payment, color: Colors.blueAccent),
                onPressed: () => _toggleStatus(tx),
              )
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
