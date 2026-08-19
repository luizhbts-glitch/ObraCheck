// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recebimento_material_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemRecebimentoVerificadoAdapter
    extends TypeAdapter<ItemRecebimentoVerificado> {
  @override
  final int typeId = 33;

  @override
  ItemRecebimentoVerificado read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemRecebimentoVerificado(
      descricao: fields[0] as String,
      proofType: fields[1] as String,
      status: fields[2] as String,
      certificadoStoragePath: fields[3] as String?,
      obs: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ItemRecebimentoVerificado obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.descricao)
      ..writeByte(1)
      ..write(obj.proofType)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.certificadoStoragePath)
      ..writeByte(4)
      ..write(obj.obs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemRecebimentoVerificadoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecebimentoMaterialRecordAdapter
    extends TypeAdapter<RecebimentoMaterialRecord> {
  @override
  final int typeId = 34;

  @override
  RecebimentoMaterialRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecebimentoMaterialRecord(
      id: fields[0] as String,
      pedidoCompraId: fields[1] as String,
      fornecedorId: fields[2] as String,
      dataRecebimento: fields[3] as DateTime,
      prazoOk: fields[4] as bool,
      condicaoOk: fields[5] as bool,
      qualidadeFornecedorNota: fields[6] as double?,
      itensVerificados: (fields[7] as List?)?.cast<ItemRecebimentoVerificado>(),
      fotos: (fields[8] as List?)?.cast<String>(),
      pendingSync: fields[9] as bool,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecebimentoMaterialRecord obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pedidoCompraId)
      ..writeByte(2)
      ..write(obj.fornecedorId)
      ..writeByte(3)
      ..write(obj.dataRecebimento)
      ..writeByte(4)
      ..write(obj.prazoOk)
      ..writeByte(5)
      ..write(obj.condicaoOk)
      ..writeByte(6)
      ..write(obj.qualidadeFornecedorNota)
      ..writeByte(7)
      ..write(obj.itensVerificados)
      ..writeByte(8)
      ..write(obj.fotos)
      ..writeByte(9)
      ..write(obj.pendingSync)
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
      other is RecebimentoMaterialRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
