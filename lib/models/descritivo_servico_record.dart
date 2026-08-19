import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'descritivo_servico_record.g.dart';

/// Catálogo de serviços com valor unitário — base do orçamento de
/// empreiteiro (ex.: "alvenaria de vedação — m² — R\$ X").
@HiveType(typeId: 28)
class DescritivoServicoRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String orgId;

  @HiveField(2)
  final String descricao;

  @HiveField(3)
  final String unidadeMedida;

  @HiveField(4)
  final double valorUnitarioReferencia;

  @HiveField(5)
  final bool isActive;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  DescritivoServicoRecord({
    required this.id,
    required this.orgId,
    required this.descricao,
    this.unidadeMedida = '',
    this.valorUnitarioReferencia = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  DescritivoServicoRecord copyWith({
    String? id,
    String? orgId,
    String? descricao,
    String? unidadeMedida,
    double? valorUnitarioReferencia,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DescritivoServicoRecord(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      descricao: descricao ?? this.descricao,
      unidadeMedida: unidadeMedida ?? this.unidadeMedida,
      valorUnitarioReferencia: valorUnitarioReferencia ?? this.valorUnitarioReferencia,
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
      'descricao': descricao,
      'unidadeMedida': unidadeMedida,
      'valorUnitarioReferencia': valorUnitarioReferencia,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory DescritivoServicoRecord.fromMap(Map<String, dynamic> map) {
    return DescritivoServicoRecord(
      id: (map['id'] ?? '').toString(),
      orgId: (map['orgId'] ?? '').toString(),
      descricao: (map['descricao'] ?? '').toString(),
      unidadeMedida: (map['unidadeMedida'] ?? '').toString(),
      valorUnitarioReferencia: (map['valorUnitarioReferencia'] as num?)?.toDouble() ?? 0,
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
