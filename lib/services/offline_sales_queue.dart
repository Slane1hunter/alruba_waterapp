import 'package:hive/hive.dart';
import '../models/offline_sale.dart';

class OfflineSalesQueue {
  static const String salesBoxName = 'offline_sales'; // or 'sales_queue'

  /// Add a single OfflineSale to the local queue
  static Future<void> addSale(OfflineSale sale) async {
    final box = await Hive.openBox<OfflineSale>(salesBoxName);
    await box.add(sale);
  }

  /// Get all unsynced OfflineSales from the local queue
  static Future<List<OfflineSale>> getAllSales() async {
    final box = await Hive.openBox<OfflineSale>(salesBoxName);
    return box.values.toList();
  }
}
