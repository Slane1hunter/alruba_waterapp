import 'package:alruba_waterapp/models/offline_gallon_transaction.dart';
import 'package:alruba_waterapp/providers/customers_provider.dart';
import 'package:alruba_waterapp/providers/distributor_sales_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:alruba_waterapp/models/offline_sale.dart';
import 'package:alruba_waterapp/services/offline_sync_service.dart';

class SalesQueuePage extends ConsumerStatefulWidget {
  const SalesQueuePage({super.key});

  @override
  ConsumerState<SalesQueuePage> createState() => _SalesQueuePageState();
}

class _SalesQueuePageState extends ConsumerState<SalesQueuePage> {
  bool _isSyncing = false;

  // LBP currency formatter
  final _lbpFormat = NumberFormat.currency(
    locale: 'ar_LB',
    symbol: 'ل.ل',
    name: '',             // Prevent LPB from being added
    decimalDigits: 0,
    customPattern: '#,##0 ¤', // Number then currency
  );

  Future<void> _syncSales() async {
    setState(() {
      _isSyncing = true;
    });
    try {
      final salesBox = Hive.box<OfflineSale>('offline_sales');
      final List<OfflineSale> localSales = salesBox.values.toList();

      await OfflineSyncService().syncOfflineData();

      ref.invalidate(customersProvider);
      ref.invalidate(distributorSalesProvider);

      await salesBox.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت المزامنة بنجاح!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشلت المزامنة: $e')),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _clearQueue() async {
    final saleBox = Hive.box<OfflineSale>('offline_sales');
    await saleBox.clear();

    final txBox = await Hive.openBox<OfflineGallonTransaction>(
        'offline_gallon_transactions');
    await txBox.clear();

    if (!mounted) return;
    setState(() {});
  }

  void _showSaleDetails(OfflineSale sale) {
    final formattedDate =
        DateFormat('yyyy-MM-dd hh:mm a').format(sale.createdAt);
    final phoneNumber = sale.customerPhone ?? sale.newCustomerPhone ?? 'N/A';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            sale.customerName ?? 'عميل غير معروف',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الهاتف: $phoneNumber',
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 10),
                const Divider(thickness: 1.2),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المنتج: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(sale.productName ?? 'لا يوجد منتج')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('الكمية: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${sale.quantity}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('السعر لكل وحدة: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_lbpFormat.format(sale.pricePerUnit)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('الإجمالي: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_lbpFormat.format(sale.totalPrice)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('الدفع: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(sale.paymentStatus),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('تاريخ الإنشاء: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(formattedDate),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("قائمة مبيعات اليوم"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _isSyncing ? null : _syncSales,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.cloud_upload),
                    label:
                        Text(_isSyncing ? 'جارٍ المزامنة...' : 'مزامنة الكل'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          title: const Text('مسح القائمة'),
                          content: const Text(
                              'هل أنت متأكد من حذف جميع المبيعات غير المتزامنة؟'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('تأكيد'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await _clearQueue();
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('مسح الكل'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Box<OfflineSale>>(
              valueListenable:
                  Hive.box<OfflineSale>('offline_sales').listenable(),
              builder: (context, box, _) {
                final unsyncedSales = box.values.toList();
                if (unsyncedSales.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد مبيعات غير متزامنة!',
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: unsyncedSales.length,
                  itemBuilder: (context, index) {
                    final sale = unsyncedSales[index];
                    final customerLabel = sale.customerName ?? 'عميل غير معروف';
                    final productLabel = sale.productName ?? 'لا يوجد منتج';
                    return Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        leading: const Icon(Icons.pending_actions, size: 30),
                        title: Text(
                          customerLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('المنتج: $productLabel\n'
                            'الكمية: ${sale.quantity} | السعر: ${_lbpFormat.format(sale.pricePerUnit)}'),
                        trailing: Text(
                          _lbpFormat.format(sale.totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => _showSaleDetails(sale),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
