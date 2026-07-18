// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectRecordAdapter extends TypeAdapter<ProjectRecord> {
  @override
  final int typeId = 6;

  @override
  ProjectRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectRecord(
      id: fields[0] as String,
      name: fields[1] as String,
      code: fields[2] as String,
      isActive: fields[3] as bool,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ProjectRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.code)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
