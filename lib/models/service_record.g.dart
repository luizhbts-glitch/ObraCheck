// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

int _safeHiveServiceInt(dynamic value, String field, {int fallback = 0}) {
  if (value == null) {
    if (AppLog.enableSyncLogs) {
      debugPrint('[SYNC][NULL_INT_FIX] campo=$field origem=Hive valor=null fallback=$fallback');
    }
    return fallback;
  }
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value.toString());
  if (parsed != null) return parsed;
  if (AppLog.enableSyncLogs) {
    debugPrint('[SYNC][NULL_INT_FIX] campo=$field origem=Hive valor_invalido="$value" fallback=$fallback');
  }
  return fallback;
}

class ServiceRecordAdapter extends TypeAdapter<ServiceRecord> {
  @override
  final int typeId = 3;

  @override
  ServiceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ServiceRecord(
      id: fields[0] as String,
      obra: fields[1] as String,
      torre: fields[2] as String,
      andar: _safeHiveServiceInt(fields[3], 'ServiceRecord.andar', fallback: 0),
      localRef: fields[4] as String,
      localLabel: fields[5] as String,
      empresaId: fields[6] as String,
      empresaNome: fields[7] as String,
      servicoCodigo: fields[8] as String,
      servicoNome: fields[9] as String,
      status: fields[10] as String,
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      deleted: fields[13] as bool,
      pendingSync: fields[14] as bool,
      deletedAt: fields[15] as DateTime?,
      projectId: fields[16] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ServiceRecord obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.obra)
      ..writeByte(2)
      ..write(obj.torre)
      ..writeByte(3)
      ..write(obj.andar)
      ..writeByte(4)
      ..write(obj.localRef)
      ..writeByte(5)
      ..write(obj.localLabel)
      ..writeByte(6)
      ..write(obj.empresaId)
      ..writeByte(7)
      ..write(obj.empresaNome)
      ..writeByte(8)
      ..write(obj.servicoCodigo)
      ..writeByte(9)
      ..write(obj.servicoNome)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.deleted)
      ..writeByte(14)
      ..write(obj.pendingSync)
      ..writeByte(15)
      ..write(obj.deletedAt)
      ..writeByte(16)
      ..write(obj.projectId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
