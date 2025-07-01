import 'package:hive/hive.dart';

part 'sale.g.dart'; // This is needed for hive_generator

@HiveType(typeId: 1) // unique typeId per model
class Sale extends HiveObject {
  @HiveField(0)
  String? localId;  // a local key if needed (or you can rely on the Hive key)

  @HiveField(1)
  String? remoteSaleId; // the remote ID from Supabase if it exists

  @HiveField(2)
  bool isNewCustomer;

  @HiveField(3)
  String? newCustomerPhone; // used if isNewCustomer == true

  @HiveField(4)
  String? customerId; // the remote customer ID if known

  @HiveField(5)
  String productId;

  @HiveField(6)
  double pricePerUnit;

  @HiveField(7)
  int quantity;

  @HiveField(8)
  double totalAmount;

  @HiveField(9)
  String paymentStatus;

  @HiveField(10)
  String soldBy;

  @HiveField(11)
  String? locationId;

  @HiveField(12)
  DateTime createdAt;

  @HiveField(13)
double amountPaid;

  // Constructor
  Sale({
    this.localId,
    this.remoteSaleId,
    required this.isNewCustomer,
    this.newCustomerPhone,
    this.customerId,
    required this.productId,
    required this.pricePerUnit,
    required this.quantity,
    required this.totalAmount,
    required this.paymentStatus,
    required this.soldBy,
    this.locationId,
    required this.createdAt,
    this.amountPaid = 0.0,
  });
}
