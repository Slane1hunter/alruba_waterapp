import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/offline_gallon_transaction.dart';

class OfflineGallonQueue {
  static const String gallonBoxName = 'offline_gallon_transactions';
  static Box<OfflineGallonTransaction>? _box;

  static Future<Box<OfflineGallonTransaction>> getBox() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<OfflineGallonTransaction>(gallonBoxName);
      debugPrint("[OfflineGallonQueue] Box opened with length: ${_box!.length}");
    }
    return _box!;
  }

  static Future<void> addTransaction(OfflineGallonTransaction tx) async {
    final box = await getBox();
    await box.put(tx.localTxId,tx);
    debugPrint("[OfflineGallonQueue] Added transaction. New length: ${box.length}");
  }

  static Future<List<OfflineGallonTransaction>> getAllTransactions() async {
    final box = await getBox();
    return box.values.toList();
  }

  static Future<void> clearQueue() async {
    final box = await getBox();
    await box.clear();
    debugPrint("[OfflineGallonQueue] Cleared transaction queue.");
  }
}
