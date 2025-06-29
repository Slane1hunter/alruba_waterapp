// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:intl/intl.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// /// مزود بيانات كل المبيعات مرتبة حسب تاريخ الإنشاء نزولاً
// final allSalesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
//   final response = await Supabase.instance.client
//       .from('sales')
//       .select('*')
//       .order('created_at', ascending: false); // ترتيب حسب عمود الوقت بشكل تنازلي
//   return List<Map<String, dynamic>>.from(response);
// });

// /// صفحة لوحة تحكم المالك التي تعرض ملخص المبيعات اليوم والمبيعات حسب الموزع
// class OwnerDashboardPage2 extends ConsumerWidget {
//   const OwnerDashboardPage2({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final salesAsync = ref.watch(allSalesProvider);
//     final lbp = NumberFormat.currency(locale: 'en_US', symbol: 'LBP ', decimalDigits: 0);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('لوحة تحكم المالك'),
//         backgroundColor: Colors.blue.shade800,
//       ),
//       body: salesAsync.when(
//         loading: () => const Center(child: CircularProgressIndicator()),
//         error: (e, _) => Center(child: Text('خطأ: $e')),
//         data: (sales) {
//           final now = DateTime.now();

//           // تصفية مبيعات اليوم فقط
//           final todaySales = sales.where((s) {
//             final created = DateTime.tryParse(s['created_at'] ?? '')?.toLocal();
//             return created != null &&
//                 created.year == now.year &&
//                 created.month == now.month &&
//                 created.day == now.day;
//           }).toList();

//           // حساب إجمالي الإيرادات من المبيعات المدفوعة فقط
//           final totalRevenue = todaySales
//               .where((s) => s['payment_status'] == 'paid')
//               .fold<double>(0, (sum, s) => sum + (s['total_amount'] as num).toDouble());

//           // تجميع المبيعات حسب معرف الموزع
//           final distributorMap = <String, List<Map<String, dynamic>>>{};
//           for (final s in todaySales) {
//             final distributor = s['sold_by'] ?? 'Unknown';
//             distributorMap.putIfAbsent(distributor, () => []).add(s);
//           }

//           return ListView(
//             padding: const EdgeInsets.all(16),
//             children: [
//               // بطاقة عرض إجمالي الإيرادات اليوم
//               Card(
//                 elevation: 4,
//                 color: Colors.blue.shade50,
//                 child: ListTile(
//                   title: const Text('إجمالي الإيرادات اليوم', style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: Text(
//                     lbp.format(totalRevenue),
//                     style: TextStyle(fontSize: 20, color: Colors.green.shade700),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),

//               // عنوان مبيعات حسب الموزع
//               const Text('المبيعات حسب الموزع:',
//                   style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
//               const SizedBox(height: 8),

//               // قائمة الموزعين مع ملخص مبيعاتهم
//               ...distributorMap.entries.map((entry) {
//                 final distributorId = entry.key;
//                 final sales = entry.value;
//                 final total = sales.fold<double>(
//                     0, (sum, s) => sum + (s['total_amount'] as num).toDouble());

//                 return Card(
//                   elevation: 2,
//                   child: ListTile(
//                     title: Text('معرف المستخدم: $distributorId'),
//                     subtitle: Text('${sales.length} مبيعات - ${lbp.format(total)}'),
//                     trailing: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blue.shade800,
//                         foregroundColor: Colors.white,
//                       ),
//                       child: const Text('عرض'),
//                       onPressed: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (_) => DistributorSalesBreakdownPage(
//                               distributorId: distributorId,
//                               sales: sales,
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }

// /// صفحة عرض تفاصيل المبيعات لموزع معين
// class DistributorSalesBreakdownPage extends StatelessWidget {
//   final String distributorId;
//   final List<Map<String, dynamic>> sales;

//   const DistributorSalesBreakdownPage({
//     super.key,
//     required this.distributorId,
//     required this.sales,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final lbp = NumberFormat.currency(locale: 'en_US', symbol: 'LBP ', decimalDigits: 0);

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('مبيعات $distributorId'),
//         backgroundColor: Colors.blue.shade800,
//       ),
//       body: ListView.builder(
//         padding: const EdgeInsets.all(16),
//         itemCount: sales.length,
//         itemBuilder: (context, index) {
//           final s = sales[index];
//           final dateStr = s['created_at'];
//           final date = DateTime.tryParse(dateStr ?? '')?.toLocal();

//           return Card(
//             child: ListTile(
//               title: Text('${s['product_name']} ×${s['quantity']}'),
//               subtitle: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text('الإجمالي: ${lbp.format(s['total_amount'])}'),
//                   if (date != null)
//                     Text(DateFormat('MMM dd, yyyy - hh:mm a').format(date))
//                   else
//                     const Text('تاريخ غير صالح'),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
