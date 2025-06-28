import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alruba_waterapp/features/presentation/distrubutor/sale_form.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/distributor_sales_page.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/sales_queue_page.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/distrubutor_profile_page.dart';

import 'package:alruba_waterapp/providers/distributor_sales_provider.dart'
    show DistributorSale, distributorSalesProvider;

const _primaryGradient = LinearGradient(
  colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class DistributorHomePage extends ConsumerStatefulWidget {
  const DistributorHomePage({super.key});

  @override
  ConsumerState<DistributorHomePage> createState() =>
      _DistributorHomePageState();
}

class _DistributorHomePageState extends ConsumerState<DistributorHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributor Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 22,
              letterSpacing: 0.5,
            )),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _primaryGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(distributorSalesProvider),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardTab(),
          DistributorSalesPage(),
          SalesQueuePage(),
          DistributorProfilePage(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MakeSalePage()),
          );
          ref.invalidate(distributorSalesProvider);
        },
        backgroundColor: Colors.blue.shade800,
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 16,
        padding: EdgeInsets.zero,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            gradient: _primaryGradient,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade900.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTabButton(Icons.dashboard_outlined, 0),
              _buildTabButton(Icons.list_alt_outlined, 1),
              const SizedBox(width: 48),
              _buildTabButton(Icons.pending_actions_outlined, 2),
              _buildTabButton(Icons.person_outline, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(IconData icon, int index) => IconButton(
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _currentIndex == index
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              size: 28,
              color: _currentIndex == index
                  ? Colors.white
                  : Colors.white.withOpacity(0.7)),
        ),
        onPressed: () => setState(() => _currentIndex = index),
      );
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(distributorSalesProvider);
    final lbp = NumberFormat.currency(
        locale: 'en_US', symbol: 'LBP ', decimalDigits: 0);

    return salesAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: Colors.blue.shade800),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: TextStyle(color: Colors.red.shade800)),
      ),
      data: (allSales) {
        final now = DateTime.now();
        final createdToday = allSales.where((s) {
          final d = s.date.toLocal();
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();
        final collectedToday = allSales.where((s) {
          final p = s.paymentDate?.toLocal();
          if (p == null) return false;
          return p.year == now.year && p.month == now.month && p.day == now.day;
        }).toList();
        final depositsToday =
            createdToday.where((s) => s.paymentStatus == 'deposit').toList();
        final outstanding =
            allSales.where((s) => s.paymentStatus == 'unpaid').toList();
        final revenueToday = createdToday
            .where((s) => s.paymentStatus == 'paid')
            .fold<double>(0, (sum, s) => sum + s.totalAmount);
        final depositTaken =
            depositsToday.fold<double>(0, (sum, s) => sum + s.totalAmount);
        final cashInToday =
            collectedToday.fold<double>(0, (sum, s) => sum + s.totalAmount);
        final outstandingTotal =
            outstanding.fold<double>(0, (sum, s) => sum + s.totalAmount);
        final itemsSoldMap = <String, int>{};
        for (final s in createdToday) {
          itemsSoldMap[s.productName] =
              (itemsSoldMap[s.productName] ?? 0) + s.quantity;
        }
        final oweMap = <String, double>{};
        for (final s in outstanding) {
          oweMap[s.customerName] =
              (oweMap[s.customerName] ?? 0) + s.totalAmount;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryCard(
                title: "Today's Orders",
                children: [
                  'Total orders: ${createdToday.length}',
                  'Upfront paid: ${lbp.format(revenueToday)}',
                  'Deposits: ${lbp.format(depositTaken)}',
                ],
              ),
              const SizedBox(height: 16),
              _SummaryCard(
                title: "Items Sold Today",
                children: itemsSoldMap.entries.map((e) {
                  final product = e.key;
                  final total = e.value;
                  final paidCount = createdToday
                      .where((s) =>
                          s.productName == product && s.paymentStatus == 'paid')
                      .fold<int>(0, (sum, s) => sum + s.quantity);
                  final depositCount = createdToday
                      .where((s) =>
                          s.productName == product &&
                          s.paymentStatus == 'deposit')
                      .fold<int>(0, (sum, s) => sum + s.quantity);
                  final unpaidCount = createdToday
                      .where((s) =>
                          s.productName == product &&
                          s.paymentStatus == 'unpaid')
                      .fold<int>(0, (sum, s) => sum + s.quantity);

                  return '• $product: total $total '
                      '(paid: $paidCount, deposit: $depositCount, unpaid: $unpaidCount)';
                }).toList(),
              ),
              const SizedBox(height: 16),
              _SummaryCard(
                title: "Today's Cash Flow",
                children: [
                  'Total collected: ${lbp.format(cashInToday)}',
                  ' • on new orders: ${lbp.format(revenueToday)}',
                  ' • on old orders: ${lbp.format(cashInToday - revenueToday)}',
                ],
              ),
              const SizedBox(height: 16),
              _SummaryCard(
                title: 'Receivables (Unpaid)',
                children: ['Total owed: ${lbp.format(outstandingTotal)}'],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Unpaid Customers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    )),
              ),
              const SizedBox(height: 8),
              if (oweMap.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No outstanding payments!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      )),
                )
              else
                ...oweMap.entries.map((e) => _UnpaidCustomerCard(
                      entry: e,
                      allSales: allSales,
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final List<String> children;

  const _SummaryCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF8F9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                        letterSpacing: 0.3,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Icon(Icons.circle, size: 8, color: Colors.blue.shade300),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(line,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade800,
                              height: 1.4,
                            )),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _UnpaidCustomerCard extends StatelessWidget {
  final MapEntry<String, double> entry;
  final List<DistributorSale> allSales;

  const _UnpaidCustomerCard({
    required this.entry,
    required this.allSales,
  });

  @override
  Widget build(BuildContext context) {
    final lbp = NumberFormat.currency(
        locale: 'en_US', symbol: 'LBP ', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child:
              Icon(Icons.person_outline, size: 24, color: Colors.blue.shade800),
        ),
        title: Text(entry.key,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            )),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Owes: ${lbp.format(entry.value)}',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              )),
        ),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.attach_money, size: 18),
          label: const Text('Collect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            elevation: 2,
          ),
          onPressed: () {
            final unpaidSales = allSales
                .where((s) =>
                    s.customerName == entry.key && s.paymentStatus == 'unpaid')
                .toList();
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _UnpaidSalesPage(
                      customerName: entry.key,
                      sales: unpaidSales,
                    )));
          },
        ),
      ),
    );
  }
}

class _UnpaidSalesPage extends ConsumerWidget {
  final String customerName;
  final List<DistributorSale> sales;

  const _UnpaidSalesPage({
    required this.customerName,
    required this.sales,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lbp = NumberFormat.currency(
        locale: 'en_US', symbol: 'LBP ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Unpaid: $customerName'),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: _primaryGradient)),
      ),
      body: sales.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sales.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final s = sales[i];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.inventory_2_outlined,
                          size: 22, color: Colors.orange.shade800),
                    ),
                    title: Text('${s.productName} x${s.quantity}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          'Total: ${lbp.format(s.totalAmount)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy - hh:mm a')
                              .format(s.date.toLocal()),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final msg = ScaffoldMessenger.of(context);

                        try {
                          // Update the sale payment status
                          final updatedSale = await Supabase.instance.client
                              .from('sales')
                              .update({'payment_status': 'paid'})
                              .eq('id', s.saleId)
                              .select();

                          if (updatedSale.isEmpty) {
                            msg.showSnackBar(const SnackBar(
                                content: Text('No sale updated.')));
                            return;
                          }

                          // Also update related gallon transactions
                          await Supabase.instance.client
                              .from('gallon_transactions')
                              .update({'status' : 'paid', 'transaction_type' : 'purchase'}).eq(
                                  'sale_id', s.saleId);
                        } on PostgrestException catch (err) {
                          msg.showSnackBar(SnackBar(
                              content: Text('Update failed: ${err.message}')));
                          return;
                        } catch (err) {
                          msg.showSnackBar(
                              SnackBar(content: Text('Unexpected: $err')));
                          return;
                        }

                        ref.invalidate(distributorSalesProvider);
                        msg.showSnackBar(
                            const SnackBar(content: Text('Payment recorded!')));
                        nav.pop();
                      },
                      child: const Text('Mark Paid'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text('All payments collected!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      );
}
