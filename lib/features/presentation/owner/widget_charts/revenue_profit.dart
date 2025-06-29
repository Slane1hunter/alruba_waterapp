// // lib/widgets/financial/charts/profit_trend_chart.dart
// import 'package:alruba_waterapp/models/monthly_summary.dart';
// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:intl/intl.dart';

// class ProfitTrendChart extends StatelessWidget {
//   final List<MonthlySummary> monthlyData;
//   final NumberFormat currencyFormat;

//   const ProfitTrendChart({
//     super.key,
//     required this.monthlyData,
//     required this.currencyFormat,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             const Text('Monthly Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             SizedBox(
//               height: 200,
//               child: LineChart(
//                 LineChartData(
//                   gridData: const FlGridData(show: true),
//                   titlesData: FlTitlesData(
//                     bottomTitles: AxisTitles(
//                       sideTitles: SideTitles(
//                         showTitles: true,
//                         getTitlesWidget: (value, _) => Text(
//                           DateFormat('MMM').format(monthlyData[value.toInt()].month),
//                           style: const TextStyle(fontSize: 10),
//                         ),
//                       ),
//                     ),
//                     leftTitles: AxisTitles(
//                       sideTitles: SideTitles(
//                         showTitles: true,
//                         getTitlesWidget: (value, _) => Text(
//                           currencyFormat.format(value),
//                           style: const TextStyle(fontSize: 10),
//                         ),
//                       ),
//                     ),
//                   ),
//                   lineBarsData: [
//                     LineChartBarData(
//                       spots: monthlyData.asMap().entries.map((e) => 
//                         FlSpot(e.key.toDouble(), e.value.totalProfit)
//                       ).toList(),
//                       color: Colors.green,
//                       isCurved: true,
//                     ),
//                     LineChartBarData(
//                       spots: monthlyData.asMap().entries.map((e) => 
//                         FlSpot(e.key.toDouble(), e.value.totalExpenses)
//                       ).toList(),
//                       color: Colors.red,
//                       isCurved: true,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }