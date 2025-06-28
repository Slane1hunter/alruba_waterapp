class SoldItem {
  final DateTime date;
  final String productName;
  final int quantity;
  final double pricePerUnit;
  final double total;

  SoldItem({
    required this.date,
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
    required this.total,
  });

 factory SoldItem.fromJson(Map<String, dynamic> json) {
  return SoldItem(
    date: DateTime.parse(json['created_at']),
    productName: json['product_name'] ?? 'Unknown Product',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0.0,
    total: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
  );
}
}