// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipamento_estoque_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EquipamentoEstoqueRecordAdapter
    extends TypeAdapter<EquipamentoEstoqueRecord> {
  @override
  final int typeId = 36;

  @override
  EquipamentoEstoqueRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EquipamentoEstoqueRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      tipo: fields[2] as String,
      material: fields[3] as String,
      marca: fields[4] as String?,
      descricao: fields[5] as String?,
      terceiroNome: fields[6] as String?,
      periodoInicio: fields[7] as DateTime?,
      periodoFim: fields[8] as DateTime?,
      locadora: fields[9] as String?,
      centroCusto: fields[10] as String?,
      valor: fields[11] as double?,
      deleted: fields[12] as bool,
      pendingSync: fields[13] as bool,
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, EquipamentoEstoqueRecord obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.tipo)
      ..writeByte(3)
      ..write(obj.material)
      ..writeByte(4)
      ..write(obj.marca)
      ..writeByte(5)
      ..write(obj.descricao)
      ..writeByte(6)
      ..write(obj.terceiroNome)
      ..writeByte(7)
      ..write(obj.periodoInicio)
      ..writeByte(8)
      ..write(obj.periodoFim)
      ..writeByte(9)
      ..write(obj.locadora)
      ..writeByte(10)
      ..write(obj.centroCusto)
      ..writeByte(11)
      ..write(obj.valor)
      ..writeByte(12)
      ..write(obj.deleted)
      ..writeByte(13)
      ..write(obj.pendingSync)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipamentoEstoqueRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
