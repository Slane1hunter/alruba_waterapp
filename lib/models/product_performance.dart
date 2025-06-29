// lib/models/product_performance.dart
class ProductPerformance {
  final String productName;
  final int unitsSold;
  final double totalRevenue;
  final double profit;

  ProductPerformance({
    required this.productName,
    required this.unitsSold,
    required this.totalRevenue,
    required this.profit,
  });

  factory ProductPerformance.fromJson(Map<String, dynamic> json) {
    return ProductPerformance(
      productName: json['name'] ?? 'Unknown Product',
      unitsSold: (json['units_sold'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}