// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'material_catalogo_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaterialCatalogoRecordAdapter
    extends TypeAdapter<MaterialCatalogoRecord> {
  @override
  final int typeId = 21;

  @override
  MaterialCatalogoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaterialCatalogoRecord(
      id: fields[0] as String,
      orgId: fields[1] as String,
      categoria: fields[2] as String,
      produto: fields[3] as String,
      unidadeMedida: fields[4] as String,
      custoMedioReferencia: fields[5] as double?,
      ultimaCompraEm: fields[6] as DateTime?,
      isActive: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MaterialCatalogoRecord obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orgId)
      ..writeByte(2)
      ..write(obj.categoria)
      ..writeByte(3)
      ..write(obj.produto)
      ..writeByte(4)
      ..write(obj.unidadeMedida)
      ..writeByte(5)
      ..write(obj.custoMedioReferencia)
      ..writeByte(6)
      ..write(obj.ultimaCompraEm)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialCatalogoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
