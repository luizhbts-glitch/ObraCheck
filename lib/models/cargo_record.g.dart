// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cargo_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CargoRecordAdapter extends TypeAdapter<CargoRecord> {
  @override
  final int typeId = 15;

  @override
  CargoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CargoRecord(
      id: fields[0] as String,
      orgId: fields[1] as String,
      nome: fields[2] as String,
      nivelHierarquico: fields[3] as int,
      perfilAcessoIdPadrao: fields[4] as String?,
      isActive: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CargoRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orgId)
      ..writeByte(2)
      ..write(obj.nome)
      ..writeByte(3)
      ..write(obj.nivelHierarquico)
      ..writeByte(4)
      ..write(obj.perfilAcessoIdPadrao)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CargoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
