// File: owner_unpaid_sales_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as show;
import 'package:alruba_waterapp/providers/manager_slaes_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerUnpaidSalesPage extends ConsumerStatefulWidget {
  const OwnerUnpaidSalesPage({super.key});

  @override
  ConsumerState<OwnerUnpaidSalesPage> createState() => _OwnerUnpaidSalesPageState();
}

class _OwnerUnpaidSalesPageState extends ConsumerState<OwnerUnpaidSalesPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final Map<String, TextEditingController> _paymentControllers = {};
  final Map<String, bool> _isProcessingMap = {};
  String? _globalErrorText;

  @override
  void dispose() {
    for (final controller in _paymentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _processPartialPayment(
    String customerName,
    List<ManagerSale> unpaidSales,
    double paymentAmount,
  ) async {
    setState(() {
      _isProcessingMap[customerName] = true;
      _globalErrorText = null;
    });

    try {
      double remainingPayment = paymentAmount;

      for (final sale in unpaidSales) {
        final double total = sale.totalAmount;
        final double paid = sale.amountPaid;
        final double balance = total - paid;

        if (balance <= 0) continue;

        double payNow = remainingPayment > balance ? balance : remainingPayment;
        remainingPayment -= payNow;

        double newAmountPaid = paid + payNow;
        String newStatus = newAmountPaid >= total ? 'paid' : 'partial';

        await _client
            .from('sales')
            .update({
              'amount_paid': newAmountPaid,
              'payment_status': newStatus,
              'payment_date': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', sale.saleId)
            .select();

        if (remainingPayment <= 0) break;
      }

      // Refresh provider after update
      ref.invalidate(managerSalesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت معالجة الدفعة للعميل $customerName بنجاح')),
      );
    } catch (e) {
      setState(() {
        _globalErrorText = 'حدث خطأ أثناء المعالجة: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingMap[customerName] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(managerSalesProvider);
    final lbp = show.NumberFormat.currency(locale: 'ar_LB', symbol: 'ل.ل ', decimalDigits: 0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المبيعات غير المدفوعة'),
          centerTitle: true,
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
          onRefresh: () async {
            ref.invalidate(managerSalesProvider);
          },
          child: salesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text('حدث خطأ: $err', style: const TextStyle(color: Colors.red)),
            ),
            data: (allSales) {
              final Map<String, List<ManagerSale>> salesByCustomer = {};
              for (final sale in allSales.where((s) =>
                  s.paymentStatus == 'unpaid' || s.paymentStatus == 'partial')) {
                salesByCustomer.putIfAbsent(sale.customerName, () => []).add(sale);
              }

              if (salesByCustomer.isEmpty) {
                return const Center(child: Text('لا توجد مبيعات غير مدفوعة'));
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: salesByCustomer.entries.map((entry) {
                  final customerName = entry.key;
                  final customerSales = entry.value;

                  _paymentControllers.putIfAbsent(customerName, () => TextEditingController());
                  _isProcessingMap.putIfAbsent(customerName, () => false);

                  final totalOwed = customerSales.fold<double>(
                    0,
                    (sum, sale) => sum + (sale.totalAmount - sale.amountPaid),
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      title: Text(
                        '$customerName - المجموع المستحق: ${lbp.format(totalOwed)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      children: [
                        ...customerSales.map((sale) {
                          final total = sale.totalAmount;
                          final paid = sale.amountPaid;
                          final balance = total - paid;
                          final saleDate = sale.date;
                          final formattedDate = saleDate != null
                              ? show.DateFormat('yyyy-MM-dd').format(saleDate.toLocal())
                              : '-';

                          return ListTile(
                            title: Text(sale.productName),
                            subtitle: Text(
                              'الكمية: ${sale.quantity} - المدفوع: ${lbp.format(paid)} - المتبقي: ${lbp.format(balance)}',
                            ),
                            trailing: Text(formattedDate),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: _paymentControllers[customerName],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'ادخل مبلغ الدفع لهذا العميل',
                              errorText: _globalErrorText,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ElevatedButton(
                            onPressed: _isProcessingMap[customerName]!
                                ? null
                                : () {
                                    final input = _paymentControllers[customerName]!.text.trim();
                                    if (input.isEmpty) {
                                      setState(() {
                                        _globalErrorText = 'الرجاء إدخال مبلغ الدفع';
                                      });
                                      return;
                                    }
                                    final paymentAmount = double.tryParse(input);
                                    if (paymentAmount == null || paymentAmount <= 0) {
                                      setState(() {
                                        _globalErrorText = 'الرجاء إدخال مبلغ صحيح أكبر من صفر';
                                      });
                                      return;
                                    }
                                    if (paymentAmount > totalOwed) {
                                      setState(() {
                                        _globalErrorText =
                                            'مبلغ الدفع أكبر من المجموع المستحق لهذا العميل';
                                      });
                                      return;
                                    }

                                    _processPartialPayment(customerName, customerSales, paymentAmount);
                                  },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: const Color(0xFF00695C),
                            ),
                            child: _isProcessingMap[customerName]!
                                ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                : const Text('دفع لهذا العميل'),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }
}
