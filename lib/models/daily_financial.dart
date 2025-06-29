//import 'package:flutter/foundation.dart';

class DailyFinancial {
  final DateTime date;
  final double revenue;
  final double cogs;
  final double expenses;
  final double grossProfit;
  final double netProfit;

  DailyFinancial({
    required this.date,
    required this.revenue,
    required this.cogs,
    required this.expenses,
    required this.grossProfit,
    required this.netProfit,
  });

  factory DailyFinancial.fromMap(Map<String, dynamic> m) {
    return DailyFinancial(
      date: DateTime.parse(m['date'] as String),
      revenue: (m['revenue'] as num).toDouble(),
      cogs: (m['cogs'] as num).toDouble(),
      expenses: (m['expenses'] as num).toDouble(),
      grossProfit: (m['gross_profit'] as num).toDouble(),
      netProfit: (m['net_profit'] as num).toDouble(),
    );
  }
}
