// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insumo_obra_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InsumoObraRecordAdapter extends TypeAdapter<InsumoObraRecord> {
  @override
  final int typeId = 37;

  @override
  InsumoObraRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InsumoObraRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      material: fields[2] as String,
      endereco: fields[3] as String,
      estoqueMinimo: fields[4] as double,
      quantidadeAtual: fields[5] as double,
      deleted: fields[6] as bool,
      pendingSync: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
      unidade: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, InsumoObraRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.material)
      ..writeByte(3)
      ..write(obj.endereco)
      ..writeByte(4)
      ..write(obj.estoqueMinimo)
      ..writeByte(5)
      ..write(obj.quantidadeAtual)
      ..writeByte(6)
      ..write(obj.deleted)
      ..writeByte(7)
      ..write(obj.pendingSync)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.unidade);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsumoObraRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InsumoMovimentoRecordAdapter extends TypeAdapter<InsumoMovimentoRecord> {
  @override
  final int typeId = 38;

  @override
  InsumoMovimentoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InsumoMovimentoRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      insumoId: fields[2] as String,
      material: fields[3] as String,
      tipo: fields[4] as String,
      quantidade: fields[5] as double,
      saldoResultante: fields[6] as double,
      deleted: fields[7] as bool,
      pendingSync: fields[8] as bool,
      createdAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, InsumoMovimentoRecord obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.insumoId)
      ..writeByte(3)
      ..write(obj.material)
      ..writeByte(4)
      ..write(obj.tipo)
      ..writeByte(5)
      ..write(obj.quantidade)
      ..writeByte(6)
      ..write(obj.saldoResultante)
      ..writeByte(7)
      ..write(obj.deleted)
      ..writeByte(8)
      ..write(obj.pendingSync)
      ..writeByte(9)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsumoMovimentoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InsumoConferenciaRecordAdapter
    extends TypeAdapter<InsumoConferenciaRecord> {
  @override
  final int typeId = 39;

  @override
  InsumoConferenciaRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InsumoConferenciaRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      insumoId: fields[2] as String,
      material: fields[3] as String,
      unidade: fields[4] as String,
      quantidadeEsperada: fields[5] as double,
      quantidadeConferida: fields[6] as double,
      divergencia: fields[7] as double,
      observacao: fields[8] as String?,
      deleted: fields[9] as bool,
      pendingSync: fields[10] as bool,
      createdAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, InsumoConferenciaRecord obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.insumoId)
      ..writeByte(3)
      ..write(obj.material)
      ..writeByte(4)
      ..write(obj.unidade)
      ..writeByte(5)
      ..write(obj.quantidadeEsperada)
      ..writeByte(6)
      ..write(obj.quantidadeConferida)
      ..writeByte(7)
      ..write(obj.divergencia)
      ..writeByte(8)
      ..write(obj.observacao)
      ..writeByte(9)
      ..write(obj.deleted)
      ..writeByte(10)
      ..write(obj.pendingSync)
      ..writeByte(11)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsumoConferenciaRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
