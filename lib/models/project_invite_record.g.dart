// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_invite_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectInviteRecordAdapter extends TypeAdapter<ProjectInviteRecord> {
  @override
  final int typeId = 8;

  @override
  ProjectInviteRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectInviteRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      email: fields[2] as String,
      emailLower: fields[3] as String,
      role: fields[4] as String,
      status: fields[5] as String,
      invitedByUid: fields[6] as String,
      invitedByName: fields[7] as String?,
      invitedAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
      acceptedByUid: fields[10] as String?,
      acceptedAt: fields[11] as DateTime?,
      pendingSync: (fields[12] as bool?) ?? false,
      syncError: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProjectInviteRecord obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.emailLower)
      ..writeByte(4)
      ..write(obj.role)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.invitedByUid)
      ..writeByte(7)
      ..write(obj.invitedByName)
      ..writeByte(8)
      ..write(obj.invitedAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.acceptedByUid)
      ..writeByte(11)
      ..write(obj.acceptedAt)
      ..writeByte(12)
      ..write(obj.pendingSync)
      ..writeByte(13)
      ..write(obj.syncError);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectInviteRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

