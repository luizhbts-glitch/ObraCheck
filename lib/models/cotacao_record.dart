import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'cotacao_record.g.dart';

/// Item cotado: mesma descrição da requisição + valor unitário proposto
/// por este fornecedor.
@HiveType(typeId: 25)
class ItemCotacao {
  @HiveField(0)
  final String descricao;

  @HiveField(1)
  final String quantidade;

  @HiveField(2)
  final String unidade;

  @HiveField(3)
  final double valorUnitario;

  /// Herdado do `ItemRequisicao` de origem, quando o item veio do
  /// catálogo — usado pra atualizar `custoMedioReferencia`/`ultimaCompraEm`
  /// no `MaterialCatalogoRecord` quando o pedido é aprovado.
  @HiveField(4)
  final String? materialCatalogoId;

  const ItemCotacao({
    required this.descricao,
    required this.quantidade,
    this.unidade = '',
    this.valorUnitario = 0,
    this.materialCatalogoId,
  });

  double get valorTotal {
    final qtd = double.tryParse(quantidade.replaceAll(',', '.')) ?? 0;
    return qtd * valorUnitario;
  }

  Map<String, dynamic> toMap() {
    return {
      'descricao': descricao,
      'quantidade': quantidade,
      'unidade': unidade,
      'valorUnitario': valorUnitario,
      'materialCatalogoId': materialCatalogoId,
    };
  }

  factory ItemCotacao.fromMap(Map<String, dynamic> map) {
    return ItemCotacao(
      descricao: (map['descricao'] ?? '').toString(),
      quantidade: (map['quantidade'] ?? '').toString(),
      unidade: (map['unidade'] ?? '').toString(),
      valorUnitario: (map['valorUnitario'] as num?)?.toDouble() ?? 0,
      materialCatalogoId: map['materialCatalogoId']?.toString().isNotEmpty == true
          ? map['materialCatalogoId'].toString()
          : null,
    );
  }
}

/// Cotação: proposta de um fornecedor pra uma requisição. Uma requisição
/// pode ter mais de uma cotação (comparação lado a lado); a vencedora
/// converte em [PedidoCompraRecord] — a cotação em si não é compromisso.
@HiveType(typeId: 26)
class CotacaoRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String codigo;

  @HiveField(2)
  final String requisicaoId;

  @HiveField(3)
  final String fornecedorId;

  @HiveField(4)
  final List<ItemCotacao> itens;

  @HiveField(5)
  final double? frete;

  @HiveField(6)
  final double? desconto;

  @HiveField(7)
  final String? prazoEntrega;

  @HiveField(8)
  final String? condicaoPagamento;

  @HiveField(9)
  final bool vencedora;

  @HiveField(10)
  final String? comentario;

  @HiveField(11)
  final bool deleted;

  @HiveField(12)
  final bool pendingSync;

  @HiveField(13)
  final DateTime createdAt;

  @HiveField(14)
  final DateTime updatedAt;

  CotacaoRecord({
    required this.id,
    required this.codigo,
    required this.requisicaoId,
    required this.fornecedorId,
    List<ItemCotacao>? itens,
    this.frete,
    this.desconto,
    this.prazoEntrega,
    this.condicaoPagamento,
    this.vencedora = false,
    this.comentario,
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
    required this.updatedAt,
  }) : itens = itens ?? const [];

  double get subtotal =>
      itens.fold(0.0, (total, item) => total + item.valorTotal);

  double get valorTotal => subtotal + (frete ?? 0) - (desconto ?? 0);

  CotacaoRecord copyWith({
    String? id,
    String? codigo,
    String? requisicaoId,
    String? fornecedorId,
    List<ItemCotacao>? itens,
    double? frete,
    double? desconto,
    String? prazoEntrega,
    String? condicaoPagamento,
    bool? vencedora,
    String? comentario,
    bool? deleted,
    bool? pendingSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CotacaoRecord(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      requisicaoId: requisicaoId ?? this.requisicaoId,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      itens: itens ?? this.itens,
      frete: frete ?? this.frete,
      desconto: desconto ?? this.desconto,
      prazoEntrega: prazoEntrega ?? this.prazoEntrega,
      condicaoPagamento: condicaoPagamento ?? this.condicaoPagamento,
      vencedora: vencedora ?? this.vencedora,
      comentario: comentario ?? this.comentario,
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
      'requisicaoId': requisicaoId,
      'fornecedorId': fornecedorId,
      'itens': itens.map((i) => i.toMap()).toList(),
      'frete': frete,
      'desconto': desconto,
      'prazoEntrega': prazoEntrega,
      'condicaoPagamento': condicaoPagamento,
      'vencedora': vencedora,
      'comentario': comentario,
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory CotacaoRecord.fromMap(Map<String, dynamic> map) {
    final rawItens = map['itens'];
    final itens = rawItens is List
        ? rawItens
            .whereType<Map>()
            .map((m) => ItemCotacao.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <ItemCotacao>[];

    return CotacaoRecord(
      id: (map['id'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      requisicaoId: (map['requisicaoId'] ?? '').toString(),
      fornecedorId: (map['fornecedorId'] ?? '').toString(),
      itens: itens,
      frete: (map['frete'] as num?)?.toDouble(),
      desconto: (map['desconto'] as num?)?.toDouble(),
      prazoEntrega: map['prazoEntrega']?.toString(),
      condicaoPagamento: map['condicaoPagamento']?.toString(),
      vencedora: map['vencedora'] == true,
      comentario: map['comentario']?.toString(),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
