class DailySalesSummary {
  final DateTime day;
  final int revenue;
  final int cost;
  final int profit;

  DailySalesSummary({
    required this.day,
    required this.revenue,
    required this.cost,
    required this.profit,
  });

  factory DailySalesSummary.fromMap(Map<String, dynamic> m) {
    return DailySalesSummary(
      day: DateTime.parse(m['day'] as String),
      revenue: (m['revenue'] as num).toInt(),
      cost:    (m['cost']    as num).toInt(),
      profit:  (m['profit']  as num).toInt(),
    );
  }
}
