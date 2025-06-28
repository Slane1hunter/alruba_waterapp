import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final allSalesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('sales')
      .select('*')
      .order('created_at', ascending: false); // ✅ Use correct column
  return List<Map<String, dynamic>>.from(response);
});

class OwnerDashboardPage2 extends ConsumerWidget {
  const OwnerDashboardPage2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(allSalesProvider);
    final lbp = NumberFormat.currency(locale: 'en_US', symbol: 'LBP ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sales) {
          final now = DateTime.now();
          final todaySales = sales.where((s) {
            final created = DateTime.tryParse(s['created_at'] ?? '')?.toLocal();
            return created != null &&
                created.year == now.year &&
                created.month == now.month &&
                created.day == now.day;
          }).toList();

          final totalRevenue = todaySales
              .where((s) => s['payment_status'] == 'paid')
              .fold<double>(0, (sum, s) => sum + (s['total_amount'] as num).toDouble());

          final distributorMap = <String, List<Map<String, dynamic>>>{};
          for (final s in todaySales) {
            final distributor = s['sold_by'] ?? 'Unknown';
            distributorMap.putIfAbsent(distributor, () => []).add(s);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 4,
                color: Colors.blue.shade50,
                child: ListTile(
                  title: const Text('Total Revenue Today', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    lbp.format(totalRevenue),
                    style: TextStyle(fontSize: 20, color: Colors.green.shade700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Sales by Distributor:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 8),
              ...distributorMap.entries.map((entry) {
                final distributorId = entry.key;
                final sales = entry.value;
                final total = sales.fold<double>(
                    0, (sum, s) => sum + (s['total_amount'] as num).toDouble());

                return Card(
                  elevation: 2,
                  child: ListTile(
                    title: Text('User ID: $distributorId'),
                    subtitle: Text('${sales.length} sales - ${lbp.format(total)}'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('View'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DistributorSalesBreakdownPage(
                              distributorId: distributorId,
                              sales: sales,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}

class DistributorSalesBreakdownPage extends StatelessWidget {
  final String distributorId;
  final List<Map<String, dynamic>> sales;

  const DistributorSalesBreakdownPage({
    super.key,
    required this.distributorId,
    required this.sales,
  });

  @override
  Widget build(BuildContext context) {
    final lbp = NumberFormat.currency(locale: 'en_US', symbol: 'LBP ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sales by $distributorId'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sales.length,
        itemBuilder: (context, index) {
          final s = sales[index];
          final dateStr = s['created_at'];
          final date = DateTime.tryParse(dateStr ?? '')?.toLocal();

          return Card(
            child: ListTile(
              title: Text('${s['product_name']} x${s['quantity']}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total: ${lbp.format(s['total_amount'])}'),
                  if (date != null)
                    Text(DateFormat('MMM dd, yyyy - hh:mm a').format(date))
                  else
                    const Text('Invalid date'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
