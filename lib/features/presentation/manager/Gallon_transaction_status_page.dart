// GallonTransactionStatusPage: Full, working logic with no reliance on Supabase foreign key relationships

import 'package:alruba_waterapp/services/gallon_payment-service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../../services/supabase_service.dart';

final _lbp =
    NumberFormat.currency(locale: 'ar_LB', symbol: 'ل.ل ', decimalDigits: 0);

class GallonTransactionStatusPage extends ConsumerStatefulWidget {
  const GallonTransactionStatusPage({super.key});

  @override
  ConsumerState<GallonTransactionStatusPage> createState() =>
      _GallonTransactionStatusPageState();
}

class _GallonTransactionStatusPageState
    extends ConsumerState<GallonTransactionStatusPage> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String _search = '';
  List<Map<String, dynamic>> _transactions = [];
  Map<String, Map<String, dynamic>> _customers = {};
  Map<String, Map<String, dynamic>> _products = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
    _searchCtrl.addListener(
        () => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
  setState(() => _loading = true);
  try {
    final txs = await SupabaseService.client
        .from('gallon_transactions')
        .select('*')
        .order('created_at', ascending: false);

    final customerIds = txs.map((t) => t['customer_id'] as String).toSet().toList();
    final productIds = txs.map((t) => t['product_id'] as String).toSet().toList();
    final saleIds = txs.map((t) => t['sale_id'] as String).toSet().toList();

    final customerList = await SupabaseService.client
        .from('customers')
        .select('id, name')
        .inFilter('id', customerIds);

    final productList = await SupabaseService.client
        .from('products')
        .select('id, name')
        .inFilter('id', productIds);

    // Fetch sales to get location_id per sale_id
    final salesList = await SupabaseService.client
        .from('sales')
        .select('id, location_id')
        .inFilter('id', saleIds);

    final salesMap = {for (var s in salesList) s['id']: s['location_id']};

    _customers = {for (var c in customerList) c['id']: c};
    _products = {for (var p in productList) p['id']: p};

    _transactions = txs
        .map((tx) => {
              ...tx,
              'customer': _customers[tx['customer_id']],
              'product': _products[tx['product_id']],
              'location_id': salesMap[tx['sale_id']],  // attach location_id here
            })
        .toList();
  } catch (e) {
    _snack('خطأ أثناء التحميل: $e', Colors.red);
  } finally {
    setState(() => _loading = false);
  }
}


  Map<String, List<Map<String, dynamic>>> get _grouped => groupBy(
        _transactions.where(
            (t) => t['transaction_type'] == 'deposit' && !t['is_settled']),
        (t) => t['customer_id'] as String,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة جالونات الإيداع')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(top: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        labelText: 'ابحث باسم الزبون',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_grouped.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('لا توجد نتائج'),
                      ),
                    )
                  else
                    ..._grouped.entries.map((entry) {
                      final customerId = entry.key;
                      final customer = _customers[customerId];
                      final txs = entry.value;
                      final totalQty = txs.fold<int>(
                          0, (sum, tx) => sum + (tx['quantity'] as int));
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          title: Text(customer?['name'] ?? 'مجهول'),
                          subtitle: Text('الرصيد: $totalQty جالون'),
                          children: [
                            for (final tx in txs) _txTile(tx),
                          ],
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _txTile(Map<String, dynamic> tx) {
    final dt = DateTime.tryParse(tx['created_at'])?.toLocal();
    final qty = tx['quantity'] as int;
    final product = tx['product']?['name'] ?? 'غير معروف';
    return ListTile(
      title: Text('منتج: $product - $qty جالون'),
      subtitle: Text(
          'تم في: ${dt != null ? DateFormat('yyyy-MM-dd – HH:mm').format(dt) : '?'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.money, color: Colors.green),
            onPressed: () => _confirmAction(tx, 'pay'),
          ),
          IconButton(
            icon: const Icon(Icons.reply, color: Colors.orange),
            onPressed: () => _confirmAction(tx, 'return'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAction(Map<String, dynamic> tx, String action) async {
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) =>
          _QuantityDialog(maxQuantity: tx['quantity'], action: action),
    );

    if (qty == null) return;

    if (qty <= 0 || qty > tx['quantity']) {
      _snack('كمية غير صالحة', Colors.red);
      return;
    }

    try {
      final remaining = tx['quantity'] - qty;

      if (action == 'pay') {
        final pricePerUnit =
            (tx['amount'] as num?) != null && (tx['quantity'] as int) > 0
                ? (tx['amount'] as num) / tx['quantity']
                : 0;
        final locationId = tx['location_id'];
        if (locationId == null) {
          _snack('خطأ: مكان البيع غير معروف (location_id فارغ)', Colors.red);
          return;
        }

        await payForDeposit(
          context: context,
          customerId: tx['customer_id'],
          productId: tx['product_id'],
          quantity: qty,
          pricePerUnit: pricePerUnit.toDouble(),
          linkedDepositSaleId: tx['sale_id'],
          locationId: (tx['location_id'] ??
              'eab70b1a-310d-4115-80ac-bf93c09f3cdd') as String,
        );
      } else {
        await SupabaseService.client.from('gallon_transactions').insert({
          'customer_id': tx['customer_id'],
          'product_id': tx['product_id'],
          'quantity': qty,
          'transaction_type': 'return',
          'status': 'paid',
          'amount': 0,
          'sale_id': tx['sale_id'],
          'created_at': DateTime.now().toIso8601String(),
          'is_settled': false,
        });
      }

      if (remaining > 0) {
        await SupabaseService.client
            .from('gallon_transactions')
            .update({'quantity': remaining}).eq('id', tx['id']);
      } else {
        await SupabaseService.client
            .from('gallon_transactions')
            .update({'is_settled': true}).eq('id', tx['id']);
      }

      _snack('تم تنفيذ العملية بنجاح', Colors.green);
      _fetch();
    } catch (e) {
      _snack('فشل في تنفيذ العملية: $e', Colors.red);
    }
  }

  void _snack(String m, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }
}

class _QuantityDialog extends StatefulWidget {
  final int maxQuantity;
  final String action;
  const _QuantityDialog({required this.maxQuantity, required this.action});

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  int qty = 1;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.action == 'pay' ? 'دفع جالونات' : 'إرجاع جالونات'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () => setState(() => qty = (qty > 1) ? qty - 1 : qty)),
          Text('$qty', style: const TextStyle(fontSize: 20)),
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => setState(
                  () => qty = (qty < widget.maxQuantity) ? qty + 1 : qty)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, qty),
            child: const Text('تأكيد')),
      ],
    );
  }
}
