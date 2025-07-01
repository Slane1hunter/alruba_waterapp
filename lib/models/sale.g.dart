// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 1;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sale(
      localId: fields[0] as String?,
      remoteSaleId: fields[1] as String?,
      isNewCustomer: fields[2] as bool,
      newCustomerPhone: fields[3] as String?,
      customerId: fields[4] as String?,
      productId: fields[5] as String,
      pricePerUnit: fields[6] as double,
      quantity: fields[7] as int,
      totalAmount: fields[8] as double,
      paymentStatus: fields[9] as String,
      soldBy: fields[10] as String,
      locationId: fields[11] as String?,
      createdAt: fields[12] as DateTime,
      amountPaid: fields[13] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.localId)
      ..writeByte(1)
      ..write(obj.remoteSaleId)
      ..writeByte(2)
      ..write(obj.isNewCustomer)
      ..writeByte(3)
      ..write(obj.newCustomerPhone)
      ..writeByte(4)
      ..write(obj.customerId)
      ..writeByte(5)
      ..write(obj.productId)
      ..writeByte(6)
      ..write(obj.pricePerUnit)
      ..writeByte(7)
      ..write(obj.quantity)
      ..writeByte(8)
      ..write(obj.totalAmount)
      ..writeByte(9)
      ..write(obj.paymentStatus)
      ..writeByte(10)
      ..write(obj.soldBy)
      ..writeByte(11)
      ..write(obj.locationId)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.amountPaid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
