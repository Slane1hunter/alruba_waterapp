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

class _GallonTransactionStatusPageState
    extends ConsumerState<GallonTransactionStatusPage> {
  List<Map<String, dynamic>> _allTransactions = [];
  bool _isLoading = false;
  String _searchText = '';
  String _selectedStatusFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.client
          .from('gallon_transactions')
          .select('*, customer:customers!customer_id(id, name), sale_id')
          .order('created_at', ascending: false);

      _allTransactions = (List<Map<String, dynamic>>.from(result)).map((tx) {
        return {
          ...tx,
          'quantity': (tx['quantity'] as num?)?.toInt() ?? 0,
          'amount': (tx['amount'] as num?)?.toDouble() ?? 0.0,
          'status': (tx['status']?.toString().trim().toLowerCase()) ?? 'unpaid',
          'created_at': tx['created_at'] ?? DateTime.now().toIso8601String(),
          'customer': tx['customer'] ?? {'id': 'unknown', 'name': 'Unknown Customer'},
        };
      }).toList();
    } catch (e) {
      _showErrorSnackBar('Error loading transactions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filterTransactions() {
    return _allTransactions.where((tx) {
      if (_selectedStatusFilter != 'all' &&
          tx['status'] != _selectedStatusFilter) {
        return false;
      }

      final createdAt = DateTime.tryParse(tx['created_at']?.toString() ?? '');
      if (createdAt != null) {
        if (_startDate != null && createdAt.isBefore(_startDate!)) return false;
        if (_endDate != null && createdAt.isAfter(_endDate!)) return false;
      }

      final customerName = ((tx['customer'] as Map)['name'] ?? '')
          .toString()
          .toLowerCase();
      return customerName.contains(_searchText);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupByCustomer(
      List<Map<String, dynamic>> list) {
    return groupBy(list, (tx) => (tx['customer'] as Map)['id']?.toString() ?? '');
  }

  Future<void> _toggleStatus(Map<String, dynamic> transaction) async {
    final transactionId = transaction['id'].toString();
    final saleId = transaction['sale_id']?.toString();
    final currentStatus = transaction['status']?.toString().toLowerCase();

    if (currentStatus == 'paid' || saleId == null) {
      _showErrorSnackBar(currentStatus == 'paid'
          ? 'Already marked as paid'
          : 'Invalid sale ID');
      return;
    }

    try {
      await PaymentService.markAsPaid(
        saleId: saleId,
        gallonTransactionId: transactionId,
      );
      setState(() => transaction['status'] = 'paid');
      _showSuccessSnackBar('Marked as paid successfully!');
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _startDate != null && _endDate != null
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterTransactions();
    final grouped = _groupByCustomer(filteredList);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallon Transactions'),
        centerTitle: true,
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(grouped),
    );
  }

  Widget _buildMainContent(Map<String, List<Map<String, dynamic>>> grouped) {
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildFilterSection()),
          if (grouped.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No transactions found')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _CustomerGroupTile(
                      group: grouped.entries.elementAt(index),
                      onStatusToggle: _toggleStatus,
                    ),
                childCount: grouped.length),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSearchField(),
          const SizedBox(height: 16),
          _buildFilterControls(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search Customer',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
    );
  }

  Widget _buildFilterControls() {
    return Row(
      children: [
        Expanded(child: _buildStatusDropdown()),
        const SizedBox(width: 16),
        Expanded(child: _buildDateRangeSelector()),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatusFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All')),
            DropdownMenuItem(value: 'paid', child: Text('Paid')),
            DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
            DropdownMenuItem(value: 'deposit', child: Text('Deposit')),
          ],
          onChanged: (val) => setState(() => _selectedStatusFilter = val ?? 'all'),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Date Range',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: TextButton(
              onPressed: _selectDateRange,
              child: Text(
                _startDate != null && _endDate != null
                    ? '${DateFormat('MMM dd').format(_startDate!)} - '
                        '${DateFormat('MMM dd').format(_endDate!)}'
                    : 'Select Dates',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (_startDate != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () => setState(() {
                _startDate = null;
                _endDate = null;
              }),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _CustomerGroupTile extends StatelessWidget {
  final MapEntry<String, List<Map<String, dynamic>>> group;
  final Function(Map<String, dynamic>) onStatusToggle;

  const _CustomerGroupTile({
    required this.group,
    required this.onStatusToggle,
  });

  @override
  Widget build(BuildContext context) {
    final customer = group.value.first['customer'] as Map;
    final customerName = customer['name']?.toString() ?? 'Unknown Customer';
    final totalQty = group.value.fold<int>(0, (sum, tx) => sum + (tx['quantity'] as int));
    final totalAmt = group.value.fold<double>(0, (sum, tx) => sum + (tx['amount'] as double));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Icon(Icons.person_outline, size: 28),
        title: Text(
          customerName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: _buildSummary(totalQty, totalAmt),
        children: group.value.map((tx) => _TransactionItem(
          transaction: tx,
          onStatusToggle: () => onStatusToggle(tx),
        )).toList(),
      ),
    );
  }

  Widget _buildSummary(int qty, double amt) {
    return Row(
      children: [
        _SummaryChip(
          icon: Icons.water_drop,
          label: '$qty Gallons',
          color: Colors.blue.shade100,
        ),
        const SizedBox(width: 8),
        _SummaryChip(
          icon: Icons.attach_money,
          label: '\$${amt.toStringAsFixed(2)}',
          color: Colors.green.shade100,
        ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onStatusToggle;

  const _TransactionItem({
    required this.transaction,
    required this.onStatusToggle,
  });

  @override
  Widget build(BuildContext context) {
    final status = transaction['status']?.toString().toLowerCase() ?? 'unpaid';
    final isPaid = status == 'paid';
    final isDeposit = status == 'deposit';
    final date = DateTime.tryParse(transaction['created_at']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(
          isPaid ? Icons.check_circle : 
                  isDeposit ? Icons.account_balance_wallet : Icons.pending_actions,
          color: isPaid ? Colors.green : isDeposit ? Colors.purple : Colors.orange,
        ),
        title: Text(
          '${_capitalize(transaction['transaction_type']?.toString() ?? 'Transaction')}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd, y • h:mm a').format(date ?? DateTime.now()),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _InfoPill('Qty: ${transaction['quantity']}'),
                const SizedBox(width: 8),
                _InfoPill('Amt: \$${(transaction['amount'] as double).toStringAsFixed(2)}'),
              ],
            ),
          ],
        ),
        trailing: !isPaid && !isDeposit
            ? IconButton(
                icon: const Icon(Icons.payment, color: Colors.blue),
                onPressed: onStatusToggle,
              )
            : null,
      ),
    );
  }

  String _capitalize(String s) => s.isNotEmpty
      ? s[0].toUpperCase() + s.substring(1).toLowerCase()
      : s;
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color,
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;

  const _InfoPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
      )),
    );
  }
}