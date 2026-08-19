import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'medicao_empreiteiro_record.g.dart';

class StatusMedicao {
  static const String rascunho = 'rascunho';
  static const String enviada = 'enviada';
  static const String aprovada = 'aprovada';
  static const String paga = 'paga';
}

/// Item medido: quanto do orçamento foi de fato executado neste período.
@HiveType(typeId: 31)
class ItemMedicao {
  @HiveField(0)
  final String descritivoServicoId;

  @HiveField(1)
  final double quantidadeMedida;

  @HiveField(2)
  final double valorUnitario;

  const ItemMedicao({
    required this.descritivoServicoId,
    required this.quantidadeMedida,
    required this.valorUnitario,
  });

  double get valorMedido => quantidadeMedida * valorUnitario;

  Map<String, dynamic> toMap() {
    return {
      'descritivoServicoId': descritivoServicoId,
      'quantidadeMedida': quantidadeMedida,
      'valorUnitario': valorUnitario,
    };
  }

  factory ItemMedicao.fromMap(Map<String, dynamic> map) {
    return ItemMedicao(
      descritivoServicoId: (map['descritivoServicoId'] ?? '').toString(),
      quantidadeMedida: (map['quantidadeMedida'] as num?)?.toDouble() ?? 0,
      valorUnitario: (map['valorUnitario'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Medição periódica (normalmente mensal) de um empreiteiro: calcula
/// bruto → líquido a pagar. Decidido em 2026-07-18: bruto − adiantamento
/// − desconto de imposto − desconto comercial = líquido.
@HiveType(typeId: 32)
class MedicaoEmpreiteiroRecord extends HiveObject {
  @HiveField(0)
  final String id;

  /// Gerado uma vez, imutável — "serviço controlado" no vocabulário do
  /// plano ERP.
  @HiveField(1)
  final String codigo;

  @HiveField(2)
  final String orcamentoServicoId;

  @HiveField(3)
  final String empreiteiroId;

  @HiveField(4)
  final String projectId;

  @HiveField(5)
  final String? centroCustoId;

  @HiveField(6)
  final String periodo;

  @HiveField(7)
  final List<ItemMedicao> itens;

  @HiveField(8)
  final double adiantamentoDeduzido;

  @HiveField(9)
  final double descontoImposto;

  @HiveField(10)
  final double descontoComercial;

  @HiveField(11)
  final String status;

  @HiveField(12)
  final bool deleted;

  @HiveField(13)
  final bool pendingSync;

  @HiveField(14)
  final DateTime createdAt;

  @HiveField(15)
  final DateTime updatedAt;

  MedicaoEmpreiteiroRecord({
    required this.id,
    required this.codigo,
    required this.orcamentoServicoId,
    required this.empreiteiroId,
    required this.projectId,
    this.centroCustoId,
    required this.periodo,
    List<ItemMedicao>? itens,
    this.adiantamentoDeduzido = 0,
    this.descontoImposto = 0,
    this.descontoComercial = 0,
    this.status = StatusMedicao.rascunho,
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
    required this.updatedAt,
  }) : itens = itens ?? const [];

  double get valorBrutoMedido =>
      itens.fold(0.0, (total, item) => total + item.valorMedido);

  double get valorLiquidoAPagar =>
      valorBrutoMedido - adiantamentoDeduzido - descontoImposto - descontoComercial;

  MedicaoEmpreiteiroRecord copyWith({
    String? id,
    String? codigo,
    String? orcamentoServicoId,
    String? empreiteiroId,
    String? projectId,
    String? centroCustoId,
    String? periodo,
    List<ItemMedicao>? itens,
    double? adiantamentoDeduzido,
    double? descontoImposto,
    double? descontoComercial,
    String? status,
    bool? deleted,
    bool? pendingSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicaoEmpreiteiroRecord(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      orcamentoServicoId: orcamentoServicoId ?? this.orcamentoServicoId,
      empreiteiroId: empreiteiroId ?? this.empreiteiroId,
      projectId: projectId ?? this.projectId,
      centroCustoId: centroCustoId ?? this.centroCustoId,
      periodo: periodo ?? this.periodo,
      itens: itens ?? this.itens,
      adiantamentoDeduzido: adiantamentoDeduzido ?? this.adiantamentoDeduzido,
      descontoImposto: descontoImposto ?? this.descontoImposto,
      descontoComercial: descontoComercial ?? this.descontoComercial,
      status: status ?? this.status,
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
      'orcamentoServicoId': orcamentoServicoId,
      'empreiteiroId': empreiteiroId,
      'projectId': projectId,
      'centroCustoId': centroCustoId,
      'periodo': periodo,
      'itens': itens.map((i) => i.toMap()).toList(),
      'adiantamentoDeduzido': adiantamentoDeduzido,
      'descontoImposto': descontoImposto,
      'descontoComercial': descontoComercial,
      'status': status,
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MedicaoEmpreiteiroRecord.fromMap(Map<String, dynamic> map) {
    final rawItens = map['itens'];
    final itens = rawItens is List
        ? rawItens
            .whereType<Map>()
            .map((m) => ItemMedicao.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <ItemMedicao>[];

    return MedicaoEmpreiteiroRecord(
      id: (map['id'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      orcamentoServicoId: (map['orcamentoServicoId'] ?? '').toString(),
      empreiteiroId: (map['empreiteiroId'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      centroCustoId: map['centroCustoId']?.toString().isNotEmpty == true
          ? map['centroCustoId'].toString()
          : null,
      periodo: (map['periodo'] ?? '').toString(),
      itens: itens,
      adiantamentoDeduzido: (map['adiantamentoDeduzido'] as num?)?.toDouble() ?? 0,
      descontoImposto: (map['descontoImposto'] as num?)?.toDouble() ?? 0,
      descontoComercial: (map['descontoComercial'] as num?)?.toDouble() ?? 0,
      status: (map['status'] ?? StatusMedicao.rascunho).toString(),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
