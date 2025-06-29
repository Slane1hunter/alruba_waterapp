import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';

/// Model representing a distributor sale with joined customer and product details
class DistributorSale {
  final String saleId;
  final DateTime date;
  final String paymentStatus;
  final int quantity;
  final double pricePerUnit;
  final double totalAmount;
  final String productName;
  final String customerName;
  final String phone;
  final String location;
  final String? preciseLocation;
  final DateTime? paymentDate; // ← new

  DistributorSale({
    required this.saleId,
    required this.date,
    required this.paymentStatus,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.productName,
    required this.customerName,
    required this.phone,
    required this.location,
    this.preciseLocation,
    this.paymentDate, // ← new
  });

  factory DistributorSale.fromMap(Map<String, dynamic> map) {
    final customer = map['customer'] as Map<String, dynamic>? ?? {};
    final locationData = customer['location'] as Map<String, dynamic>?;

    final product = map['product'] as Map<String, dynamic>? ?? {};

    // parse payment_date safely
    final rawPd = map['payment_date'];
    DateTime? pd;
    if (rawPd != null) {
      if (rawPd is String) {
        pd = DateTime.parse(rawPd).toLocal();
      } else if (rawPd is DateTime) {
        pd = rawPd.toLocal();
      }
    }

    return DistributorSale(
      saleId: map['id'] as String,
      date: DateTime.parse(map['created_at'] as String),
      paymentDate: pd, // ← new
      paymentStatus:
          (map['payment_status'] as String?)?.toLowerCase() ?? 'unknown',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      pricePerUnit: (map['price_per_unit'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble()
          // fall back: qty * unit price
          ??
          ((map['quantity'] as num?)?.toInt() ?? 0) *
              ((map['price_per_unit'] as num?)?.toDouble() ?? 0.0),
      productName: product['name'] as String? ?? 'Unknown Item',
      customerName: customer['name'] as String? ?? 'Unknown',
      phone: customer['phone'] as String? ?? '',
      location: locationData?['name'] as String? ?? 'Unknown',
      preciseLocation: customer['precise_location'] as String?,
    );
  }
}

/// Provider that fetches distributor sales with joined data
final distributorSalesProvider =
    FutureProvider.autoDispose<List<DistributorSale>>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await SupabaseService.client.from('sales').select(r'''
        id,
        created_at,
        payment_date,
        payment_status,
        quantity,
        price_per_unit,
        total_amount,
        product:products!fk_sales_product(name),
        customer:customers!fk_sales_customer(
          name,
          phone,
          precise_location,
          location:locations(name)
        )
      ''').eq('sold_by', userId).order('created_at', ascending: true);
  return response
      .cast<Map<String, dynamic>>()
      .map((m) => DistributorSale.fromMap(m))
      .toList();
});
