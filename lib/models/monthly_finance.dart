class MonthlyFinancials {
  final DateTime month;
  final double revenue;
  final double expenses;
  final double profit;

  MonthlyFinancials({
    required this.month,
    required this.revenue,
    required this.expenses,
    required this.profit,
  });

  factory MonthlyFinancials.fromJson(Map<String, dynamic> json) {
    return MonthlyFinancials(
      month: DateTime.parse(json['month']),
      revenue: (json['revenue'] as num).toDouble(),
      expenses: (json['expenses'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
    );
  }
}