import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../models/offline_sale.dart';
import '../../../providers/customers_provider.dart';
import '../../../services/offline_sync_service.dart';

class SalesQueuePage extends ConsumerStatefulWidget {
  const SalesQueuePage({super.key});

  @override
  ConsumerState<SalesQueuePage> createState() => _SalesQueuePageState();
}

class _SalesQueuePageState extends ConsumerState<SalesQueuePage> {

  Future<void> _syncSales() async {
    // 1) Sync offline data
    await OfflineSyncService().syncOfflineData();

    // 2) Refresh the customers if needed
    ref.refresh(customersProvider);

    // 3) Clear the local queue
    final box = Hive.box<OfflineSale>('offline_sales');
    await box.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync completed!')),
    );
  }

  Future<void> _clearQueue() async {
    final box = Hive.box<OfflineSale>('offline_sales');
    await box.clear();

    if (!mounted) return;
    setState(() {}); // or rely on ValueListenableBuilder auto-update
  }

  /// Shows a pop-up with detailed sale information
  void _showSaleDetails(OfflineSale sale) {
    final formattedDate =
        DateFormat('yyyy-MM-dd hh:mm a').format(sale.createdAt);
    final phoneNumber = sale.customerPhone ?? sale.newCustomerPhone ?? 'N/A';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            sale.customerName ?? 'Unknown Customer',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone: $phoneNumber', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 10),
                const Divider(thickness: 1.2),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Product: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(sale.productName ?? 'No Product')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Quantity: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${sale.quantity}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Price/Unit: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${sale.pricePerUnit.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Total: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${sale.totalPrice.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Payment: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(sale.paymentStatus),
                  ],
                ),
                if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(sale.notes!),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Created At: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(formattedDate),
                  ],
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

  @override
  Widget build(BuildContext context) {
    // Instead of manually opening the box, rely on Hive.box<OfflineSale>('offline_sales') directly
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Sales Queue"),
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
                    onPressed: _syncSales,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Sync All'),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: const Text('Clear Queue'),
                          content: const Text('Are you sure you want to remove all unsynced sales?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await _clearQueue();
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear All'),
                  ),
                ),
              ],
            ),
          ),

          // Use ValueListenableBuilder to auto-update whenever offline_sales changes
          Expanded(
            child: ValueListenableBuilder<Box<OfflineSale>>(
              valueListenable: Hive.box<OfflineSale>('offline_sales').listenable(),
              builder: (context, box, _) {
                final unsyncedSales = box.values.toList();
                if (unsyncedSales.isEmpty) {
                  return const Center(
                    child: Text(
                      'No unsynced sales!',
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: unsyncedSales.length,
                  itemBuilder: (context, index) {
                    final sale = unsyncedSales[index];
                    final customerLabel = sale.customerName ?? 'Unknown Customer';
                    final productLabel = sale.productName ?? 'No Product';

                    return Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 10
                        ),
                        leading: const Icon(Icons.pending_actions, size: 30),
                        title: Text(
                          customerLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Product: $productLabel\n'
                          'Qty: ${sale.quantity} | \$${sale.pricePerUnit.toStringAsFixed(2)}',
                        ),
                        trailing: Text(
                          '\$${sale.totalPrice.toStringAsFixed(2)}',
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
