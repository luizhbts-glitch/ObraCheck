import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'perfil_acesso_record.g.dart';

/// Ações possíveis dentro de uma permissão granular.
class AcaoPermissao {
  static const String criar = 'criar';
  static const String editar = 'editar';
  static const String excluir = 'excluir';
  static const String aprovar = 'aprovar';
  static const String rejeitar = 'rejeitar';
  static const String visualizar = 'visualizar';

  static const List<String> todas = [
    criar,
    editar,
    excluir,
    aprovar,
    rejeitar,
    visualizar,
  ];
}

/// Uma permissão granular: módulo + entidade + ação.
/// Ex.: {modulo: 'Compras', entidade: 'Requisicao', acao: 'Aprovar'}.
@HiveType(typeId: 18)
class PermissaoItem {
  @HiveField(0)
  final String modulo;

  @HiveField(1)
  final String entidade;

  @HiveField(2)
  final String acao;

  const PermissaoItem({
    required this.modulo,
    required this.entidade,
    required this.acao,
  });

  /// Chave estável pra comparar/deduplicar — evita o bug de permissão
  /// repetida que vimos no sistema de referência (L7).
  String get chave => '$modulo.$entidade.$acao';

  Map<String, dynamic> toMap() {
    return {'modulo': modulo, 'entidade': entidade, 'acao': acao};
  }

  factory PermissaoItem.fromMap(Map<String, dynamic> map) {
    return PermissaoItem(
      modulo: (map['modulo'] ?? '').toString(),
      entidade: (map['entidade'] ?? '').toString(),
      acao: (map['acao'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PermissaoItem && other.chave == chave;

  @override
  int get hashCode => chave.hashCode;
}

/// Perfil de acesso: conjunto nomeado e reutilizável de permissões
/// granulares, criado/editado por Diretor ou TI (níveis 1-2 do
/// organograma). Atribuído a funcionários via `EmployeeRecord.perfilAcessoId`.
@HiveType(typeId: 17)
class PerfilAcessoRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String orgId;

  @HiveField(2)
  final String nome;

  @HiveField(3)
  final List<PermissaoItem> permissoes;

  @HiveField(4)
  final String criadoPorEmployeeId;

  @HiveField(5)
  final bool isActive;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  PerfilAcessoRecord({
    required this.id,
    required this.orgId,
    required this.nome,
    List<PermissaoItem>? permissoes,
    required this.criadoPorEmployeeId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  }) : permissoes = _dedupe(permissoes ?? const []);

  /// Deduplicação por chave — a mesma proteção que faltou no sistema de
  /// referência, onde vimos a mesma permissão repetida 3x num perfil.
  static List<PermissaoItem> _dedupe(List<PermissaoItem> itens) {
    final seen = <String>{};
    final out = <PermissaoItem>[];
    for (final item in itens) {
      if (seen.add(item.chave)) out.add(item);
    }
    return out;
  }

  bool tem(String modulo, String entidade, String acao) {
    final chave = '$modulo.$entidade.$acao';
    return permissoes.any((p) => p.chave == chave);
  }

  PerfilAcessoRecord copyWith({
    String? id,
    String? orgId,
    String? nome,
    List<PermissaoItem>? permissoes,
    String? criadoPorEmployeeId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PerfilAcessoRecord(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      nome: nome ?? this.nome,
      permissoes: permissoes ?? this.permissoes,
      criadoPorEmployeeId: criadoPorEmployeeId ?? this.criadoPorEmployeeId,
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
      'orgId': orgId,
      'nome': nome,
      'permissoes': permissoes.map((p) => p.toMap()).toList(),
      'criadoPorEmployeeId': criadoPorEmployeeId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PerfilAcessoRecord.fromMap(Map<String, dynamic> map) {
    final rawPermissoes = map['permissoes'];
    final permissoes = rawPermissoes is List
        ? rawPermissoes
            .whereType<Map>()
            .map((m) => PermissaoItem.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <PermissaoItem>[];

    return PerfilAcessoRecord(
      id: (map['id'] ?? '').toString(),
      orgId: (map['orgId'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      permissoes: permissoes,
      criadoPorEmployeeId: (map['criadoPorEmployeeId'] ?? '').toString(),
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
