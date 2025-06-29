import 'package:hive/hive.dart';

part 'customer.g.dart';

@HiveType(typeId: 3)
class Customer extends HiveObject {
  // ---------------- database columns --------------
  @HiveField(0) String? remoteId;          // == Supabase id
  @HiveField(1) String  name;
  @HiveField(2) String  phone;
  @HiveField(3) String  type;              // 'regular' | 'distributor'
  @HiveField(4) String? locationId;        // FK -> locations.id
  @HiveField(5) String? preciseLocation;   // JSON string ({lat,lng})

  //-----------------------------------------------
  Customer({
    this.remoteId,
    required this.name,
    required this.phone,
    required this.type,
    this.locationId,
    this.preciseLocation,
  });

  /* ---------- helpers ---------- */
  factory Customer.fromMap(Map data) => Customer(
        remoteId:        data['id']      as String?,
        name:            data['name']    as String,
        phone:           data['phone']   as String,
        type:            data['type']    as String,
        locationId:      data['location_id'] as String?,
        preciseLocation: data['precise_location'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id'              : remoteId,
        'name'            : name,
        'phone'           : phone,
        'type'            : type,
        'location_id'     : locationId,
        'precise_location': preciseLocation,
      };
}

