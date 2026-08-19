import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'orcamento_servico_record.g.dart';

/// Item do orçamento: descritivo + quantidade orçada.
@HiveType(typeId: 29)
class ItemOrcamento {
  @HiveField(0)
  final String descritivoServicoId;

  @HiveField(1)
  final double quantidadeOrcada;

  @HiveField(2)
  final double valorUnitario;

  const ItemOrcamento({
    required this.descritivoServicoId,
    required this.quantidadeOrcada,
    required this.valorUnitario,
  });

  double get valorTotal => quantidadeOrcada * valorUnitario;

  Map<String, dynamic> toMap() {
    return {
      'descritivoServicoId': descritivoServicoId,
      'quantidadeOrcada': quantidadeOrcada,
      'valorUnitario': valorUnitario,
    };
  }

  factory ItemOrcamento.fromMap(Map<String, dynamic> map) {
    return ItemOrcamento(
      descritivoServicoId: (map['descritivoServicoId'] ?? '').toString(),
      quantidadeOrcada: (map['quantidadeOrcada'] as num?)?.toDouble() ?? 0,
      valorUnitario: (map['valorUnitario'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Orçamento de serviço com um empreiteiro numa obra — soma de itens do
/// descritivo com quantidade orçada. Base pra medições periódicas.
@HiveType(typeId: 30)
class OrcamentoServicoRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String empreiteiroId;

  @HiveField(3)
  final List<ItemOrcamento> itens;

  @HiveField(4)
  final bool isActive;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  OrcamentoServicoRecord({
    required this.id,
    required this.projectId,
    required this.empreiteiroId,
    List<ItemOrcamento>? itens,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  }) : itens = itens ?? const [];

  double get valorTotalOrcamento =>
      itens.fold(0.0, (total, item) => total + item.valorTotal);

  OrcamentoServicoRecord copyWith({
    String? id,
    String? projectId,
    String? empreiteiroId,
    List<ItemOrcamento>? itens,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrcamentoServicoRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      empreiteiroId: empreiteiroId ?? this.empreiteiroId,
      itens: itens ?? this.itens,
      isActive: isActive ?? this.isActive,
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
      'empreiteiroId': empreiteiroId,
      'itens': itens.map((i) => i.toMap()).toList(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory OrcamentoServicoRecord.fromMap(Map<String, dynamic> map) {
    final rawItens = map['itens'];
    final itens = rawItens is List
        ? rawItens
            .whereType<Map>()
            .map((m) => ItemOrcamento.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <ItemOrcamento>[];

    return OrcamentoServicoRecord(
      id: (map['id'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      empreiteiroId: (map['empreiteiroId'] ?? '').toString(),
      itens: itens,
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
