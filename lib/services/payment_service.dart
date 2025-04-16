import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PaymentService {
  static final SupabaseClient client = Supabase.instance.client;

  /// Marks both sale and gallon transaction as paid.
  static Future<void> markAsPaid({
    required String saleId,
    required String gallonTransactionId,
  }) async {
    try {
      // Update sale to paid
      await client.from('sales')
          .update({'payment_status': 'paid'})
          .eq('id', saleId);

      // Update gallon transaction to paid
      await client.from('gallon_transactions')
          .update({'status': 'paid'})
          .eq('id', gallonTransactionId);

      print("✅ Both sale and gallon transaction set to 'paid'.");
    } catch (e) {
      print("❌ Error marking as paid: $e");
      rethrow;
    }
  }

  /// OPTIONAL: Queue payments offline.
  static Future<void> queuePaymentOffline({
    required String saleId,
    required String gallonTransactionId,
  }) async {
    final offlinePaymentBox = await Hive.openBox('offline_payments');
    await offlinePaymentBox.add({
      'saleId': saleId,
      'gallonTransactionId': gallonTransactionId,
    });
    print("🟠 Payment queued offline.");
  }
}
