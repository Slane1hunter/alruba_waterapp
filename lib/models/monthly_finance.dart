import 'package:intl/intl.dart';

class MonthlyFinancial {
  final DateTime month;
  final double revenue;
  final double totalCogs;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final double grossMarginPct;
  final double netMarginPct;

  MonthlyFinancial({
    required this.month,
    required this.revenue,
    required this.totalCogs,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.grossMarginPct,
    required this.netMarginPct,
  });

  factory MonthlyFinancial.fromMap(Map<String, dynamic> m) => MonthlyFinancial(
        month: DateTime.parse(m['month'] as String),
        revenue: (m['revenue'] as num).toDouble(),
        totalCogs: (m['total_cogs'] as num).toDouble(),
        grossProfit: (m['gross_profit'] as num).toDouble(),
        expenses: (m['expenses'] as num).toDouble(),
        netProfit: (m['net_profit'] as num).toDouble(),
        grossMarginPct: (m['gross_margin_pct'] as num).toDouble(),
        netMarginPct: (m['net_margin_pct'] as num).toDouble(),
      );

  String get monthLabel => DateFormat.yMMM().format(month);
  String get revenueFormatted => NumberFormat.simpleCurrency().format(revenue);
  String get expensesFormatted => NumberFormat.simpleCurrency().format(expenses);
  String get profitFormatted => NumberFormat.simpleCurrency().format(netProfit);
}
