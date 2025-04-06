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

  @HiveField(13)
  String soldBy;

  @HiveField(14)
  String locationId;

  @HiveField(15)
  String? preciseLocation;

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
    this.preciseLocation,
  });
}
