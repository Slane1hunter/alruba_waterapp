// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_gallon_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineGallonTransactionAdapter
    extends TypeAdapter<OfflineGallonTransaction> {
  @override
  final int typeId = 5;

  @override
  OfflineGallonTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineGallonTransaction(
      customerId: fields[0] as String?,
      productId: fields[1] as String?,
      quantity: fields[2] as int,
      transactionType: fields[3] as String,
      status: fields[4] as String?,
      createdAt: fields[5] as DateTime,
      amount: fields[6] as double,
      saleId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineGallonTransaction obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.customerId)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.transactionType)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.amount)
      ..writeByte(7)
      ..write(obj.saleId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineGallonTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
