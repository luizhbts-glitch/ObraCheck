// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompanyRecordAdapter extends TypeAdapter<CompanyRecord> {
  @override
  final int typeId = 4;

  @override
  CompanyRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompanyRecord(
      id: fields[0] as String,
      nome: fields[1] as String,
      especialidade: fields[2] as String,
      cnpj: fields[3] as String?,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      deleted: fields[6] as bool,
      pendingSync: fields[7] as bool,
      deletedAt: fields[8] as DateTime?,
      projectId: fields[9] as String,
      phone: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CompanyRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.especialidade)
      ..writeByte(3)
      ..write(obj.cnpj)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.deleted)
      ..writeByte(7)
      ..write(obj.pendingSync)
      ..writeByte(8)
      ..write(obj.deletedAt)
      ..writeByte(9)
      ..write(obj.projectId)
      ..writeByte(10)
      ..write(obj.phone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
