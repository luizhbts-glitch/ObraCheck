import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'cargo_record.g.dart';

/// Cargo do organograma da construtora.
///
/// Nível hierárquico segue o organograma decidido em 2026-07-18:
/// 1=Diretor, 2=TI, 3=Coordenador de obras,
/// 4=Engenheiro/Compras/Financeiro, 5=Auxiliar de engenharia/administrativo/
/// comercial, 6=Estagiário. Usado pra resolver quem pode conceder permissão
/// pra quem (regra do teto: só quem está acima na cadeia de avaliador, e só
/// até o próprio teto de acesso).
@HiveType(typeId: 15)
class CargoRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String orgId;

  @HiveField(2)
  final String nome;

  @HiveField(3)
  final int nivelHierarquico;

  /// Perfil de acesso sugerido como padrão pra quem tem esse cargo — só um
  /// ponto de partida, cada funcionário pode receber outro perfil.
  @HiveField(4)
  final String? perfilAcessoIdPadrao;

  @HiveField(5)
  final bool isActive;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  CargoRecord({
    required this.id,
    required this.orgId,
    required this.nome,
    required this.nivelHierarquico,
    this.perfilAcessoIdPadrao,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  CargoRecord copyWith({
    String? id,
    String? orgId,
    String? nome,
    int? nivelHierarquico,
    String? perfilAcessoIdPadrao,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CargoRecord(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      nome: nome ?? this.nome,
      nivelHierarquico: nivelHierarquico ?? this.nivelHierarquico,
      perfilAcessoIdPadrao: perfilAcessoIdPadrao ?? this.perfilAcessoIdPadrao,
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
      'nivelHierarquico': nivelHierarquico,
      'perfilAcessoIdPadrao': perfilAcessoIdPadrao,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory CargoRecord.fromMap(Map<String, dynamic> map) {
    return CargoRecord(
      id: (map['id'] ?? '').toString(),
      orgId: (map['orgId'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      nivelHierarquico: (map['nivelHierarquico'] is int)
          ? map['nivelHierarquico'] as int
          : int.tryParse('${map['nivelHierarquico']}') ?? 6,
      perfilAcessoIdPadrao: map['perfilAcessoIdPadrao']?.toString(),
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
