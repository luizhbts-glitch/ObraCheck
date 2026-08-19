import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../data/fvs_data.dart';

part 'recebimento_material_record.g.dart';

/// Item verificado no recebimento — mesmo espírito do `InspectionItemResult`
/// do FVS (reaproveitando `FvsProofType`), confirmado em 2026-07-18: o app
/// já resolve bem esse tipo de checklist, não precisa reinventar.
@HiveType(typeId: 33)
class ItemRecebimentoVerificado {
  @HiveField(0)
  final String descricao;

  /// Reaproveita `FvsProofType` (visual, photo_required, measurement,
  /// technical_note, sampled_location) — `technicalNote` cobre o caso do
  /// certificado de carga do bloco estrutural.
  @HiveField(1)
  final String proofType;

  @HiveField(2)
  final String status; // 'ok' | 'nok'

  @HiveField(3)
  final String? certificadoStoragePath;

  @HiveField(4)
  final String? obs;

  const ItemRecebimentoVerificado({
    required this.descricao,
    this.proofType = FvsProofType.visual,
    this.status = 'ok',
    this.certificadoStoragePath,
    this.obs,
  });

  Map<String, dynamic> toMap() {
    return {
      'descricao': descricao,
      'proofType': proofType,
      'status': status,
      'certificadoStoragePath': certificadoStoragePath,
      'obs': obs,
    };
  }

  factory ItemRecebimentoVerificado.fromMap(Map<String, dynamic> map) {
    return ItemRecebimentoVerificado(
      descricao: (map['descricao'] ?? '').toString(),
      proofType: (map['proofType'] ?? FvsProofType.visual).toString(),
      status: (map['status'] ?? 'ok').toString(),
      certificadoStoragePath: map['certificadoStoragePath']?.toString(),
      obs: map['obs']?.toString(),
    );
  }
}

/// Recebimento de material — estende Compras > Ordem de compra com um
/// checklist de qualidade: prazo, condição física ("zerado"), nota do
/// fornecedor e conformidade normativa por item quando aplicável.
@HiveType(typeId: 34)
class RecebimentoMaterialRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String pedidoCompraId;

  @HiveField(2)
  final String fornecedorId;

  @HiveField(3)
  final DateTime dataRecebimento;

  @HiveField(4)
  final bool prazoOk;

  @HiveField(5)
  final bool condicaoOk;

  @HiveField(6)
  final double? qualidadeFornecedorNota;

  @HiveField(7)
  final List<ItemRecebimentoVerificado> itensVerificados;

  @HiveField(8)
  final List<String> fotos;

  @HiveField(9)
  final bool pendingSync;

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final DateTime updatedAt;

  RecebimentoMaterialRecord({
    required this.id,
    required this.pedidoCompraId,
    required this.fornecedorId,
    required this.dataRecebimento,
    this.prazoOk = true,
    this.condicaoOk = true,
    this.qualidadeFornecedorNota,
    List<ItemRecebimentoVerificado>? itensVerificados,
    List<String>? fotos,
    this.pendingSync = false,
    required this.createdAt,
    required this.updatedAt,
  })  : itensVerificados = itensVerificados ?? const [],
        fotos = fotos ?? const [];

  /// Algum item não conforme, ou prazo/condição falhou — reflete no "problema"
  /// que o usuário já rastreava manualmente na ferramenta pessoal dele.
  bool get temProblema =>
      !prazoOk || !condicaoOk || itensVerificados.any((i) => i.status == 'nok');

  RecebimentoMaterialRecord copyWith({
    String? id,
    String? pedidoCompraId,
    String? fornecedorId,
    DateTime? dataRecebimento,
    bool? prazoOk,
    bool? condicaoOk,
    double? qualidadeFornecedorNota,
    List<ItemRecebimentoVerificado>? itensVerificados,
    List<String>? fotos,
    bool? pendingSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecebimentoMaterialRecord(
      id: id ?? this.id,
      pedidoCompraId: pedidoCompraId ?? this.pedidoCompraId,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      dataRecebimento: dataRecebimento ?? this.dataRecebimento,
      prazoOk: prazoOk ?? this.prazoOk,
      condicaoOk: condicaoOk ?? this.condicaoOk,
      qualidadeFornecedorNota: qualidadeFornecedorNota ?? this.qualidadeFornecedorNota,
      itensVerificados: itensVerificados ?? this.itensVerificados,
      fotos: fotos ?? this.fotos,
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
      'pedidoCompraId': pedidoCompraId,
      'fornecedorId': fornecedorId,
      'dataRecebimento': Timestamp.fromDate(dataRecebimento),
      'prazoOk': prazoOk,
      'condicaoOk': condicaoOk,
      'qualidadeFornecedorNota': qualidadeFornecedorNota,
      'itensVerificados': itensVerificados.map((i) => i.toMap()).toList(),
      'fotos': fotos,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RecebimentoMaterialRecord.fromMap(Map<String, dynamic> map) {
    final rawItens = map['itensVerificados'];
    final itens = rawItens is List
        ? rawItens
            .whereType<Map>()
            .map((m) => ItemRecebimentoVerificado.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <ItemRecebimentoVerificado>[];
    final rawFotos = map['fotos'];
    final fotos = rawFotos is List ? rawFotos.map((f) => f.toString()).toList() : <String>[];

    return RecebimentoMaterialRecord(
      id: (map['id'] ?? '').toString(),
      pedidoCompraId: (map['pedidoCompraId'] ?? '').toString(),
      fornecedorId: (map['fornecedorId'] ?? '').toString(),
      dataRecebimento: _toDate(map['dataRecebimento']),
      prazoOk: map['prazoOk'] != false,
      condicaoOk: map['condicaoOk'] != false,
      qualidadeFornecedorNota: (map['qualidadeFornecedorNota'] as num?)?.toDouble(),
      itensVerificados: itens,
      fotos: fotos,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
