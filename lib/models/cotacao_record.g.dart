// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cotacao_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemCotacaoAdapter extends TypeAdapter<ItemCotacao> {
  @override
  final int typeId = 25;

  @override
  ItemCotacao read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemCotacao(
      descricao: fields[0] as String,
      quantidade: fields[1] as String,
      unidade: fields[2] as String,
      valorUnitario: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ItemCotacao obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.descricao)
      ..writeByte(1)
      ..write(obj.quantidade)
      ..writeByte(2)
      ..write(obj.unidade)
      ..writeByte(3)
      ..write(obj.valorUnitario);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemCotacaoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CotacaoRecordAdapter extends TypeAdapter<CotacaoRecord> {
  @override
  final int typeId = 26;

  @override
  CotacaoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CotacaoRecord(
      id: fields[0] as String,
      codigo: fields[1] as String,
      requisicaoId: fields[2] as String,
      fornecedorId: fields[3] as String,
      itens: (fields[4] as List?)?.cast<ItemCotacao>(),
      frete: fields[5] as double?,
      desconto: fields[6] as double?,
      prazoEntrega: fields[7] as String?,
      condicaoPagamento: fields[8] as String?,
      vencedora: fields[9] as bool,
      comentario: fields[10] as String?,
      deleted: fields[11] as bool,
      pendingSync: fields[12] as bool,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CotacaoRecord obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.codigo)
      ..writeByte(2)
      ..write(obj.requisicaoId)
      ..writeByte(3)
      ..write(obj.fornecedorId)
      ..writeByte(4)
      ..write(obj.itens)
      ..writeByte(5)
      ..write(obj.frete)
      ..writeByte(6)
      ..write(obj.desconto)
      ..writeByte(7)
      ..write(obj.prazoEntrega)
      ..writeByte(8)
      ..write(obj.condicaoPagamento)
      ..writeByte(9)
      ..write(obj.vencedora)
      ..writeByte(10)
      ..write(obj.comentario)
      ..writeByte(11)
      ..write(obj.deleted)
      ..writeByte(12)
      ..write(obj.pendingSync)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CotacaoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
