// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fornecedor_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FornecedorRecordAdapter extends TypeAdapter<FornecedorRecord> {
  @override
  final int typeId = 20;

  @override
  FornecedorRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FornecedorRecord(
      id: fields[0] as String,
      orgId: fields[1] as String,
      nome: fields[2] as String,
      cnpj: fields[3] as String?,
      categoria: fields[4] as String,
      telefone: fields[5] as String?,
      isActive: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FornecedorRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orgId)
      ..writeByte(2)
      ..write(obj.nome)
      ..writeByte(3)
      ..write(obj.cnpj)
      ..writeByte(4)
      ..write(obj.categoria)
      ..writeByte(5)
      ..write(obj.telefone)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FornecedorRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
