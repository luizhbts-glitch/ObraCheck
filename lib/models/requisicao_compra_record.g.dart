// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'requisicao_compra_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemRequisicaoAdapter extends TypeAdapter<ItemRequisicao> {
  @override
  final int typeId = 23;

  @override
  ItemRequisicao read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemRequisicao(
      materialCatalogoId: fields[0] as String?,
      descricao: fields[1] as String,
      quantidade: fields[2] as String,
      unidade: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ItemRequisicao obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.materialCatalogoId)
      ..writeByte(1)
      ..write(obj.descricao)
      ..writeByte(2)
      ..write(obj.quantidade)
      ..writeByte(3)
      ..write(obj.unidade);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemRequisicaoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RequisicaoCompraRecordAdapter
    extends TypeAdapter<RequisicaoCompraRecord> {
  @override
  final int typeId = 24;

  @override
  RequisicaoCompraRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RequisicaoCompraRecord(
      id: fields[0] as String,
      codigo: fields[1] as String,
      projectId: fields[2] as String,
      centroCustoId: fields[3] as String?,
      solicitanteEmployeeId: fields[4] as String,
      itens: (fields[5] as List?)?.cast<ItemRequisicao>(),
      urgencia: fields[6] as String,
      status: fields[7] as String,
      observacao: fields[8] as String?,
      deleted: fields[9] as bool,
      pendingSync: fields[10] as bool,
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RequisicaoCompraRecord obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.codigo)
      ..writeByte(2)
      ..write(obj.projectId)
      ..writeByte(3)
      ..write(obj.centroCustoId)
      ..writeByte(4)
      ..write(obj.solicitanteEmployeeId)
      ..writeByte(5)
      ..write(obj.itens)
      ..writeByte(6)
      ..write(obj.urgencia)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.observacao)
      ..writeByte(9)
      ..write(obj.deleted)
      ..writeByte(10)
      ..write(obj.pendingSync)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequisicaoCompraRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
