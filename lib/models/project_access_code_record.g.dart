// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_access_code_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

int _safeHiveProjectAccessInt(dynamic value, String field, {int fallback = 0}) {
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

class ProjectAccessCodeRecordAdapter extends TypeAdapter<ProjectAccessCodeRecord> {
  @override
  final int typeId = 11;

  @override
  ProjectAccessCodeRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectAccessCodeRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      code: fields[2] as String,
      role: fields[3] as String,
      expiresAt: fields[4] as DateTime?,
      maxUses: _safeHiveProjectAccessInt(fields[5], 'ProjectAccessCodeRecord.maxUses', fallback: 1),
      usedCount: _safeHiveProjectAccessInt(fields[6], 'ProjectAccessCodeRecord.usedCount', fallback: 0),
      isActive: fields[7] as bool,
      isMaster: (fields[14] as bool?) ?? false,
      createdByUid: fields[8] as String,
      createdByName: fields[9] as String?,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
      pendingSync: (fields[12] as bool?) ?? false,
      syncError: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProjectAccessCodeRecord obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.code)
      ..writeByte(3)
      ..write(obj.role)
      ..writeByte(4)
      ..write(obj.expiresAt)
      ..writeByte(5)
      ..write(obj.maxUses)
      ..writeByte(6)
      ..write(obj.usedCount)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.createdByUid)
      ..writeByte(9)
      ..write(obj.createdByName)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.pendingSync)
      ..writeByte(13)
      ..write(obj.syncError)
      ..writeByte(14)
      ..write(obj.isMaster);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectAccessCodeRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

