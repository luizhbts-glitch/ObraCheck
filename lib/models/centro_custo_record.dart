import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'centro_custo_record.g.dart';

/// Centro de custo — classificação orçamentária da obra, estilo EAP
/// (ex.: "1.7 - Instalações elétricas"). Confirmado contra o sistema de
/// referência (L7) em 2026-07-18: toda Requisição/Cotação/Ordem de
/// compra/Despesa carrega um centro de custo. Cada obra tem sua própria
/// lista.
@HiveType(typeId: 22)
class CentroCustoRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String codigo;

  @HiveField(3)
  final String nome;

  @HiveField(4)
  final double? orcado;

  @HiveField(5)
  final bool isActive;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  CentroCustoRecord({
    required this.id,
    required this.projectId,
    required this.codigo,
    required this.nome,
    this.orcado,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get codigoNome => nome.isEmpty ? codigo : '$codigo - $nome';

  CentroCustoRecord copyWith({
    String? id,
    String? projectId,
    String? codigo,
    String? nome,
    double? orcado,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CentroCustoRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      codigo: codigo ?? this.codigo,
      nome: nome ?? this.nome,
      orcado: orcado ?? this.orcado,
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
      'codigo': codigo,
      'nome': nome,
      'orcado': orcado,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory CentroCustoRecord.fromMap(Map<String, dynamic> map) {
    return CentroCustoRecord(
      id: (map['id'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      orcado: (map['orcado'] as num?)?.toDouble(),
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
