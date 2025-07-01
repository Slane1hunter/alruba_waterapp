// lib/services/gallon_payment_service.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // Add this if you haven't already

final supabase = Supabase.instance.client;
final _lbp = NumberFormat.currency(locale: 'ar_LB', symbol: 'ل.ل ', decimalDigits: 0);

Future<void> payForDeposit({
  required BuildContext context,
  required String customerId,
  required String productId,
  required int quantity,
  required double pricePerUnit,
  required String linkedDepositSaleId,
  required String locationId,
}) async {
  final totalAmount = quantity * pricePerUnit;
  final now = DateTime.now().toUtc();
  final saleId = const Uuid().v4();

  try {
    await supabase.from('sales').insert({
      'id': saleId,
      'customer_id': customerId,
      'product_id': productId,
      'quantity': quantity,
      'price_per_unit': pricePerUnit,
      'payment_status': 'paid',
      'sale_type': 'deposit_paid',
      'created_at': now.toIso8601String(),
      'payment_date': now.toIso8601String(),
      'note': 'Payment for deposit sale $linkedDepositSaleId',
      'linked_sale_id': linkedDepositSaleId,
      'location_id': locationId,
      'sold_by': Supabase.instance.client.auth.currentUser?.id,
    });

    await supabase.from('gallon_transactions').insert({
      'id': const Uuid().v4(),
      'customer_id': customerId,
      'product_id': productId,
      'quantity': quantity,
      'transaction_type': 'paid',
      'status': 'paid',
      'created_at': now.toIso8601String(),
      'amount': totalAmount,
      'sale_id': saleId,
      'is_settled': false,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الدفع بنجاح'), backgroundColor: Colors.green),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
    );
  }
}
