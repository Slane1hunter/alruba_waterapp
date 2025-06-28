import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';

/// Model representing a sale (with joined customer/product details)
class ManagerSale {
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
  final DateTime? paymentDate;

  ManagerSale({
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
    this.paymentDate,
  });

  factory ManagerSale.fromMap(Map<String, dynamic> m) {
    final customer   = m['customer'] as Map<String, dynamic>? ?? {};
    final locData    = customer['location'] as Map<String, dynamic>?;
    final product    = m['product'] as Map<String, dynamic>? ?? {};

    // parse payment_date
    DateTime? pd;
    final raw = m['payment_date'];
    if (raw != null) {
      pd = raw is String
          ? DateTime.parse(raw).toLocal()
          : (raw as DateTime).toLocal();
    }

    final qty   = (m['quantity'] as num?)?.toInt() ?? 0;
    final price = (m['price_per_unit'] as num?)?.toDouble() ?? 0.0;
    final tot   = (m['total_amount'] as num?)?.toDouble() ?? (qty * price);

    return ManagerSale(
      saleId:        m['id'] as String,
      date:          DateTime.parse(m['created_at'] as String).toLocal(),
      paymentDate:   pd,
      paymentStatus: (m['payment_status'] as String?)?.toLowerCase() ?? 'unknown',
      quantity:      qty,
      pricePerUnit:  price,
      totalAmount:   tot,
      productName:   product['name'] as String? ?? 'Unknown',
      customerName:  customer['name'] as String? ?? 'Unknown',
      phone:         customer['phone'] as String? ?? '',
      location:      locData?['name'] as String? ?? 'Unknown',
      preciseLocation: customer['precise_location'] as String?,
    );
  }
}

/// Fetches *all* sales (no user filter)
final managerSalesProvider =
    FutureProvider.autoDispose<List<ManagerSale>>((ref) async {
  final resp = await SupabaseService.client
      .from('sales')
      .select(r'''
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
      ''')
      .order('created_at', ascending: true);

  return (resp as List)
      .cast<Map<String, dynamic>>()
      .map((m) => ManagerSale.fromMap(m))
      .toList();
});
