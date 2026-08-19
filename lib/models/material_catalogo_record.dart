import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'material_catalogo_record.g.dart';

/// Catálogo mestre de materiais — confirmado contra o sistema de
/// referência (L7) em 2026-07-18. Requisições selecionam itens daqui em
/// vez de digitar tudo em texto livre; `custoMedioReferencia` orienta o
/// valor estimado antes de cotar de verdade.
@HiveType(typeId: 21)
class MaterialCatalogoRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String orgId;

  @HiveField(2)
  final String categoria;

  @HiveField(3)
  final String produto;

  @HiveField(4)
  final String unidadeMedida;

  @HiveField(5)
  final double? custoMedioReferencia;

  @HiveField(6)
  final DateTime? ultimaCompraEm;

  @HiveField(7)
  final bool isActive;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime updatedAt;

  MaterialCatalogoRecord({
    required this.id,
    required this.orgId,
    this.categoria = '',
    required this.produto,
    this.unidadeMedida = '',
    this.custoMedioReferencia,
    this.ultimaCompraEm,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  MaterialCatalogoRecord copyWith({
    String? id,
    String? orgId,
    String? categoria,
    String? produto,
    String? unidadeMedida,
    double? custoMedioReferencia,
    DateTime? ultimaCompraEm,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialCatalogoRecord(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      categoria: categoria ?? this.categoria,
      produto: produto ?? this.produto,
      unidadeMedida: unidadeMedida ?? this.unidadeMedida,
      custoMedioReferencia: custoMedioReferencia ?? this.custoMedioReferencia,
      ultimaCompraEm: ultimaCompraEm ?? this.ultimaCompraEm,
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

  static DateTime? _toDateOrNull(dynamic value) {
    if (value == null) return null;
    return _toDate(value);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orgId': orgId,
      'categoria': categoria,
      'produto': produto,
      'unidadeMedida': unidadeMedida,
      'custoMedioReferencia': custoMedioReferencia,
      'ultimaCompraEm':
          ultimaCompraEm == null ? null : Timestamp.fromDate(ultimaCompraEm!),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MaterialCatalogoRecord.fromMap(Map<String, dynamic> map) {
    return MaterialCatalogoRecord(
      id: (map['id'] ?? '').toString(),
      orgId: (map['orgId'] ?? '').toString(),
      categoria: (map['categoria'] ?? '').toString(),
      produto: (map['produto'] ?? '').toString(),
      unidadeMedida: (map['unidadeMedida'] ?? '').toString(),
      custoMedioReferencia: (map['custoMedioReferencia'] as num?)?.toDouble(),
      ultimaCompraEm: _toDateOrNull(map['ultimaCompraEm']),
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
