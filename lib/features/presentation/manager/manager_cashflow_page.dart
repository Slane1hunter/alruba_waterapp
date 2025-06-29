import 'package:alruba_waterapp/providers/manager_slaes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// Page showing today's cash flow summary for all sales (manager view) - Arabic version
class ManagerCashflowPage extends ConsumerWidget {
  const ManagerCashflowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(managerSalesProvider);
    final lbp = NumberFormat.currency(locale: 'ar_LB', symbol: 'ل.ل ', decimalDigits: 0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("التدفق النقدي اليومي"),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () {
            ref.invalidate(managerSalesProvider);
            return Future.value();
          },
          child: salesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => const Center(
              child: Text('حدث خطأ في تحميل البيانات', style: TextStyle(color: Colors.red)),
            ),
            data: (allSales) {
              final now = DateTime.now();
              final todaySales = allSales.where((s) {
                final d = s.date.toLocal();
                return d.year == now.year && d.month == now.month && d.day == now.day;
              }).toList();

              final paidSales = todaySales.where((s) => s.paymentStatus == 'paid');
              final depositSales = todaySales.where((s) => s.paymentStatus == 'deposit');
              final collectedToday = allSales.where((s) {
                final p = s.paymentDate?.toLocal();
                return p != null && p.year == now.year && p.month == now.month && p.day == now.day;
              });
              final unpaidSales = allSales.where((s) => s.paymentStatus == 'unpaid');

              final revenue = paidSales.fold<double>(0, (sum, s) => sum + s.totalAmount);
              final depositTotal = depositSales.fold<double>(0, (sum, s) => sum + s.totalAmount);
              final cashIn = collectedToday.fold<double>(0, (sum, s) => sum + s.totalAmount);
              final owedTotal = unpaidSales.fold<double>(0, (sum, s) => sum + s.totalAmount);

              final itemsSold = <String, int>{};
              for (var s in todaySales) {
                itemsSold[s.productName] = (itemsSold[s.productName] ?? 0) + s.quantity;
              }

              final oweMap = <String, double>{};
              for (var s in unpaidSales) {
                oweMap[s.customerName] = (oweMap[s.customerName] ?? 0) + s.totalAmount;
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 3,
                          children: [
                            _InfoCard(
                              icon: Icons.shopping_cart_outlined,
                              title: "طلبات اليوم",
                              stats: [
                                'الإجمالي: ${todaySales.length}',
                                'المدفوع: ${lbp.format(revenue)}',
                                'العربون: ${lbp.format(depositTotal)}',
                              ],
                            ),
                            _InfoCard(
                              icon: Icons.attach_money_outlined,
                              title: 'التدفق النقدي',
                              stats: [
                                'المحصل: ${lbp.format(cashIn)}',
                                'الجديد: ${lbp.format(revenue)}',
                                'السابق: ${lbp.format(cashIn - revenue)}',
                              ],
                            ),
                            _InfoCard(
                              icon: Icons.receipt_long_outlined,
                              title: 'المستحقات',
                              stats: ['المديونية: ${lbp.format(owedTotal)}'],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('المنتجات المباعة اليوم', style: Theme.of(context).textTheme.titleLarge),
                        const Divider(thickness: 1.5),
                        ...itemsSold.entries.map((e) {
                          final total = e.value;
                          final paid = todaySales
                              .where((s) => s.productName == e.key && s.paymentStatus == 'paid')
                              .fold<int>(0, (sum, s) => sum + s.quantity);
                          final depo = todaySales
                              .where((s) => s.productName == e.key && s.paymentStatus == 'deposit')
                              .fold<int>(0, (sum, s) => sum + s.quantity);
                          final unp = todaySales
                              .where((s) => s.productName == e.key && s.paymentStatus == 'unpaid')
                              .fold<int>(0, (sum, s) => sum + s.quantity);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: ListTile(
                              leading: Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.primary),
                              title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('الإجمالي $total • المدفوع $paid • العربون $depo • غير مدفوع $unp'),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        Text('العملاء غير المدفوعين', style: Theme.of(context).textTheme.titleLarge),
                        const Divider(thickness: 1.5),
                        if (oweMap.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: Text('لا يوجد', style: TextStyle(fontSize: 16))),
                          ),
                        ...oweMap.entries.map((e) => Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                trailing: Text(lbp.format(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            )),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> stats;
  const _InfoCard({required this.icon, required this.title, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...stats.map((s) => Text(s, style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}