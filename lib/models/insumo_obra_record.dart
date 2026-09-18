import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'insumo_obra_record.g.dart';

/// Unidades de medida disponíveis pro cadastro de insumo — cada material
/// usa a que fizer sentido (fita em dezena, tinta em litro, etc.).
/// Especificado com o usuário em 2026-09-18.
class UnidadeMedida {
  static const String unidade = 'Unidade';
  static const String dezena = 'Dezena';
  static const String litro = 'Litro';
  static const String metro = 'Metro';
  static const String metroQuadrado = 'Metro²';
  static const String metroCubico = 'Metro³';
  static const String quilograma = 'Quilograma';
  static const String saco = 'Saco';
  static const String caixa = 'Caixa';
  static const String rolo = 'Rolo';
  static const String par = 'Par';

  static const List<String> todas = [
    unidade,
    dezena,
    litro,
    metro,
    metroQuadrado,
    metroCubico,
    quilograma,
    saco,
    caixa,
    rolo,
    par,
  ];
}

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

  @HiveField(10)
  final String unidade;

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
    this.unidade = UnidadeMedida.unidade,
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
    String? unidade,
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
      unidade: unidade ?? this.unidade,
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
      'unidade': unidade,
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
      unidade: (map['unidade']?.toString().trim().isNotEmpty == true)
          ? map['unidade'].toString()
          : UnidadeMedida.unidade,
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

/// Conferência de estoque de um insumo — não é um log de auditoria
/// burocrático, é um controle: sempre que o insumo teve retirada desde a
/// última conferência, alguém precisa recontar fisicamente e confirmar
/// (ou corrigir) o que o sistema acha que tem em estoque. Divergência
/// vira "ocorrência" — exige uma explicação de quem conferiu, não só o
/// número novo. Especificado com o usuário em 2026-09-18.
@HiveType(typeId: 39)
class InsumoConferenciaRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String insumoId;

  @HiveField(3)
  final String material;

  @HiveField(4)
  final String unidade;

  @HiveField(5)
  final double quantidadeEsperada;

  @HiveField(6)
  final double quantidadeConferida;

  @HiveField(7)
  final double divergencia;

  @HiveField(8)
  final String? observacao;

  @HiveField(9)
  final bool deleted;

  @HiveField(10)
  final bool pendingSync;

  @HiveField(11)
  final DateTime createdAt;

  InsumoConferenciaRecord({
    required this.id,
    required this.projectId,
    required this.insumoId,
    required this.material,
    required this.unidade,
    required this.quantidadeEsperada,
    required this.quantidadeConferida,
    required this.divergencia,
    this.observacao,
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
  });

  bool get temDivergencia => divergencia != 0;

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
      'unidade': unidade,
      'quantidadeEsperada': quantidadeEsperada,
      'quantidadeConferida': quantidadeConferida,
      'divergencia': divergencia,
      'observacao': observacao,
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory InsumoConferenciaRecord.fromMap(Map<String, dynamic> map) {
    return InsumoConferenciaRecord(
      id: (map['id'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      insumoId: (map['insumoId'] ?? '').toString(),
      material: (map['material'] ?? '').toString(),
      unidade: (map['unidade'] ?? '').toString(),
      quantidadeEsperada: (map['quantidadeEsperada'] as num?)?.toDouble() ?? 0,
      quantidadeConferida: (map['quantidadeConferida'] as num?)?.toDouble() ?? 0,
      divergencia: (map['divergencia'] as num?)?.toDouble() ?? 0,
      observacao: map['observacao']?.toString(),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
    );
  }
}
