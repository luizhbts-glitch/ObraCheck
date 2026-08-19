// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'centro_custo_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CentroCustoRecordAdapter extends TypeAdapter<CentroCustoRecord> {
  @override
  final int typeId = 22;

  @override
  CentroCustoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CentroCustoRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      codigo: fields[2] as String,
      nome: fields[3] as String,
      orcado: fields[4] as double?,
      isActive: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CentroCustoRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.codigo)
      ..writeByte(3)
      ..write(obj.nome)
      ..writeByte(4)
      ..write(obj.orcado)
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
      other is CentroCustoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
