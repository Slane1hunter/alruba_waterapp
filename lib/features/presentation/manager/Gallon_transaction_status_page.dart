import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../../services/supabase_service.dart';

final _lbp = NumberFormat.currency(
  locale: 'ar_LB',
  symbol: 'ل.ل ',
  decimalDigits: 0,
);

class GallonTransactionStatusPage extends ConsumerStatefulWidget {
  const GallonTransactionStatusPage({super.key});

  @override
  ConsumerState<GallonTransactionStatusPage> createState() => _GallonTransactionStatusPageState();
}

class _GallonTransactionStatusPageState extends ConsumerState<GallonTransactionStatusPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  String _search = '';
  List<Map<String, dynamic>> _all = [];

  @override
  void initState() {
    super.initState();
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

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final rows = await SupabaseService.client.from('gallon_transactions').select('''
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
                'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
                'customer': m['customer'] ?? {'id': '?', 'name': 'مجهول'},
              })
          .where((m) => m['status'] == 'unpaid' || m['transaction_type'] == 'deposit')
          .toList();
    } catch (e) {
      _snack('خطأ في التحميل: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> get _byCustomer =>
      groupBy(_all.where((tx) {
        final name = (tx['customer']['name'] as String).toLowerCase();
        return name.contains(_search);
      }), (m) => m['customer']['id'] as String);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحركات المالية - جالون'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  SliverToBoxAdapter(child: _searchField()),
                  if (_byCustomer.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('لا توجد نتائج')),
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

  Widget _searchField() => Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            labelText: 'ابحث باسم الزبون',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Future<void> _markPaid(Map<String, dynamic> tx) async {
    if (tx['status'] == 'paid') {
      _snack('تم الدفع مسبقاً', Colors.orange);
      return;
    }
    if (tx['sale_id'] == null) {
      _snack('لا يوجد sale_id', Colors.red);
      return;
    }
    try {
      final updates = {
        'status': 'paid',
        if (tx['transaction_type'] == 'deposit') 'transaction_type': 'purchase'
      };

      await SupabaseService.client
          .from('gallon_transactions')
          .update(updates)
          .eq('id', tx['id']);

      setState(() {
        tx['status'] = 'paid';
        if (tx['transaction_type'] == 'deposit') {
          tx['transaction_type'] = 'purchase';
        }
      });

      _snack('تم تأكيد الدفع', Colors.green);
    } catch (e) {
      _snack('خطأ: $e', Colors.red);
    }
  }

  void _snack(String m, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile(this.entry, this.onPay);

  final MapEntry<String, List<Map<String, dynamic>>> entry;
  final void Function(Map<String, dynamic>) onPay;

  @override
  Widget build(BuildContext context) {
    final name = entry.value.first['customer']['name'] ?? 'مجهول';
    final qty = entry.value.fold<int>(0, (s, m) => s + (m['quantity'] as int));
    final amt = entry.value.fold<double>(0, (s, m) => s + (m['amount'] as double));

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
            _chip(Icons.water_drop, '$qty جالون'),
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

class _TxTile extends StatelessWidget {
  const _TxTile(this.tx, this.onPay);
  final Map<String, dynamic> tx;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final status = (tx['status'] as String).toLowerCase();
    final paid = status == 'paid';
    final dep = tx['transaction_type'] == 'deposit';
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
            _pill('الكمية: ${tx['quantity']}'),
            _pill('المبلغ: ${_lbp.format(tx['amount'])}'),
            _pill(DateFormat('MMM d • HH:mm', 'ar').format(dt)),
          ],
        ),
        trailing: !paid
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
        child: Text(t, style: const TextStyle(fontSize: 12)),
      );
}
