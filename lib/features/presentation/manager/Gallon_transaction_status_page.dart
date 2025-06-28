import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../../services/supabase_service.dart';

/*──────────────────────────────────────────*/
/*  CURRENCY: Lebanese Pounds (no decimals) */
/*──────────────────────────────────────────*/
final _lbp = NumberFormat.currency(
  locale: 'ar_LB',
  symbol: 'LBP ',
  decimalDigits: 0,
);

/*──────────────────────────────────────────*/
/*  MAIN PAGE                               */
/*──────────────────────────────────────────*/
class GallonTransactionStatusPage extends ConsumerStatefulWidget {
  const GallonTransactionStatusPage({super.key});

  @override
  ConsumerState<GallonTransactionStatusPage> createState() =>
      _GallonTransactionStatusPageState();
}

class _GallonTransactionStatusPageState
    extends ConsumerState<GallonTransactionStatusPage> {
  /* UI state */
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int get _totalGallons =>
      _all.fold<int>(0, (sum, tx) => sum + (tx['quantity'] as int));

  bool _loading = true;
  String _search = '';
  String _status = 'all'; // all | paid | unpaid | deposit
  DateTime? _start;
  DateTime? _end;

  List<Map<String, dynamic>> _all = [];

  /*────────────────── init / dispose ──────────────────*/
  @override
  void initState() {
    super.initState();
    // Wait until the widget tree has built once before hitting Supabase.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /*────────────────── Supabase fetch ──────────────────*/
  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final rows =
          await SupabaseService.client.from('gallon_transactions').select('''
            id,
            sale_id,
            customer_id,
            quantity,
            amount,
            status,
            transaction_type,
            created_at,
            customer:customers(id,name)
          ''').order('created_at', ascending: false);

      _all = List<Map<String, dynamic>>.from(rows)
          .map((m) => {
                ...m,
                'quantity': (m['quantity'] as num?)?.toInt() ?? 0,
                'amount': (m['amount'] as num?)?.toDouble() ?? 0.0,
                'status': (m['status']?.toString().toLowerCase() ?? 'unpaid'),
                'created_at':
                    m['created_at'] ?? DateTime.now().toIso8601String(),
                'customer': m['customer'] ?? {'id': '?', 'name': 'Unknown'},
              })
          .toList();
    } catch (e) {
      _snack('Error loading: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /*────────────────── filtering / grouping ─────────────*/
  List<Map<String, dynamic>> get _filtered => _all.where((tx) {
        // status
        if (_status != 'all' && tx['status'] != _status) return false;

        // date-range (inclusive)
        final dt = DateTime.tryParse(tx['created_at'])?.toLocal();
        if (dt != null) {
          if (_start != null && dt.isBefore(_start!)) return false;

          if (_end != null) {
            final endInclusive = DateTime(_end!.year, _end!.month, _end!.day)
                .add(const Duration(days: 1));
            if (dt.isAfter(endInclusive)) return false;
          }
        }

        // search
        final cust = (tx['customer']['name'] as String).toLowerCase();
        return cust.contains(_search);
      }).toList();

  Map<String, List<Map<String, dynamic>>> get _byCustomer =>
      groupBy(_filtered, (m) => m['customer']['id'] as String);

  /*────────────────── build ────────────────────────────*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallon Transactions'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Chip(
              label: Text('Total $_totalGallons gal'),
              avatar: const Icon(Icons.water_drop, size: 16),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  SliverToBoxAdapter(child: _filters(context)),
                  if (_byCustomer.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No transactions found')),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final e = _byCustomer.entries.elementAt(i);
                          return _CustomerTile(e, _markPaid);
                        },
                        childCount: _byCustomer.length,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /*────────────────── filters panel ───────────────────*/
  Widget _filters(BuildContext ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Search customer',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statusDrop(ctx)),
                const SizedBox(width: 12),
                Expanded(child: _datePick(ctx)),
              ],
            ),
          ],
        ),
      );

  InputDecoration _dec(String lbl) => InputDecoration(
        labelText: lbl,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      );

  Widget _statusDrop(BuildContext ctx) => InputDecorator(
        decoration: _dec('Status'),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _status,
            onChanged: (v) => setState(() => _status = v ?? 'all'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'paid', child: Text('Paid')),
              DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
              DropdownMenuItem(value: 'deposit', child: Text('Deposit')),
            ],
          ),
        ),
      );

  Widget _datePick(BuildContext ctx) {
    final txt = (_start != null && _end != null)
        ? '${DateFormat('MMM d').format(_start!)} – '
            '${DateFormat('MMM d').format(_end!)}'
        : 'Select dates';

    return InputDecorator(
      decoration: _dec('Date range'),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              onPressed: _pickDates,
              child: Text(txt, overflow: TextOverflow.ellipsis),
            ),
          ),
          if (_start != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () => setState(() {
                _start = null;
                _end = null;
              }),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDateRange: (_start != null && _end != null)
          ? DateTimeRange(start: _start!, end: _end!)
          : null,
    );
    if (range != null) {
      setState(() {
        _start = range.start;
        _end = range.end;
      });
    }
  }

  /*────────────────── mark as paid ────────────────────*/
  /*────────────────── mark as paid ────────────────────*/
  Future<void> _markPaid(Map<String, dynamic> tx) async {
    if (tx['status'] == 'paid') {
      _snack('Already paid', Colors.orange);
      return;
    }
    if (tx['sale_id'] == null) {
      _snack('Missing sale id', Colors.red);
      return;
    }

    try {
      // Update both status and transaction type if needed
      final updates = {
        'status': 'paid',
        if (tx['transaction_type'] == 'deposit') 'transaction_type': 'purchase'
      };

      await SupabaseService.client
          .from('gallon_transactions')
          .update(updates)
          .eq('id', tx['id']);

      // Update local state
      setState(() {
        tx['status'] = 'paid';
        if (tx['transaction_type'] == 'deposit') {
          tx['transaction_type'] = 'purchase';
        }
      });

      _snack('Marked as paid', Colors.green);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}

/*────────────────── customer tile ───────────────────*/
class _CustomerTile extends StatelessWidget {
  const _CustomerTile(this.entry, this.onPay);

  final MapEntry<String, List<Map<String, dynamic>>> entry;
  final void Function(Map<String, dynamic>) onPay;

  @override
  Widget build(BuildContext context) {
    final name = entry.value.first['customer']['name'] ?? 'Unknown';

    final qty = entry.value.fold<int>(0, (s, m) => s + (m['quantity'] as int));
    final amt =
        entry.value.fold<double>(0, (s, m) => s + (m['amount'] as double));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Icon(Icons.person_outline),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Wrap(
          spacing: 8,
          children: [
            _chip(Icons.water_drop, '$qty Gal'),
            _chip(Icons.attach_money, _lbp.format(amt)),
          ],
        ),
        children: [
          for (final tx in entry.value) _TxTile(tx, () => onPay(tx)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Chip _chip(IconData ic, String t) => Chip(
        avatar: Icon(ic, size: 16),
        label: Text(t, overflow: TextOverflow.ellipsis),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      );
}

/*────────────────── single tx tile ───────────────────*/
class _TxTile extends StatelessWidget {
  const _TxTile(this.tx, this.onPay);
  final Map<String, dynamic> tx;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final status = (tx['status'] as String).toLowerCase();
    final paid = status == 'paid';
    final dep = status == 'deposit';
    final dt = DateTime.tryParse(tx['created_at'])?.toLocal() ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: Icon(
          paid
              ? Icons.check_circle
              : dep
                  ? Icons.account_balance_wallet
                  : Icons.pending_actions,
          color: paid
              ? Colors.green
              : dep
                  ? Colors.purple
                  : Colors.orange,
        ),
        title: Text(_cap(tx['transaction_type'])),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _pill('Qty: ${tx['quantity']}'),
            _pill('Amt: ${_lbp.format(tx['amount'])}'),
            _pill(DateFormat('MMM d • HH:mm').format(dt)),
          ],
        ),
        trailing: !paid // ← pay allowed for deposit & unpaid
            ? IconButton(
                icon: const Icon(Icons.payment, color: Colors.blue),
                onPressed: onPay,
              )
            : null,
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t,
            style:
                const TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis)),
      );
}
