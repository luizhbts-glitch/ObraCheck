import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import 'perfil_acesso_record.dart';

part 'employee_record.g.dart';

/// Ajuste fino de permissão por pessoa, em cima do que o perfil já dá.
/// `liberado: false` revoga algo que o perfil concederia; `liberado: true`
/// concede algo além do perfil — mas só até o teto de quem concedeu (regra
/// validada no serviço que resolve a concessão, não aqui no model).
@HiveType(typeId: 19)
class PermissaoOverride {
  @HiveField(0)
  final PermissaoItem permissao;

  @HiveField(1)
  final bool liberado;

  @HiveField(2)
  final String concedidoPorEmployeeId;

  @HiveField(3)
  final DateTime concedidoEm;

  const PermissaoOverride({
    required this.permissao,
    required this.liberado,
    required this.concedidoPorEmployeeId,
    required this.concedidoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'permissao': permissao.toMap(),
      'liberado': liberado,
      'concedidoPorEmployeeId': concedidoPorEmployeeId,
      'concedidoEm': Timestamp.fromDate(concedidoEm),
    };
  }

  factory PermissaoOverride.fromMap(Map<String, dynamic> map) {
    final rawPermissao = map['permissao'];
    return PermissaoOverride(
      permissao: rawPermissao is Map
          ? PermissaoItem.fromMap(Map<String, dynamic>.from(rawPermissao))
          : const PermissaoItem(modulo: '', entidade: '', acao: ''),
      liberado: map['liberado'] == true,
      concedidoPorEmployeeId: (map['concedidoPorEmployeeId'] ?? '').toString(),
      concedidoEm: map['concedidoEm'] is Timestamp
          ? (map['concedidoEm'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

/// Registro de RH > Funcionários.
///
/// Nem todo funcionário tem login no app (ex.: servente de obra sem acesso
/// digital) — `userId` fica vazio nesse caso. Quando existe, é o vínculo
/// com a conta real usada pra resolver permissão (ver [[PerfilAcessoRecord]]).
@HiveType(typeId: 16)
class EmployeeRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String orgId;

  /// Obra onde está lotado, ou vazio pra "Adm" (escritório/sede).
  @HiveField(2)
  final String projectId;

  @HiveField(3)
  final String cargoId;

  @HiveField(4)
  final String nome;

  /// FK pra outro EmployeeRecord — a quem esse funcionário responde
  /// (organograma). Vazio no topo da cadeia (ex.: Diretor).
  @HiveField(5)
  final String? avaliadorEmployeeId;

  @HiveField(6)
  final bool isActive;

  /// Conta do app vinculada a este funcionário, se houver.
  @HiveField(7)
  final String? userId;

  /// Perfil de acesso efetivo — se vazio, cai no padrão sugerido pelo cargo.
  @HiveField(8)
  final String? perfilAcessoId;

  /// Ajustes finos de permissão além do que o perfil dá — ver [[PermissaoOverride]].
  @HiveField(9)
  final List<PermissaoOverride> permissaoOverrides;

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final DateTime updatedAt;

  EmployeeRecord({
    required this.id,
    required this.orgId,
    this.projectId = '',
    required this.cargoId,
    required this.nome,
    this.avaliadorEmployeeId,
    this.isActive = true,
    this.userId,
    this.perfilAcessoId,
    List<PermissaoOverride>? permissaoOverrides,
    required this.createdAt,
    required this.updatedAt,
  }) : permissaoOverrides = permissaoOverrides ?? const [];

  EmployeeRecord copyWith({
    String? id,
    String? orgId,
    String? projectId,
    String? cargoId,
    String? nome,
    String? avaliadorEmployeeId,
    bool? isActive,
    String? userId,
    String? perfilAcessoId,
    List<PermissaoOverride>? permissaoOverrides,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeRecord(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      projectId: projectId ?? this.projectId,
      cargoId: cargoId ?? this.cargoId,
      nome: nome ?? this.nome,
      avaliadorEmployeeId: avaliadorEmployeeId ?? this.avaliadorEmployeeId,
      isActive: isActive ?? this.isActive,
      userId: userId ?? this.userId,
      perfilAcessoId: perfilAcessoId ?? this.perfilAcessoId,
      permissaoOverrides: permissaoOverrides ?? this.permissaoOverrides,
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
      'projectId': projectId,
      'cargoId': cargoId,
      'nome': nome,
      'avaliadorEmployeeId': avaliadorEmployeeId,
      'isActive': isActive,
      'userId': userId,
      'perfilAcessoId': perfilAcessoId,
      'permissaoOverrides': permissaoOverrides.map((o) => o.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EmployeeRecord.fromMap(Map<String, dynamic> map) {
    final rawOverrides = map['permissaoOverrides'];
    final overrides = rawOverrides is List
        ? rawOverrides
            .whereType<Map>()
            .map((m) => PermissaoOverride.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <PermissaoOverride>[];

    return EmployeeRecord(
      id: (map['id'] ?? '').toString(),
      orgId: (map['orgId'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      cargoId: (map['cargoId'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      avaliadorEmployeeId: map['avaliadorEmployeeId']?.toString().isNotEmpty == true
          ? map['avaliadorEmployeeId'].toString()
          : null,
      isActive: map['isActive'] != false,
      userId: map['userId']?.toString().isNotEmpty == true
          ? map['userId'].toString()
          : null,
      perfilAcessoId: map['perfilAcessoId']?.toString().isNotEmpty == true
          ? map['perfilAcessoId'].toString()
          : null,
      permissaoOverrides: overrides,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
