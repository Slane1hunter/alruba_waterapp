import 'package:hive/hive.dart';

part 'offline_sale.g.dart';

@HiveType(typeId: 2)
class OfflineSale extends HiveObject {
  /* ── persisted fields ───────────────────────────────────────────── */
  @HiveField(0)  bool   isNewCustomer;
  @HiveField(1)  String? newCustomerPhone;
  @HiveField(2)  String? existingCustomerId;
  @HiveField(3)  String? customerName;
  @HiveField(4)  String? productId;
  @HiveField(5)  String? productName;
  @HiveField(6)  double  pricePerUnit;
  @HiveField(7)  int     quantity;
  @HiveField(8)  double  totalPrice;
  @HiveField(9)  String  paymentStatus;           // "paid" | "unpaid"
  @HiveField(10) DateTime createdAt;
  @HiveField(11) String? customerPhone;
  @HiveField(12) String  soldBy;                  // Supabase user-id
  @HiveField(13) String  locationId;              // UUID from locations table
  @HiveField(15) String? localSaleId;                      // offline-generated UUID

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
    required this.createdAt,
    this.customerPhone,
    required this.soldBy,
    required this.locationId,
    required this.localSaleId,
  });

  /* ───────────────────────────────────────────────────────────────── */
  /// Optional helper if you ever store the *text* of the location
  /// (kept null for now because you only persist `locationId`)
  String? get locationName => null;

  /* ───────────────────────────────────────────────────────────────── */
  Map<String, dynamic> toJson() => {
        'id'                    : localSaleId,
        'isNewCustomer'        : isNewCustomer,
        'new_customer_phone'   : newCustomerPhone,
        'existing_customer_id' : existingCustomerId,
        'customer_name'        : customerName,
        'product_id'           : productId,
        'product_name'         : productName,
        'price_per_unit'       : pricePerUnit,
        'quantity'             : quantity,
        'total_amount'         : totalPrice,
        'payment_status'       : paymentStatus,
        'created_at'           : createdAt.toIso8601String(),
        'customer_phone'       : customerPhone,
        'sold_by'              : soldBy,
        'location_id'          : locationId,
      };

  @override
  String toString() => '''
OfflineSale(
  id:               $localSaleId
  isNewCustomer:    $isNewCustomer
  customerName:     $customerName
  newCustomerPhone: $newCustomerPhone
  existingCustomer: $existingCustomerId
  productId/name:   $productId / $productName
  quantity:         $quantity
  pricePerUnit:     $pricePerUnit
  totalPrice:       $totalPrice
  paymentStatus:    $paymentStatus
  createdAt:        $createdAt
  soldBy:           $soldBy
  locationId:       $locationId
)''';
}
