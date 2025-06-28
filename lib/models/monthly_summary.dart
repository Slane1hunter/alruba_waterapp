//import 'package:flutter/foundation.dart';

class MonthlySummary {
  final DateTime month;
  final double totalProfit;
  final double totalExpenses;
  final double netBalance;

  MonthlySummary({
    required this.month,
    required this.totalProfit,
    required this.totalExpenses,
    required this.netBalance,
  });

  factory MonthlySummary.fromMap(Map<String, dynamic> m) {
    return MonthlySummary(
      month: DateTime.parse(m['month'] as String),
      totalProfit: (m['total_profit'] as num).toDouble(),
      totalExpenses: (m['total_expenses'] as num).toDouble(),
      netBalance: (m['net_balance'] as num).toDouble(),
    );
  }
}
