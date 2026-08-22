import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'insumo_obra_record.g.dart';

/// Planilha simples de estoque de material de consumo (insumo), separada
/// do fluxo formal de Compras. Especificado com o usuário em 2026-08-22:
/// material + endereço (local físico), estoque mínimo (base pro alerta
/// visual de reposição) e saída informal (sem aprovação).
@HiveType(typeId: 37)
class InsumoObraRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String material;

  @HiveField(3)
  final String endereco;

  @HiveField(4)
  final double estoqueMinimo;

  @HiveField(5)
  final double quantidadeAtual;

  @HiveField(6)
  final bool deleted;

  @HiveField(7)
  final bool pendingSync;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime updatedAt;

  InsumoObraRecord({
    required this.id,
    required this.projectId,
    required this.material,
    this.endereco = '',
    this.estoqueMinimo = 0,
    this.quantidadeAtual = 0,
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get abaixoDoMinimo => quantidadeAtual < estoqueMinimo;

  InsumoObraRecord copyWith({
    String? id,
    String? projectId,
    String? material,
    String? endereco,
    double? estoqueMinimo,
    double? quantidadeAtual,
    bool? deleted,
    bool? pendingSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InsumoObraRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      material: material ?? this.material,
      endereco: endereco ?? this.endereco,
      estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
      quantidadeAtual: quantidadeAtual ?? this.quantidadeAtual,
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
      'projectId': projectId,
      'material': material,
      'endereco': endereco,
      'estoqueMinimo': estoqueMinimo,
      'quantidadeAtual': quantidadeAtual,
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory InsumoObraRecord.fromMap(Map<String, dynamic> map) {
    return InsumoObraRecord(
      id: (map['id'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      material: (map['material'] ?? '').toString(),
      endereco: (map['endereco'] ?? '').toString(),
      estoqueMinimo: (map['estoqueMinimo'] as num?)?.toDouble() ?? 0,
      quantidadeAtual: (map['quantidadeAtual'] as num?)?.toDouble() ?? 0,
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}

/// Movimento de estoque de um insumo — retirada informal ou ajuste de
/// contagem. Existe só pra alimentar o histórico filtrável por material;
/// não tem fluxo de aprovação (é o ponto do "sem formalidades" pedido).
class TipoMovimentoInsumo {
  static const String retirada = 'retirada';
  static const String ajusteContagem = 'ajuste_contagem';
}

@HiveType(typeId: 38)
class InsumoMovimentoRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String insumoId;

  @HiveField(3)
  final String material;

  @HiveField(4)
  final String tipo;

  @HiveField(5)
  final double quantidade;

  @HiveField(6)
  final double saldoResultante;

  @HiveField(7)
  final bool deleted;

  @HiveField(8)
  final bool pendingSync;

  @HiveField(9)
  final DateTime createdAt;

  InsumoMovimentoRecord({
    required this.id,
    required this.projectId,
    required this.insumoId,
    required this.material,
    required this.tipo,
    required this.quantidade,
    required this.saldoResultante,
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
  });

  InsumoMovimentoRecord copyWith({bool? deleted, bool? pendingSync}) {
    return InsumoMovimentoRecord(
      id: id,
      projectId: projectId,
      insumoId: insumoId,
      material: material,
      tipo: tipo,
      quantidade: quantidade,
      saldoResultante: saldoResultante,
      deleted: deleted ?? this.deleted,
      pendingSync: pendingSync ?? this.pendingSync,
      createdAt: createdAt,
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
      'projectId': projectId,
      'insumoId': insumoId,
      'material': material,
      'tipo': tipo,
      'quantidade': quantidade,
      'saldoResultante': saldoResultante,
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory InsumoMovimentoRecord.fromMap(Map<String, dynamic> map) {
    return InsumoMovimentoRecord(
      id: (map['id'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      insumoId: (map['insumoId'] ?? '').toString(),
      material: (map['material'] ?? '').toString(),
      tipo: (map['tipo'] ?? '').toString(),
      quantidade: (map['quantidade'] as num?)?.toDouble() ?? 0,
      saldoResultante: (map['saldoResultante'] as num?)?.toDouble() ?? 0,
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
    );
  }
}
