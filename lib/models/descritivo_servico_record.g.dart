// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'descritivo_servico_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DescritivoServicoRecordAdapter
    extends TypeAdapter<DescritivoServicoRecord> {
  @override
  final int typeId = 28;

  @override
  DescritivoServicoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DescritivoServicoRecord(
      id: fields[0] as String,
      orgId: fields[1] as String,
      descricao: fields[2] as String,
      unidadeMedida: fields[3] as String,
      valorUnitarioReferencia: fields[4] as double,
      isActive: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DescritivoServicoRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orgId)
      ..writeByte(2)
      ..write(obj.descricao)
      ..writeByte(3)
      ..write(obj.unidadeMedida)
      ..writeByte(4)
      ..write(obj.valorUnitarioReferencia)
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
      other is DescritivoServicoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
