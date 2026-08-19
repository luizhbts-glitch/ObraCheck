// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'employee_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PermissaoOverrideAdapter extends TypeAdapter<PermissaoOverride> {
  @override
  final int typeId = 19;

  @override
  PermissaoOverride read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PermissaoOverride(
      permissao: fields[0] as PermissaoItem,
      liberado: fields[1] as bool,
      concedidoPorEmployeeId: fields[2] as String,
      concedidoEm: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PermissaoOverride obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.permissao)
      ..writeByte(1)
      ..write(obj.liberado)
      ..writeByte(2)
      ..write(obj.concedidoPorEmployeeId)
      ..writeByte(3)
      ..write(obj.concedidoEm);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissaoOverrideAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EmployeeRecordAdapter extends TypeAdapter<EmployeeRecord> {
  @override
  final int typeId = 16;

  @override
  EmployeeRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmployeeRecord(
      id: fields[0] as String,
      orgId: fields[1] as String,
      projectId: fields[2] as String,
      cargoId: fields[3] as String,
      nome: fields[4] as String,
      avaliadorEmployeeId: fields[5] as String?,
      isActive: fields[6] as bool,
      userId: fields[7] as String?,
      perfilAcessoId: fields[8] as String?,
      permissaoOverrides: (fields[9] as List?)?.cast<PermissaoOverride>(),
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, EmployeeRecord obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orgId)
      ..writeByte(2)
      ..write(obj.projectId)
      ..writeByte(3)
      ..write(obj.cargoId)
      ..writeByte(4)
      ..write(obj.nome)
      ..writeByte(5)
      ..write(obj.avaliadorEmployeeId)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.userId)
      ..writeByte(8)
      ..write(obj.perfilAcessoId)
      ..writeByte(9)
      ..write(obj.permissaoOverrides)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
