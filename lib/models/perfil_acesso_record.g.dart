// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'perfil_acesso_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PermissaoItemAdapter extends TypeAdapter<PermissaoItem> {
  @override
  final int typeId = 18;

  @override
  PermissaoItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PermissaoItem(
      modulo: fields[0] as String,
      entidade: fields[1] as String,
      acao: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PermissaoItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.modulo)
      ..writeByte(1)
      ..write(obj.entidade)
      ..writeByte(2)
      ..write(obj.acao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissaoItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PerfilAcessoRecordAdapter extends TypeAdapter<PerfilAcessoRecord> {
  @override
  final int typeId = 17;

  @override
  PerfilAcessoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PerfilAcessoRecord(
      id: fields[0] as String,
      orgId: fields[1] as String,
      nome: fields[2] as String,
      permissoes: (fields[3] as List?)?.cast<PermissaoItem>(),
      criadoPorEmployeeId: fields[4] as String,
      isActive: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PerfilAcessoRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orgId)
      ..writeByte(2)
      ..write(obj.nome)
      ..writeByte(3)
      ..write(obj.permissoes)
      ..writeByte(4)
      ..write(obj.criadoPorEmployeeId)
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
      other is PerfilAcessoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
