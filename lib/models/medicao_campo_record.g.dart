// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicao_campo_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicaoCampoFotoAdapter extends TypeAdapter<MedicaoCampoFoto> {
  @override
  final int typeId = 42;

  @override
  MedicaoCampoFoto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicaoCampoFoto(
      id: fields[0] as String,
      localPath: fields[1] as String,
      dataUrl: fields[2] as String,
      photoUrl: fields[3] as String,
      storagePath: fields[4] as String,
      legenda: fields[5] as String,
      capturedAt: fields[6] as DateTime,
      usuario: fields[7] as String,
      pendingSync: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MedicaoCampoFoto obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.localPath)
      ..writeByte(2)
      ..write(obj.dataUrl)
      ..writeByte(3)
      ..write(obj.photoUrl)
      ..writeByte(4)
      ..write(obj.storagePath)
      ..writeByte(5)
      ..write(obj.legenda)
      ..writeByte(6)
      ..write(obj.capturedAt)
      ..writeByte(7)
      ..write(obj.usuario)
      ..writeByte(8)
      ..write(obj.pendingSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicaoCampoFotoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicaoCampoAptoAdapter extends TypeAdapter<MedicaoCampoApto> {
  @override
  final int typeId = 41;

  @override
  MedicaoCampoApto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicaoCampoApto(
      torre: fields[0] as String,
      localRef: fields[1] as String,
      label: fields[2] as String,
      andar: fields[3] as int,
      status: fields[4] as String,
      observacao: fields[5] as String,
      fotos: (fields[6] as List).cast<MedicaoCampoFoto>(),
    );
  }

  @override
  void write(BinaryWriter writer, MedicaoCampoApto obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.torre)
      ..writeByte(1)
      ..write(obj.localRef)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.andar)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.observacao)
      ..writeByte(6)
      ..write(obj.fotos);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicaoCampoAptoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicaoCampoRecordAdapter extends TypeAdapter<MedicaoCampoRecord> {
  @override
  final int typeId = 40;

  @override
  MedicaoCampoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicaoCampoRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      obra: fields[2] as String,
      servicoCodigo: fields[3] as String,
      servicoNome: fields[4] as String,
      empreiteiroId: fields[5] as String,
      empreiteiroNome: fields[6] as String,
      periodo: fields[7] as String,
      responsavelNome: fields[8] as String,
      aptos: (fields[9] as List).cast<MedicaoCampoApto>(),
      deleted: fields[10] as bool,
      pendingSync: fields[11] as bool,
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime,
      ano: fields[14] as int,
      mes: fields[15] as int,
      elementos: fields[16] == null ? [] : (fields[16] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, MedicaoCampoRecord obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.obra)
      ..writeByte(3)
      ..write(obj.servicoCodigo)
      ..writeByte(4)
      ..write(obj.servicoNome)
      ..writeByte(5)
      ..write(obj.empreiteiroId)
      ..writeByte(6)
      ..write(obj.empreiteiroNome)
      ..writeByte(7)
      ..write(obj.periodo)
      ..writeByte(8)
      ..write(obj.responsavelNome)
      ..writeByte(9)
      ..write(obj.aptos)
      ..writeByte(10)
      ..write(obj.deleted)
      ..writeByte(11)
      ..write(obj.pendingSync)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.ano)
      ..writeByte(15)
      ..write(obj.mes)
      ..writeByte(16)
      ..write(obj.elementos);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicaoCampoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
