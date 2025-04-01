import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import '../models/offline_sale.dart';

class OfflineSyncService {
  static const String offlineSalesBoxName = 'offline_sales';
  static const String localCustomersBoxName = 'offline_customers';

  final SupabaseClient client = Supabase.instance.client;

  // Helper to supply a default location id (replace with an actual valid UUID from your DB)
  String _defaultLocationId() {
    return '17c1cb39-7b97-494b-be85-bae7290cd54c';
  }

  Future<void> syncOfflineData() async {
    debugPrint("[OfflineSyncService] Starting syncOfflineData");

    // 1) Sync local new customers stored offline.
    final customerBox = await Hive.openBox<Customer>(localCustomersBoxName);
    for (final key in customerBox.keys) {
      final localCustomer = customerBox.get(key);
      if (localCustomer == null) continue;
      debugPrint("[OfflineSyncService] Syncing customer: ${localCustomer.phone}");
      try {
        // Check if this phone number is already in the remote 'customers' table.
        final checkResponse = await client
            .from('customers')
            .select('id')
            .eq('phone', localCustomer.phone)
            .maybeSingle();

        if (checkResponse == null || (checkResponse.isEmpty)) {
          // Customer does not exist remotely – insert new customer.
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
            debugPrint("[OfflineSyncService] Customer inserted with id: $newId");
            await customerBox.delete(key);
          } else {
            debugPrint("[OfflineSyncService] Error: Customer insert returned empty");
            continue; // Skip syncing sale if customer not inserted
          }
        } else {
          // Customer exists; save the remote ID.
          final existingId = (checkResponse as Map)['id'] as String;
          localCustomer.remoteId = existingId;
          debugPrint("[OfflineSyncService] Customer exists with id: $existingId");
          await customerBox.delete(key);
        }
      } catch (e) {
        debugPrint("[OfflineSyncService] Error syncing customer: $e");
      }
    }

    // 2) Now sync local offline sales.
    final salesBox = await Hive.openBox<OfflineSale>(offlineSalesBoxName);
    for (final key in salesBox.keys) {
      final offSale = salesBox.get(key);
      if (offSale == null) continue;

      try {
        // For new customers: if the remote customer ID isn't set, try lookup by phone.
       // In the loop that syncs offline sales:
if (offSale.isNewCustomer &&
    (offSale.existingCustomerId == null || offSale.existingCustomerId!.isEmpty)) {
  final phone = offSale.newCustomerPhone;
  if (phone != null && phone.isNotEmpty) {
    final custResponse = await client
        .from('customers')
        .select('id')
        .eq('phone', phone)
        .maybeSingle();
    if (custResponse != null && custResponse.isNotEmpty) {
      offSale.existingCustomerId = (custResponse as Map)['id'] as String;
      debugPrint("[OfflineSyncService] Found remote customer ID: ${offSale.existingCustomerId} for phone: $phone");
    } else {
      // New change: Insert a new customer record using offline sale info
      final insertedCustomer = await client.from('customers').insert({
        'name': offSale.customerName,
        'phone': offSale.newCustomerPhone,
        'type': 'regular', // or use an appropriate value
        'assigned_to': client.auth.currentUser?.id,
        'location_id': offSale.locationId,
        'precise_location': offSale.preciseLocation,
      }).maybeSingle();
      if (insertedCustomer != null && insertedCustomer.isNotEmpty) {
        offSale.existingCustomerId = insertedCustomer['id'] as String;
        debugPrint("[OfflineSyncService] Inserted remote new customer with id: ${offSale.existingCustomerId}");
      } else {
        debugPrint("[OfflineSyncService] Failed to insert remote new customer. Skipping sale sync.");
        continue; // Skip syncing this sale until the customer exists remotely
      }
    }
  }
}


        debugPrint("[OfflineSyncService] Inserting sale with customer_id: ${offSale.existingCustomerId}, "
            "product_id: ${offSale.productId}, quantity: ${offSale.quantity}, "
            "price_per_unit: ${offSale.pricePerUnit}, payment_status: ${offSale.paymentStatus.toLowerCase()}, "
            "sold_by: ${offSale.soldBy ?? client.auth.currentUser?.id}, "
            "location_id: ${offSale.locationId ?? _defaultLocationId()}, "
            "created_at: ${offSale.createdAt.toIso8601String()}");

        // Insert the sale into the remote 'sales' table.
        final saleInserted = await client.from('sales').insert({
          'customer_id': offSale.existingCustomerId,
          'product_id': offSale.productId,
          'quantity': offSale.quantity,
          'price_per_unit': offSale.pricePerUnit,
          'payment_status': offSale.paymentStatus.toLowerCase(),
          'sold_by': offSale.soldBy ?? client.auth.currentUser?.id,
          'location_id': offSale.locationId ?? _defaultLocationId(),
          'created_at': offSale.createdAt.toIso8601String(),
        }).maybeSingle();

        if (saleInserted != null && saleInserted.isNotEmpty) {
          debugPrint("[OfflineSyncService] Sale inserted successfully with id: ${saleInserted['id']}");
          // Remove the sale from the local queue.
          await salesBox.delete(key);
        } else {
          debugPrint("[OfflineSyncService] Error: Sale insert returned empty or null.");
        }
      } catch (e) {
        debugPrint("[OfflineSyncService] Error syncing sale: $e");
      }
    }
  }
}
