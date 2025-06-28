class DailyProfit {
  final DateTime date;
  final double revenue;
  final double productionCost;
  final double profit;

  DailyProfit({
    required this.date,
    required this.revenue,
    required this.productionCost,
    required this.profit,
  });

  factory DailyProfit.fromJson(Map<String, dynamic> json) {
    return DailyProfit(
      date: DateTime.parse(json['date']),
      revenue: (json['daily_revenue'] as num).toDouble(),
      productionCost: (json['production_cost'] as num).toDouble(),
      profit: (json['daily_profit'] as num).toDouble(),
    );
  }
}