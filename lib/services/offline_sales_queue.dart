import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/offline_sale.dart';

class OfflineSalesQueue {
  static const String salesBoxName = 'offline_sales';
  static Box<OfflineSale>? _box;

  static Future<Box<OfflineSale>> getBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<OfflineSale>(salesBoxName);
      debugPrint("[OfflineSalesQueue] Box opened with length: ${_box!.length}");
    }
    return _box!;
  }

  static Future<void> addSale(OfflineSale sale) async {
    final box = await getBox();
    await box.add(sale);
    debugPrint("[OfflineSalesQueue] Added sale. New box length: ${box.length}");
  }

  static Future<List<OfflineSale>> getAllSales() async {
    final box = await getBox();
    return box.values.toList();
  }

  static Future<void> clearQueue() async {
    final box = await getBox();
    await box.clear();
    debugPrint("[OfflineSalesQueue] Queue cleared.");
  }
}
