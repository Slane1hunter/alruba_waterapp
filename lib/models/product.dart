class Product {
  final String id;
  final String name;
  final double homePrice;
  final double marketPrice;
  final double productionCost;
  final bool isRefillable;

  Product({
    required this.id,
    required this.name,
    required this.homePrice,
    required this.marketPrice,
    required this.productionCost,
    required this.isRefillable,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      homePrice: (map['home_price'] as num).toDouble(),
      marketPrice: (map['market_price'] as num).toDouble(),
      productionCost: (map['production_cost'] as num).toDouble(),
      isRefillable: map['is_refillable'] ?? false,
    );
  }
}
