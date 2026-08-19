// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicao_empreiteiro_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemMedicaoAdapter extends TypeAdapter<ItemMedicao> {
  @override
  final int typeId = 31;

  @override
  ItemMedicao read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemMedicao(
      descritivoServicoId: fields[0] as String,
      quantidadeMedida: fields[1] as double,
      valorUnitario: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ItemMedicao obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.descritivoServicoId)
      ..writeByte(1)
      ..write(obj.quantidadeMedida)
      ..writeByte(2)
      ..write(obj.valorUnitario);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemMedicaoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicaoEmpreiteiroRecordAdapter
    extends TypeAdapter<MedicaoEmpreiteiroRecord> {
  @override
  final int typeId = 32;

  @override
  MedicaoEmpreiteiroRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MedicaoEmpreiteiroRecord(
      id: fields[0] as String,
      codigo: fields[1] as String,
      orcamentoServicoId: fields[2] as String,
      empreiteiroId: fields[3] as String,
      projectId: fields[4] as String,
      centroCustoId: fields[5] as String?,
      periodo: fields[6] as String,
      itens: (fields[7] as List?)?.cast<ItemMedicao>(),
      adiantamentoDeduzido: fields[8] as double,
      descontoImposto: fields[9] as double,
      descontoComercial: fields[10] as double,
      status: fields[11] as String,
      deleted: fields[12] as bool,
      pendingSync: fields[13] as bool,
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MedicaoEmpreiteiroRecord obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.codigo)
      ..writeByte(2)
      ..write(obj.orcamentoServicoId)
      ..writeByte(3)
      ..write(obj.empreiteiroId)
      ..writeByte(4)
      ..write(obj.projectId)
      ..writeByte(5)
      ..write(obj.centroCustoId)
      ..writeByte(6)
      ..write(obj.periodo)
      ..writeByte(7)
      ..write(obj.itens)
      ..writeByte(8)
      ..write(obj.adiantamentoDeduzido)
      ..writeByte(9)
      ..write(obj.descontoImposto)
      ..writeByte(10)
      ..write(obj.descontoComercial)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.deleted)
      ..writeByte(13)
      ..write(obj.pendingSync)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicaoEmpreiteiroRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
