import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import '../models/offline_sale.dart';

class OfflineSyncService {
  static const String offlineSalesBoxName = 'offline_sales';
  static const String localCustomersBoxName = 'offline_customers';

  final SupabaseClient client = Supabase.instance.client;

  Future<void> syncOfflineData() async {
    // 1) Sync local new customers stored offline.
    final customerBox = await Hive.openBox<Customer>(localCustomersBoxName);

    for (final key in customerBox.keys) {
      final localCustomer = customerBox.get(key);
      if (localCustomer == null) continue;

      try {
        // Check if this phone number is already in the remote 'customers' table.
        final checkData = await client
            .from('customers')
            .select('id')
            .eq('phone', localCustomer.phone)
            .maybeSingle();

        // If no matching customer is found, insert a new record.
        if (checkData == null || (checkData.isEmpty)) {
          final inserted = await client.from('customers').insert({
            'name': localCustomer.name,
            'phone': localCustomer.phone,
            'type': localCustomer.type,
            'location_id': localCustomer.locationId,
            'precise_location': localCustomer.preciseLocation,
          }).maybeSingle();

          if (inserted != null && (inserted.isNotEmpty)) {
            final newId = inserted['id'] as String;
            localCustomer.remoteId = newId;
            await customerBox.delete(key);
          }
        } else {
          // Customer already exists. Save the remote ID.
          final existingId = (checkData as Map)['id'] as String;
          localCustomer.remoteId = existingId;
          await customerBox.delete(key);
        }
      } catch (e) {
        debugPrint("Error syncing customer: $e");
      }
    }

    // 2) Now sync local offline sales.
    final salesBox = await Hive.openBox<OfflineSale>(offlineSalesBoxName);

    for (final key in salesBox.keys) {
      final offSale = salesBox.get(key);
      if (offSale == null) continue;

      try {
        // For new customers: if the remote customer ID isn't set, try to fetch it via phone lookup.
        if (offSale.isNewCustomer && offSale.existingCustomerId == null) {
          final phone = offSale.newCustomerPhone;
          if (phone != null && phone.isNotEmpty) {
            final custRow = await client
                .from('customers')
                .select('id')
                .eq('phone', phone)
                .maybeSingle();
            if (custRow != null && (custRow.isNotEmpty)) {
              offSale.existingCustomerId = custRow['id'] as String;
            } else {
              // If the customer isn't found, skip syncing this sale for now.
              continue;
            }
          }
        }
        String defaultLocationId() {
          // Replace with an actual valid location id from your locations table
          return '17c1cb39-7b97-494b-be85-bae7290cd54c';
        }

        // Insert the sale into the remote 'sales' table.
        final saleInserted = await client.from('sales').insert({
          'customer_id': offSale.existingCustomerId,
          'product_id': offSale.productId,
          'quantity': offSale.quantity,
          'price_per_unit': offSale.pricePerUnit,
          'payment_status': offSale.paymentStatus.toLowerCase(),
          'sold_by': offSale.soldBy,
          'location_id': offSale.locationId ??
              defaultLocationId(), // Must return valid uuid
          'created_at': offSale.createdAt.toIso8601String(),
        }).maybeSingle();

        if (saleInserted != null && (saleInserted.isNotEmpty)) {
          // Successfully inserted; remove the sale from the local queue.
          await salesBox.delete(key);
        }
      } catch (e) {
        debugPrint("Error syncing sale: $e");
      }
    }
  }
}
