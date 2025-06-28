// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_sale.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineSaleAdapter extends TypeAdapter<OfflineSale> {
  @override
  final int typeId = 2;

  @override
  OfflineSale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineSale(
      isNewCustomer: fields[0] as bool,
      newCustomerPhone: fields[1] as String?,
      existingCustomerId: fields[2] as String?,
      customerName: fields[3] as String?,
      productId: fields[4] as String?,
      productName: fields[5] as String?,
      pricePerUnit: fields[6] as double,
      quantity: fields[7] as int,
      totalPrice: fields[8] as double,
      paymentStatus: fields[9] as String,
      createdAt: fields[10] as DateTime,
      customerPhone: fields[11] as String?,
      soldBy: fields[12] as String,
      locationId: fields[13] as String,
      localSaleId: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineSale obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.isNewCustomer)
      ..writeByte(1)
      ..write(obj.newCustomerPhone)
      ..writeByte(2)
      ..write(obj.existingCustomerId)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.productId)
      ..writeByte(5)
      ..write(obj.productName)
      ..writeByte(6)
      ..write(obj.pricePerUnit)
      ..writeByte(7)
      ..write(obj.quantity)
      ..writeByte(8)
      ..write(obj.totalPrice)
      ..writeByte(9)
      ..write(obj.paymentStatus)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.customerPhone)
      ..writeByte(12)
      ..write(obj.soldBy)
      ..writeByte(13)
      ..write(obj.locationId)
      ..writeByte(15)
      ..write(obj.localSaleId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineSaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
