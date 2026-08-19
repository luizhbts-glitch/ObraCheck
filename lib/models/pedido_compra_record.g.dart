// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedido_compra_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PedidoCompraRecordAdapter extends TypeAdapter<PedidoCompraRecord> {
  @override
  final int typeId = 27;

  @override
  PedidoCompraRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PedidoCompraRecord(
      id: fields[0] as String,
      codigo: fields[1] as String,
      requisicaoId: fields[2] as String,
      cotacaoVencedoraId: fields[3] as String?,
      fornecedorId: fields[4] as String,
      projectId: fields[5] as String,
      centroCustoId: fields[6] as String?,
      valorTotal: fields[7] as double,
      saldoAtual: fields[8] as double?,
      aprovadoPorEmployeeId: fields[9] as String?,
      aprovadoEm: fields[10] as DateTime?,
      status: fields[11] as String,
      prazoEntrega: fields[12] as String?,
      notaFiscalStoragePath: fields[13] as String?,
      deleted: fields[14] as bool,
      pendingSync: fields[15] as bool,
      createdAt: fields[16] as DateTime,
      updatedAt: fields[17] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PedidoCompraRecord obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.codigo)
      ..writeByte(2)
      ..write(obj.requisicaoId)
      ..writeByte(3)
      ..write(obj.cotacaoVencedoraId)
      ..writeByte(4)
      ..write(obj.fornecedorId)
      ..writeByte(5)
      ..write(obj.projectId)
      ..writeByte(6)
      ..write(obj.centroCustoId)
      ..writeByte(7)
      ..write(obj.valorTotal)
      ..writeByte(8)
      ..write(obj.saldoAtual)
      ..writeByte(9)
      ..write(obj.aprovadoPorEmployeeId)
      ..writeByte(10)
      ..write(obj.aprovadoEm)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.prazoEntrega)
      ..writeByte(13)
      ..write(obj.notaFiscalStoragePath)
      ..writeByte(14)
      ..write(obj.deleted)
      ..writeByte(15)
      ..write(obj.pendingSync)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PedidoCompraRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
