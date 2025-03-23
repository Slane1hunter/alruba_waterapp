import 'package:hive/hive.dart';

part 'customer.g.dart';

@HiveType(typeId: 2)
class Customer extends HiveObject {
  @HiveField(0)
  String? localId;   // local only, if you want

  @HiveField(1)
  String? remoteId;  // remote ID from Supabase after syncing

  @HiveField(2)
  String name;

  @HiveField(3)
  String phone; // assume unique phone constraint

  @HiveField(4)
  String type;  // 'normal', 'market', etc.

  @HiveField(5)
  String? locationId;

  @HiveField(6)
  String? preciseLocation;

  Customer({
    this.localId,
    this.remoteId,
    required this.name,
    required this.phone,
    required this.type,
    this.locationId,
    this.preciseLocation,
  });
}
