// import 'package:alruba_waterapp/models/daily_financial.dart';
// import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:intl/intl.dart';

// class MonthlyFinanceCard extends StatelessWidget {
//   final MonthlyFinance data;
//   const MonthlyFinanceCard({super.key, required this.data});

//   @override
//   Widget build(BuildContext context) {
//     final nf = NumberFormat.compactSimpleCurrency(decimalDigits: 1);
//     final theme = Theme.of(context);

//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       elevation: 3,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             // ---- Header row (numbers) -----------------------------------
//             Row(
//               children: [
//                 _moneyTile('Revenue',    data.revenue,   theme.colorScheme.primary),
//                 _moneyTile('COGS',       data.cogs,      Colors.orange),
//                 _moneyTile('Expenses',   data.otherExp,  Colors.deepOrangeAccent),
//                 _moneyTile('Net',        data.netProfit,
//                             data.netProfit >= 0 ? Colors.green : Colors.red),
//               ],
//             ),
//             const SizedBox(height: 12),
//             // ---- Chart ---------------------------------------------------
//             SizedBox(
//               height: 220,
//               child: SfCartesianChart(
//                 primaryXAxis: CategoryAxis(isVisible: false),
//                 legend: Legend(isVisible: false),
//                 tooltipBehavior: TooltipBehavior(enable: true),
//                 series: <ChartSeries>[
//                   // stacked revenue bar (COGS part)
//                   StackedBarSeries<ChartPoint, String>(
//                     dataSource: [_toChartPoint(data, data.cogs)],
//                     xValueMapper: (cp, _) => cp.x,
//                     yValueMapper: (cp, _) => cp.y,
//                     color: Colors.orange.withOpacity(.8),
//                   ),
//                   // stacked revenue bar (Other Expenses part)
//                   StackedBarSeries<ChartPoint, String>(
//                     dataSource: [_toChartPoint(data, data.otherExp)],
//                     xValueMapper: (cp, _) => cp.x,
//                     yValueMapper: (cp, _) => cp.y,
//                     color: Colors.deepOrangeAccent.withOpacity(.8),
//                   ),
//                   // stacked revenue bar (Gross Profit part)
//                   StackedBarSeries<ChartPoint, String>(
//                     dataSource: [_toChartPoint(data, data.grossProfit)],
//                     xValueMapper: (cp, _) => cp.x,
//                     yValueMapper: (cp, _) => cp.y,
//                     color: theme.colorScheme.primary.withOpacity(.7),
//                   ),
//                   // net‑profit line on top
//                   LineSeries<ChartPoint, String>(
//                     dataSource: [_toChartPoint(data, data.netProfit)],
//                     xValueMapper: (cp, _) => cp.x,
//                     yValueMapper: (cp, _) => cp.y,
//                     color: data.netProfit >= 0 ? Colors.green : Colors.red,
//                     markerSettings: const MarkerSettings(isVisible: true),
//                   ),
//                 ],
//               ),
//             ),
//             Align(
//               alignment: Alignment.centerLeft,
//               child: Text(
//                 DateFormat.yMMM().format(data.month),
//                 style: theme.textTheme.titleMedium,
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _moneyTile(String label, double value, Color color) {
//     final nf = NumberFormat.compactSimpleCurrency(decimalDigits: 1);
//     return Expanded(
//       child: Column(
//         children: [
//           Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
//           const SizedBox(height: 4),
//           Text(nf.format(value),
//               style:
//                   TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }

//   // helper for chart
//   ChartPoint _toChartPoint(MonthlyFinance d, double y) =>
//       ChartPoint(DateFormat.MMM().format(d.month), y);
// }

// class ChartPoint {
//   final String x;
//   final double y;
//   ChartPoint(this.x, this.y);
// }
