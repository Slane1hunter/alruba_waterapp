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
  // Now you can use ref
  late Box<OfflineSale> salesBox;

  @override
  void initState() {
    super.initState();
    _initBox();
  }

  Future<void> _initBox() async {
    try {
      debugPrint('[SalesQueuePage] Opening offline_sales box...');
      salesBox = await Hive.openBox<OfflineSale>('offline_sales');
      debugPrint('[SalesQueuePage] Box opened successfully!');
    } catch (e, st) {
      debugPrint('[SalesQueuePage] Error opening box: $e');
      debugPrint('[SalesQueuePage] Stack: $st');
      // Optionally show an error UI here
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _syncSales() async {
    await OfflineSyncService().syncOfflineData();
    if (!mounted) return;
    ref.refresh(customersProvider);
    // After sync, clear the box
    await _clearQueue();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync completed!')),
    );
  }

  Future<void> _clearQueue() async {
    await salesBox.clear();
    setState(() {});
  }

  /// Show a styled pop-up (AlertDialog) with detailed sale information
  void _showSaleDetails(OfflineSale sale) {
    final formattedDate =
        DateFormat('yyyy-MM-dd hh:mm a').format(sale.createdAt);
    // Use customerPhone if available; otherwise use newCustomerPhone.
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
                Text(
                  'Phone: $phoneNumber',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                const Divider(thickness: 1.2),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(sale.productName ?? 'No Product'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Quantity: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('${sale.quantity}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Price/Unit: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('\$${sale.pricePerUnit.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Total: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('\$${sale.totalPrice.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Payment: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(sale.paymentStatus),
                  ],
                ),
                if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(sale.notes!),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Created At: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
    debugPrint(
        '[SalesQueuePage] build() called. Box open: ${Hive.isBoxOpen('offline_sales')}');

    if (!Hive.isBoxOpen('offline_sales')) {
      debugPrint('[SalesQueuePage] Box not open yet => show spinner');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final unsyncedSales = salesBox.values.toList();
    debugPrint(
        '[SalesQueuePage] unsyncedSales.length = ${unsyncedSales.length}');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Sales Queue"),
      ),
      body: Column(
        children: [
          // Row with two separate buttons for syncing and clearing the queue
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
          // List of unsynced sales
          Expanded(
            child: unsyncedSales.isEmpty
                ? const Center(
                    child: Text(
                      'No unsynced sales!',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : ListView.builder(
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
                  ),
          ),
        ],
      ),
    );
  }
}
