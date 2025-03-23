import 'package:hive/hive.dart';

part 'offline_sale.g.dart';

@HiveType(typeId: 2)
class OfflineSale extends HiveObject {
  @HiveField(0)
  bool isNewCustomer;

  @HiveField(1)
  String? newCustomerPhone;

  @HiveField(2)
  String? existingCustomerId;

  @HiveField(3)
  String? customerName;

  @HiveField(4)
  String? productId;

  @HiveField(5)
  String? productName;

  @HiveField(6)
  double pricePerUnit;

  @HiveField(7)
  int quantity;

  @HiveField(8)
  double totalPrice;

  @HiveField(9)
  String paymentStatus;

  @HiveField(10)
  String? notes;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  String? customerPhone;

  // New required field for the sales table:
  @HiveField(13)
  String soldBy;

  // New field if you need it (for example, for location)
  @HiveField(14)
  String locationId;

  OfflineSale({
    required this.isNewCustomer,
    this.newCustomerPhone,
    this.existingCustomerId,
    this.customerName,
    this.productId,
    this.productName,
    required this.pricePerUnit,
    required this.quantity,
    required this.totalPrice,
    required this.paymentStatus,
    this.notes,
    required this.createdAt,
    this.customerPhone,
    required this.soldBy,
    required this.locationId,
  });
}
