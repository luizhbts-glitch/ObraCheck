import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'despesa_record.g.dart';

class TipoDespesa {
  static const String controlada = 'controlada';
  static const String naoControlada = 'nao_controlada';
}

class OrigemDespesa {
  static const String ordemCompra = 'ordem_compra';
  static const String medicaoEmpreiteiro = 'medicao_empreiteiro';
  static const String avulsa = 'avulsa';
}

class StatusDespesa {
  static const String lancada = 'lancada';
  static const String aguardandoAprovacao = 'aguardando_aprovacao';
  static const String aprovada = 'aprovada';
  static const String rejeitada = 'rejeitada';
  static const String paga = 'paga';
}

/// Despesa unificada — controlada (vem de ordem de compra ou medição de
/// empreiteiro) ou não controlada (avulsa, serviço/material não
/// programado). Decidido em 2026-07-18: qualquer um lança, só nível 4+ do
/// organograma (Engenheiro pra cima) aprova pra seguir pro pagamento.
@HiveType(typeId: 35)
class DespesaRecord extends HiveObject {
  @HiveField(0)
  final String id;

  /// Gerado uma vez, imutável — mesmo em despesa não controlada.
  @HiveField(1)
  final String codigo;

  @HiveField(2)
  final String projectId;

  @HiveField(3)
  final String? centroCustoId;

  @HiveField(4)
  final String tipo;

  @HiveField(5)
  final String origem;

  @HiveField(6)
  final String? origemId;

  @HiveField(7)
  final String? descricao;

  @HiveField(8)
  final double valor;

  @HiveField(9)
  final DateTime? vencimento;

  @HiveField(10)
  final String? notaFiscalStoragePath;

  @HiveField(11)
  final String lancadoPorEmployeeId;

  @HiveField(12)
  final String status;

  @HiveField(13)
  final String? aprovadoPorEmployeeId;

  @HiveField(14)
  final DateTime? aprovadoEm;

  @HiveField(15)
  final bool deleted;

  @HiveField(16)
  final bool pendingSync;

  @HiveField(17)
  final DateTime createdAt;

  @HiveField(18)
  final DateTime updatedAt;

  DespesaRecord({
    required this.id,
    required this.codigo,
    required this.projectId,
    this.centroCustoId,
    required this.tipo,
    required this.origem,
    this.origemId,
    this.descricao,
    required this.valor,
    this.vencimento,
    this.notaFiscalStoragePath,
    required this.lancadoPorEmployeeId,
    this.status = StatusDespesa.lancada,
    this.aprovadoPorEmployeeId,
    this.aprovadoEm,
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DespesaRecord copyWith({
    String? id,
    String? codigo,
    String? projectId,
    String? centroCustoId,
    String? tipo,
    String? origem,
    String? origemId,
    String? descricao,
    double? valor,
    DateTime? vencimento,
    String? notaFiscalStoragePath,
    String? lancadoPorEmployeeId,
    String? status,
    String? aprovadoPorEmployeeId,
    DateTime? aprovadoEm,
    bool? deleted,
    bool? pendingSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DespesaRecord(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      projectId: projectId ?? this.projectId,
      centroCustoId: centroCustoId ?? this.centroCustoId,
      tipo: tipo ?? this.tipo,
      origem: origem ?? this.origem,
      origemId: origemId ?? this.origemId,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      vencimento: vencimento ?? this.vencimento,
      notaFiscalStoragePath: notaFiscalStoragePath ?? this.notaFiscalStoragePath,
      lancadoPorEmployeeId: lancadoPorEmployeeId ?? this.lancadoPorEmployeeId,
      status: status ?? this.status,
      aprovadoPorEmployeeId: aprovadoPorEmployeeId ?? this.aprovadoPorEmployeeId,
      aprovadoEm: aprovadoEm ?? this.aprovadoEm,
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
      'projectId': projectId,
      'centroCustoId': centroCustoId,
      'tipo': tipo,
      'origem': origem,
      'origemId': origemId,
      'descricao': descricao,
      'valor': valor,
      'vencimento': vencimento == null ? null : Timestamp.fromDate(vencimento!),
      'notaFiscalStoragePath': notaFiscalStoragePath,
      'lancadoPorEmployeeId': lancadoPorEmployeeId,
      'status': status,
      'aprovadoPorEmployeeId': aprovadoPorEmployeeId,
      'aprovadoEm': aprovadoEm == null ? null : Timestamp.fromDate(aprovadoEm!),
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory DespesaRecord.fromMap(Map<String, dynamic> map) {
    return DespesaRecord(
      id: (map['id'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      centroCustoId: map['centroCustoId']?.toString().isNotEmpty == true
          ? map['centroCustoId'].toString()
          : null,
      tipo: (map['tipo'] ?? TipoDespesa.naoControlada).toString(),
      origem: (map['origem'] ?? OrigemDespesa.avulsa).toString(),
      origemId: map['origemId']?.toString(),
      descricao: map['descricao']?.toString(),
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      vencimento: _toDateOrNull(map['vencimento']),
      notaFiscalStoragePath: map['notaFiscalStoragePath']?.toString(),
      lancadoPorEmployeeId: (map['lancadoPorEmployeeId'] ?? '').toString(),
      status: (map['status'] ?? StatusDespesa.lancada).toString(),
      aprovadoPorEmployeeId: map['aprovadoPorEmployeeId']?.toString(),
      aprovadoEm: _toDateOrNull(map['aprovadoEm']),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
