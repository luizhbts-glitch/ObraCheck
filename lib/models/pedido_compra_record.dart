import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'pedido_compra_record.g.dart';

class StatusPedidoCompra {
  static const String pendenteAprovacao = 'pendente_aprovacao';
  static const String aprovado = 'aprovado';
  static const String enviado = 'enviado';
  static const String recebidoParcial = 'recebido_parcial';
  static const String recebidoTotal = 'recebido_total';
  static const String cancelado = 'cancelado';
}

/// Ordem de compra: a cotação vencedora vira pedido formal com o
/// fornecedor. `saldoAtual` decrementa a cada recebimento parcial —
/// confirmado contra o sistema de referência (L7) em 2026-07-18, uma
/// ordem pode ser entregue aos poucos sem precisar fechar tudo de uma vez.
@HiveType(typeId: 27)
class PedidoCompraRecord extends HiveObject {
  @HiveField(0)
  final String id;

  /// Gerado uma vez na criação, imutável — rastreia o pedido até o fim do
  /// fluxo (convenção decidida em 2026-07-18).
  @HiveField(1)
  final String codigo;

  @HiveField(2)
  final String requisicaoId;

  @HiveField(3)
  final String? cotacaoVencedoraId;

  @HiveField(4)
  final String fornecedorId;

  @HiveField(5)
  final String projectId;

  @HiveField(6)
  final String? centroCustoId;

  @HiveField(7)
  final double valorTotal;

  @HiveField(8)
  final double saldoAtual;

  @HiveField(9)
  final String? aprovadoPorEmployeeId;

  @HiveField(10)
  final DateTime? aprovadoEm;

  @HiveField(11)
  final String status;

  @HiveField(12)
  final String? prazoEntrega;

  @HiveField(13)
  final String? notaFiscalStoragePath;

  @HiveField(14)
  final bool deleted;

  @HiveField(15)
  final bool pendingSync;

  @HiveField(16)
  final DateTime createdAt;

  @HiveField(17)
  final DateTime updatedAt;

  PedidoCompraRecord({
    required this.id,
    required this.codigo,
    required this.requisicaoId,
    this.cotacaoVencedoraId,
    required this.fornecedorId,
    required this.projectId,
    this.centroCustoId,
    required this.valorTotal,
    double? saldoAtual,
    this.aprovadoPorEmployeeId,
    this.aprovadoEm,
    this.status = StatusPedidoCompra.pendenteAprovacao,
    this.prazoEntrega,
    this.notaFiscalStoragePath,
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
    required this.updatedAt,
  }) : saldoAtual = saldoAtual ?? valorTotal;

  PedidoCompraRecord copyWith({
    String? id,
    String? codigo,
    String? requisicaoId,
    String? cotacaoVencedoraId,
    String? fornecedorId,
    String? projectId,
    String? centroCustoId,
    double? valorTotal,
    double? saldoAtual,
    String? aprovadoPorEmployeeId,
    DateTime? aprovadoEm,
    String? status,
    String? prazoEntrega,
    String? notaFiscalStoragePath,
    bool? deleted,
    bool? pendingSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PedidoCompraRecord(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      requisicaoId: requisicaoId ?? this.requisicaoId,
      cotacaoVencedoraId: cotacaoVencedoraId ?? this.cotacaoVencedoraId,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      projectId: projectId ?? this.projectId,
      centroCustoId: centroCustoId ?? this.centroCustoId,
      valorTotal: valorTotal ?? this.valorTotal,
      saldoAtual: saldoAtual ?? this.saldoAtual,
      aprovadoPorEmployeeId: aprovadoPorEmployeeId ?? this.aprovadoPorEmployeeId,
      aprovadoEm: aprovadoEm ?? this.aprovadoEm,
      status: status ?? this.status,
      prazoEntrega: prazoEntrega ?? this.prazoEntrega,
      notaFiscalStoragePath: notaFiscalStoragePath ?? this.notaFiscalStoragePath,
      deleted: deleted ?? this.deleted,
      pendingSync: pendingSync ?? this.pendingSync,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  static DateTime? _toDateOrNull(dynamic value) {
    if (value == null) return null;
    return _toDate(value);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'requisicaoId': requisicaoId,
      'cotacaoVencedoraId': cotacaoVencedoraId,
      'fornecedorId': fornecedorId,
      'projectId': projectId,
      'centroCustoId': centroCustoId,
      'valorTotal': valorTotal,
      'saldoAtual': saldoAtual,
      'aprovadoPorEmployeeId': aprovadoPorEmployeeId,
      'aprovadoEm': aprovadoEm == null ? null : Timestamp.fromDate(aprovadoEm!),
      'status': status,
      'prazoEntrega': prazoEntrega,
      'notaFiscalStoragePath': notaFiscalStoragePath,
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PedidoCompraRecord.fromMap(Map<String, dynamic> map) {
    final valorTotal = (map['valorTotal'] as num?)?.toDouble() ?? 0;
    return PedidoCompraRecord(
      id: (map['id'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      requisicaoId: (map['requisicaoId'] ?? '').toString(),
      cotacaoVencedoraId: map['cotacaoVencedoraId']?.toString().isNotEmpty == true
          ? map['cotacaoVencedoraId'].toString()
          : null,
      fornecedorId: (map['fornecedorId'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      centroCustoId: map['centroCustoId']?.toString().isNotEmpty == true
          ? map['centroCustoId'].toString()
          : null,
      valorTotal: valorTotal,
      saldoAtual: (map['saldoAtual'] as num?)?.toDouble() ?? valorTotal,
      aprovadoPorEmployeeId: map['aprovadoPorEmployeeId']?.toString().isNotEmpty == true
          ? map['aprovadoPorEmployeeId'].toString()
          : null,
      aprovadoEm: _toDateOrNull(map['aprovadoEm']),
      status: (map['status'] ?? StatusPedidoCompra.pendenteAprovacao).toString(),
      prazoEntrega: map['prazoEntrega']?.toString(),
      notaFiscalStoragePath: map['notaFiscalStoragePath']?.toString(),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
