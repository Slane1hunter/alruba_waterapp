import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import '../models/offline_sale.dart';

// If you're tracking refillable containers offline:
import '../models/offline_gallon_transaction.dart';

class OfflineSyncService {
  static const String offlineSalesBoxName = 'offline_sales';
  static const String localCustomersBoxName = 'offline_customers';
  static const String offlineGallonTxBoxName = 'offline_gallon_transactions';

  final SupabaseClient client = Supabase.instance.client;

  String _defaultLocationId() {
    // Replace with a valid location ID from your DB if needed.
    return '17c1cb39-7b97-494b-be85-bae7290cd54c';
  }

  Future<void> syncOfflineData() async {
    debugPrint("[OfflineSyncService] Starting syncOfflineData");

    // 1) Sync local new customers stored offline
    await _syncLocalCustomers();

    // 2) Sync local offline sales
    await _syncOfflineSales();

    // 3) Sync container transactions for refillable items (if using them)
    await _syncGallonTransactions();
  }

  // ------------------------------------------------
  // Step 1: Sync offline customers
  // ------------------------------------------------
  Future<void> _syncLocalCustomers() async {
    final customerBox = await Hive.openBox<Customer>(localCustomersBoxName);

    for (final key in customerBox.keys) {
      final localCustomer = customerBox.get(key);
      if (localCustomer == null) continue;

      debugPrint(
          "[OfflineSyncService] Syncing customer: ${localCustomer.phone}");

      try {
        // Check if this phone already exists in 'customers'
        final checkResponse = await client
            .from('customers')
            .select('id')
            .eq('phone', localCustomer.phone)
            .maybeSingle();

        if (checkResponse == null || (checkResponse.isEmpty)) {
          // Insert a brand-new customer
          final insertedResponse = await client.from('customers').insert({
            'name': localCustomer.name,
            'phone': localCustomer.phone,
            'type': localCustomer.type,
            'assigned_to': client.auth.currentUser?.id,
            'location_id': localCustomer.locationId,
            'precise_location': localCustomer.preciseLocation,
          }).maybeSingle();

          if (insertedResponse != null && insertedResponse.isNotEmpty) {
            final newId = insertedResponse['id'] as String;
            localCustomer.remoteId = newId;
            debugPrint(
                "[OfflineSyncService] Customer inserted with id: $newId");
            await customerBox.delete(key);
          } else {
            debugPrint(
                "[OfflineSyncService] Error: Insert returned empty (customers).");
            continue;
          }
        } else {
          // Already exists; store the ID
          final existingId = (checkResponse as Map)['id'] as String;
          localCustomer.remoteId = existingId;
          debugPrint(
              "[OfflineSyncService] Customer exists with id: $existingId");
          await customerBox.delete(key);
        }
      } catch (e) {
        debugPrint("[OfflineSyncService] Error syncing customer: $e");
      }
    }
  }

  // ------------------------------------------------
  // Step 2: Sync offline sales
  // ------------------------------------------------
  Future<void> _syncOfflineSales() async {
    final salesBox = await Hive.openBox<OfflineSale>(offlineSalesBoxName);

    for (final key in salesBox.keys) {
      final offSale = salesBox.get(key);
      if (offSale == null) continue;

      try {
        // If new customer wasn't yet assigned a remote ID, attempt to find/insert them
        if (offSale.isNewCustomer &&
            (offSale.existingCustomerId == null ||
                offSale.existingCustomerId!.isEmpty)) {
          final phone = offSale.newCustomerPhone;
          if (phone != null && phone.isNotEmpty) {
            final custResponse = await client
                .from('customers')
                .select('id')
                .eq('phone', phone)
                .maybeSingle();

            if (custResponse != null && custResponse.isNotEmpty) {
              offSale.existingCustomerId =
                  (custResponse as Map)['id'] as String;
              debugPrint(
                  "[OfflineSyncService] Found remote customer ID: ${offSale.existingCustomerId} for phone: $phone");
            } else {
              // Insert new customer on the fly
              final insertedCustomer = await client.from('customers').insert({
                'name': offSale.customerName,
                'phone': offSale.newCustomerPhone,
                'type': 'regular',
                'assigned_to': client.auth.currentUser?.id,
                'location_id': offSale.locationId,
                'precise_location': offSale.preciseLocation,
              }).maybeSingle();

              if (insertedCustomer != null && insertedCustomer.isNotEmpty) {
                offSale.existingCustomerId = insertedCustomer['id'] as String;
                debugPrint(
                    "[OfflineSyncService] Inserted remote new customer with id: ${offSale.existingCustomerId}");
              } else {
                debugPrint(
                    "[OfflineSyncService] Failed to insert remote new customer. Skipping sale sync.");
                continue;
              }
            }
          }
        }

        debugPrint("[OfflineSyncService] Inserting sale with "
            "customer_id: ${offSale.existingCustomerId}, "
            "product_id: ${offSale.productId}, quantity: ${offSale.quantity}, "
            "price_per_unit: ${offSale.pricePerUnit}, payment_status: ${offSale.paymentStatus.toLowerCase()}, "
            "sold_by: ${offSale.soldBy ?? client.auth.currentUser?.id}, "
            "location_id: ${offSale.locationId ?? _defaultLocationId()}, "
            "created_at: ${offSale.createdAt.toIso8601String()}");

        // CHANGED: add .select('*') to ensure we get a non-empty response
        final saleInserted = await client
            .from('sales')
            .insert({
              'customer_id': offSale.existingCustomerId,
              'product_id': offSale.productId,
              'quantity': offSale.quantity,
              'price_per_unit': offSale.pricePerUnit,
              'payment_status': offSale.paymentStatus.toLowerCase(),
              'sold_by': offSale.soldBy,
              'location_id': offSale.locationId,
              'created_at': offSale.createdAt.toIso8601String(),
            })
            .select('*') // ensures we get the newly inserted row
            .maybeSingle();

        if (saleInserted != null && saleInserted.isNotEmpty) {
          debugPrint(
              "[OfflineSyncService] Sale inserted successfully with id: ${saleInserted['id']}");
          await salesBox.delete(key);
        } else {
          debugPrint(
              "[OfflineSyncService] Error: Sale insert returned empty or null.");
        }
      } catch (e) {
        debugPrint("[OfflineSyncService] Error syncing sale: $e");
      }
    }
  }

  // ------------------------------------------------
  // Step 3: Sync container transactions
  // ------------------------------------------------
 Future<void> _syncGallonTransactions() async {
  try {
    final containerBox = await Hive.openBox<OfflineGallonTransaction>('offline_gallon_transactions');

    for (final key in containerBox.keys) {
      final tx = containerBox.get(key);
      if (tx == null) continue;

      // 1) check for valid customer
      if (tx.customerId == null || tx.customerId!.isEmpty || tx.customerId == 'unknown') {
        debugPrint("[OfflineSyncService] Container TX has invalid customer. Skipping...");
        // Possibly do containerBox.delete(key) or continue
        continue;
      }

      debugPrint("[OfflineSyncService] Syncing container tx: $tx");
      try {
        final inserted = await client
            .from('gallon_transactions')
            .insert({
              'customer_id': tx.customerId,
              'product_id': tx.productId,
              'quantity': tx.quantity,
              'transaction_type': tx.transactionType,
              'status': tx.status,
              'created_at': tx.createdAt.toIso8601String(),
            })
            .select('*')
            .maybeSingle();

        if (inserted != null && inserted.isNotEmpty) {
          debugPrint("[OfflineSyncService] container tx inserted: ${inserted['id']}");
          await containerBox.delete(key); 
        } else {
          debugPrint("[OfflineSyncService] container tx insert returned empty");
        }
      } catch (e) {
        debugPrint("[OfflineSyncService] Error syncing container tx: $e");
      }
    }
  } catch (e) {
    debugPrint("[OfflineSyncService] Could not open offline_gallon_transactions box: $e");
  }
}

}
