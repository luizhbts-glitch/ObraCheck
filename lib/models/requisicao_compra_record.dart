import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'requisicao_compra_record.g.dart';

class StatusRequisicao {
  static const String aberta = 'aberta';
  static const String emCotacao = 'em_cotacao';
  static const String aprovada = 'aprovada';
  static const String rejeitada = 'rejeitada';
  static const String virouPedido = 'virou_pedido';
}

/// Item de uma requisição — descrição livre + referência opcional ao
/// catálogo de materiais.
@HiveType(typeId: 23)
class ItemRequisicao {
  @HiveField(0)
  final String? materialCatalogoId;

  @HiveField(1)
  final String descricao;

  @HiveField(2)
  final String quantidade;

  @HiveField(3)
  final String unidade;

  const ItemRequisicao({
    this.materialCatalogoId,
    required this.descricao,
    required this.quantidade,
    this.unidade = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'materialCatalogoId': materialCatalogoId,
      'descricao': descricao,
      'quantidade': quantidade,
      'unidade': unidade,
    };
  }

  factory ItemRequisicao.fromMap(Map<String, dynamic> map) {
    return ItemRequisicao(
      materialCatalogoId: map['materialCatalogoId']?.toString().isNotEmpty == true
          ? map['materialCatalogoId'].toString()
          : null,
      descricao: (map['descricao'] ?? '').toString(),
      quantidade: (map['quantidade'] ?? '').toString(),
      unidade: (map['unidade'] ?? '').toString(),
    );
  }
}

/// Requisição de compra: pedido inicial vindo da obra (ou do escritório).
/// Não é ainda compromisso financeiro, só uma solicitação — vira
/// compromisso quando uma cotação é aprovada e converte em
/// [PedidoCompraRecord].
@HiveType(typeId: 24)
class RequisicaoCompraRecord extends HiveObject {
  @HiveField(0)
  final String id;

  /// Gerado uma vez na criação, imutável — acompanha o registro até o fim
  /// do fluxo (convenção decidida em 2026-07-18).
  @HiveField(1)
  final String codigo;

  @HiveField(2)
  final String projectId;

  @HiveField(3)
  final String? centroCustoId;

  @HiveField(4)
  final String solicitanteEmployeeId;

  @HiveField(5)
  final List<ItemRequisicao> itens;

  @HiveField(6)
  final String urgencia;

  @HiveField(7)
  final String status;

  @HiveField(8)
  final String? observacao;

  @HiveField(9)
  final bool deleted;

  @HiveField(10)
  final bool pendingSync;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final DateTime updatedAt;

  RequisicaoCompraRecord({
    required this.id,
    required this.codigo,
    required this.projectId,
    this.centroCustoId,
    required this.solicitanteEmployeeId,
    List<ItemRequisicao>? itens,
    this.urgencia = 'normal',
    this.status = StatusRequisicao.aberta,
    this.observacao,
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
    required this.updatedAt,
  }) : itens = itens ?? const [];

  RequisicaoCompraRecord copyWith({
    String? id,
    String? codigo,
    String? projectId,
    String? centroCustoId,
    String? solicitanteEmployeeId,
    List<ItemRequisicao>? itens,
    String? urgencia,
    String? status,
    String? observacao,
    bool? deleted,
    bool? pendingSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RequisicaoCompraRecord(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      projectId: projectId ?? this.projectId,
      centroCustoId: centroCustoId ?? this.centroCustoId,
      solicitanteEmployeeId: solicitanteEmployeeId ?? this.solicitanteEmployeeId,
      itens: itens ?? this.itens,
      urgencia: urgencia ?? this.urgencia,
      status: status ?? this.status,
      observacao: observacao ?? this.observacao,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'projectId': projectId,
      'centroCustoId': centroCustoId,
      'solicitanteEmployeeId': solicitanteEmployeeId,
      'itens': itens.map((i) => i.toMap()).toList(),
      'urgencia': urgencia,
      'status': status,
      'observacao': observacao,
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RequisicaoCompraRecord.fromMap(Map<String, dynamic> map) {
    final rawItens = map['itens'];
    final itens = rawItens is List
        ? rawItens
            .whereType<Map>()
            .map((m) => ItemRequisicao.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <ItemRequisicao>[];

    return RequisicaoCompraRecord(
      id: (map['id'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      centroCustoId: map['centroCustoId']?.toString().isNotEmpty == true
          ? map['centroCustoId'].toString()
          : null,
      solicitanteEmployeeId: (map['solicitanteEmployeeId'] ?? '').toString(),
      itens: itens,
      urgencia: (map['urgencia'] ?? 'normal').toString(),
      status: (map['status'] ?? StatusRequisicao.aberta).toString(),
      observacao: map['observacao']?.toString(),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
