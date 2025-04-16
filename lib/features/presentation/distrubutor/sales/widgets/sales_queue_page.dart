import 'package:alruba_waterapp/models/offline_gallon_transaction.dart';
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

  Future<void> _syncSales() async {
    setState(() {
      _isSyncing = true;
    });
    try {
      // 1) Sync offline data (including customer, sale, and gallon transactions)
      await OfflineSyncService().syncOfflineData();

      // 3) Clear the offline sales box
      final salesBox = Hive.box<OfflineSale>('offline_sales');
      await salesBox.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync completed successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _clearQueue() async {
    // Clear both sales and gallon transactions
    final saleBox = Hive.box<OfflineSale>('offline_sales');
    await saleBox.clear();

    final txBox = await Hive.openBox<OfflineGallonTransaction>(
        'offline_gallon_transactions');
    await txBox.clear();

    if (!mounted) return;
    setState(() {});
  }

  /// Shows a detailed dialog for a sale.
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
            sale.customerName ?? 'Unknown Customer',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone: $phoneNumber',
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 10),
                const Divider(thickness: 1.2),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Product: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(sale.productName ?? 'No Product')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Quantity: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${sale.quantity}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Price/Unit: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${sale.pricePerUnit.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Total: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${sale.totalPrice.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Payment: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(sale.paymentStatus),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Created At: ',
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
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read unsynced sale count from Hive box
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Sales Queue"),
      ),
      body: Column(
        children: [
          // Sync and Clear buttons row
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
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync All'),
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
                          title: const Text('Clear Queue'),
                          content: const Text(
                              'Are you sure you want to remove all unsynced sales?'),
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
          // Unsynced sale count header
      
          // List of unsynced sales
          Expanded(
            child: ValueListenableBuilder<Box<OfflineSale>>(
              valueListenable:
                  Hive.box<OfflineSale>('offline_sales').listenable(),
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
                    final customerLabel =
                        sale.customerName ?? 'Unknown Customer';
                    final productLabel = sale.productName ?? 'No Product';
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
                        subtitle: Text(
                          'Product: $productLabel\nQty: ${sale.quantity} | \$${sale.pricePerUnit.toStringAsFixed(2)}',
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
