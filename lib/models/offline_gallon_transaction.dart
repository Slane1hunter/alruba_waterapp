import 'package:hive/hive.dart';

part 'offline_gallon_transaction.g.dart';

@HiveType(typeId: 5)
class OfflineGallonTransaction extends HiveObject {
  @HiveField(0)
  String? customerId;

  @HiveField(1)
  String? productId;

  @HiveField(2)
  int quantity;

  @HiveField(3)
  String transactionType;

  @HiveField(4)
  String? status;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  double amount;

  @HiveField(7) // 🔹 NEW FIELD
  String? saleId;

  OfflineGallonTransaction({
    this.customerId,
    this.productId,
    required this.quantity,
    required this.transactionType,
    this.status,
    required this.createdAt,
    required this.amount,
    this.saleId,
  });
}
