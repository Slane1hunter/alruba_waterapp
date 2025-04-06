import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';

/// Model representing a distributor sale with joined customer and product details.
class DistributorSale {
  final String saleId;
  final DateTime date;
  final String customerName;
  final String phone;
  final double totalPrice;
  final String location;
  final String? preciseLocation;
  final String productName;
  final int quantity;
  final double pricePerUnit;

  DistributorSale({
    required this.saleId,
    required this.date,
    required this.customerName,
    required this.phone,
    required this.totalPrice,
    required this.location,
    this.preciseLocation,
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
  });

  factory DistributorSale.fromMap(Map<String, dynamic> map) {
    // Extract customer information.
    final customer = map['customer'] as Map<String, dynamic>? ?? {};
    // Retrieve the joined location object from the customer.
    final locationData = customer['location'] as Map<String, dynamic>?;
    // Use the location name if available; otherwise default to 'Unknown'
    final locationName = locationData != null ? locationData['name'] as String? ?? 'Unknown' : 'Unknown';

    // Extract product info
    final product = map['product'] as Map<String, dynamic>? ?? {};

    return DistributorSale(
      saleId: map['id'] as String,
      date: DateTime.parse(map['created_at'] as String),
      customerName: customer['name'] as String? ?? 'Unknown',
      phone: customer['phone'] as String? ?? '',
      totalPrice: double.tryParse('${map['total_amount']}') ?? 0,
      location: locationName,
      preciseLocation: customer['precise_location'] as String?,
      productName: product['name'] as String? ?? 'No Product',
      quantity: map['quantity'] as int? ?? 0,
      pricePerUnit: double.tryParse('${map['price_per_unit']}') ?? 0,
    );
  }
}

/// Provider that fetches distributor sales with joined data.
final distributorSalesProvider = FutureProvider<List<DistributorSale>>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return [];

  // Updated query: we join the products and customers tables.
  // Notice: We use the join syntax to get the product name and customer details.
  // For the customer, we also join the locations table to fetch the actual location name.
  final response = await SupabaseService.client
      .from('sales')
      .select(
        'id, created_at, total_amount, quantity, price_per_unit, product_id, '
        'product:products(name), '
        'customer:customers(name, phone, precise_location, location:locations(name))',
      )
      .eq('sold_by', userId)
      .order('created_at', ascending: false);

  final sales = (response as List<dynamic>).map((item) {
    return DistributorSale.fromMap(item as Map<String, dynamic>);
  }).toList();

  return sales;
});
