// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orcamento_servico_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemOrcamentoAdapter extends TypeAdapter<ItemOrcamento> {
  @override
  final int typeId = 29;

  @override
  ItemOrcamento read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemOrcamento(
      descritivoServicoId: fields[0] as String,
      quantidadeOrcada: fields[1] as double,
      valorUnitario: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ItemOrcamento obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.descritivoServicoId)
      ..writeByte(1)
      ..write(obj.quantidadeOrcada)
      ..writeByte(2)
      ..write(obj.valorUnitario);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemOrcamentoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrcamentoServicoRecordAdapter
    extends TypeAdapter<OrcamentoServicoRecord> {
  @override
  final int typeId = 30;

  @override
  OrcamentoServicoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrcamentoServicoRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      empreiteiroId: fields[2] as String,
      itens: (fields[3] as List?)?.cast<ItemOrcamento>(),
      isActive: fields[4] as bool,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, OrcamentoServicoRecord obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.empreiteiroId)
      ..writeByte(3)
      ..write(obj.itens)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrcamentoServicoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
