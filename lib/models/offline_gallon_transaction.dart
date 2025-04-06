import 'package:hive/hive.dart';

part 'offline_gallon_transaction.g.dart';

@HiveType(typeId: 5) // pick a unique typeId
class OfflineGallonTransaction extends HiveObject {
  @HiveField(0)
  String? customerId;

  @HiveField(1)
  String? productId;

  @HiveField(2)
  int quantity; // + for deposit/purchase, - for return

  @HiveField(3)
  String transactionType; // 'deposit', 'return', 'purchase', etc.

  @HiveField(4)
  String? status; // 'paid', 'unpaid', 'deposit' etc.

  @HiveField(5)
  DateTime createdAt;

  OfflineGallonTransaction({
    this.customerId,
    this.productId,
    required this.quantity,
    required this.transactionType,
    this.status,
    required this.createdAt,
  });
}
