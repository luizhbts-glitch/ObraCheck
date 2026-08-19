// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'despesa_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DespesaRecordAdapter extends TypeAdapter<DespesaRecord> {
  @override
  final int typeId = 35;

  @override
  DespesaRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DespesaRecord(
      id: fields[0] as String,
      codigo: fields[1] as String,
      projectId: fields[2] as String,
      centroCustoId: fields[3] as String?,
      tipo: fields[4] as String,
      origem: fields[5] as String,
      origemId: fields[6] as String?,
      descricao: fields[7] as String?,
      valor: fields[8] as double,
      vencimento: fields[9] as DateTime?,
      notaFiscalStoragePath: fields[10] as String?,
      lancadoPorEmployeeId: fields[11] as String,
      status: fields[12] as String,
      aprovadoPorEmployeeId: fields[13] as String?,
      aprovadoEm: fields[14] as DateTime?,
      deleted: fields[15] as bool,
      pendingSync: fields[16] as bool,
      createdAt: fields[17] as DateTime,
      updatedAt: fields[18] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DespesaRecord obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.codigo)
      ..writeByte(2)
      ..write(obj.projectId)
      ..writeByte(3)
      ..write(obj.centroCustoId)
      ..writeByte(4)
      ..write(obj.tipo)
      ..writeByte(5)
      ..write(obj.origem)
      ..writeByte(6)
      ..write(obj.origemId)
      ..writeByte(7)
      ..write(obj.descricao)
      ..writeByte(8)
      ..write(obj.valor)
      ..writeByte(9)
      ..write(obj.vencimento)
      ..writeByte(10)
      ..write(obj.notaFiscalStoragePath)
      ..writeByte(11)
      ..write(obj.lancadoPorEmployeeId)
      ..writeByte(12)
      ..write(obj.status)
      ..writeByte(13)
      ..write(obj.aprovadoPorEmployeeId)
      ..writeByte(14)
      ..write(obj.aprovadoEm)
      ..writeByte(15)
      ..write(obj.deleted)
      ..writeByte(16)
      ..write(obj.pendingSync)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DespesaRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
