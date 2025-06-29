// import 'package:alruba_waterapp/models/daily_profit.dart';
// import 'package:alruba_waterapp/models/expense_entry.dart';
// import 'package:alruba_waterapp/models/monthly_summary.dart';
// import 'package:alruba_waterapp/features/presentation/owner/widget_charts/month_section.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:alruba_waterapp/models/sold_item.dart';
// import 'package:alruba_waterapp/features/presentation/owner/widget_charts/sold_item_row.dart';

// class YearSection extends StatelessWidget {
//   final int year;
//   final List<MonthlySummary> monthlyData;
//   final List<DailyProfit> dailyProfits;
//   final List<ExpenseEntry> expenses;
//   final List<SoldItem> soldItems;
//   final NumberFormat currencyFormat;

//   const YearSection({
//     super.key,
//     required this.year,
//     required this.monthlyData,
//     required this.dailyProfits,
//     required this.expenses,
//     required this.soldItems,
//     required this.currencyFormat,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final yearSummaries = monthlyData.where((m) => m.month.year == year).toList();
//     final totalProfit = yearSummaries.fold(0.0, (sum, m) => sum + m.totalProfit);
//     final totalExpenses = yearSummaries.fold(0.0, (sum, m) => sum + m.totalExpenses);
//     final netBalance = totalProfit - totalExpenses;

//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       child: Card(
//         elevation: 4,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: ExpansionTile(
//           tilePadding: const EdgeInsets.symmetric(horizontal: 16),
//           leading: Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: Colors.blue.withAlpha(25),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(Icons.calendar_today, color: Colors.blue),
//           ),
//           title: Row(
//             children: [
//               Text(
//                 year.toString(),
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const Spacer(),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Text(
//                     currencyFormat.format(netBalance),
//                     style: TextStyle(
//                       color: netBalance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                   ),
//                   Text(
//                     'Yearly Balance',
//                     style: TextStyle(
//                       color: Colors.grey.shade600,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   _buildSummaryRow('Total Revenue', totalProfit, Colors.green),
//                   _buildSummaryRow('Total Expenses', totalExpenses, Colors.red),
//                   const SizedBox(height: 16),
//                   _buildSection('Yearly Sold Items', Icons.shopping_basket, Colors.purple, [
//                     SizedBox(
//                       height: 300,
//                       child: ListView.builder(
//                         itemCount: _getYearlySoldItems().length,
//                         itemBuilder: (context, index) => _getYearlySoldItems()[index],
//                       ),
//                     ),
//                   ]),
//                   ...yearSummaries.map((month) => MonthSection(
//                         monthSummary: month,
//                         dailyProfits: dailyProfits,
//                         expenses: expenses,
//                         soldItems: soldItems,
//                         currencyFormat: currencyFormat,
//                       )),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   List<Widget> _getYearlySoldItems() {
//     final yearlyItems = soldItems.where((item) => item.date.year == year).toList();
    
//     if (yearlyItems.isEmpty) {
//       return [
//         const ListTile(
//           title: Text('No items sold this year',
//             style: TextStyle(color: Colors.grey))
//         )
//       ];
//     }
    
//     return yearlyItems.map((item) => SoldItemRow(
//       item: item,
//       currencyFormat: currencyFormat,
//     )).toList();
//   }

//   Widget _buildSummaryRow(String label, double amount, Color color) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: Colors.grey.shade600,
//               fontSize: 14,
//             ),
//           ),
//           Text(
//             currencyFormat.format(amount),
//             style: TextStyle(
//               color: color,
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSection(
//       String title, IconData icon, Color color, List<Widget> children) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//           child: Row(
//             children: [
//               Icon(icon, color: color, size: 20),
//               const SizedBox(width: 8),
//               Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: color,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         ...children,
//       ],
//     );
//   }
// }