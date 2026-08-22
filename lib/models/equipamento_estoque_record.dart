import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'equipamento_estoque_record.g.dart';

/// Controle de estoque de equipamentos (elétricos/mecânicos da obra),
/// separado do controle de saída/devolução (`equipments`/`equipment_movements`).
/// Especificado com o usuário em 2026-08-22: três categorias — próprio,
/// alugado (todos os campos obrigatórios) e de terceiro (agrupado por
/// [terceiroNome], um cartão por subcontratado).
class TipoEquipamentoEstoque {
  static const String proprio = 'proprio';
  static const String alugado = 'alugado';
  static const String terceiro = 'terceiro';
}

@HiveType(typeId: 36)
class EquipamentoEstoqueRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String tipo;

  @HiveField(3)
  final String material;

  @HiveField(4)
  final String? marca;

  @HiveField(5)
  final String? descricao;

  @HiveField(6)
  final String? terceiroNome;

  @HiveField(7)
  final DateTime? periodoInicio;

  @HiveField(8)
  final DateTime? periodoFim;

  @HiveField(9)
  final String? locadora;

  @HiveField(10)
  final String? centroCusto;

  @HiveField(11)
  final double? valor;

  @HiveField(12)
  final bool deleted;

  @HiveField(13)
  final bool pendingSync;

  @HiveField(14)
  final DateTime createdAt;

  @HiveField(15)
  final DateTime updatedAt;

  EquipamentoEstoqueRecord({
    required this.id,
    required this.projectId,
    required this.tipo,
    required this.material,
    this.marca,
    this.descricao,
    this.terceiroNome,
    this.periodoInicio,
    this.periodoFim,
    this.locadora,
    this.centroCusto,
    this.valor,
    this.deleted = false,
    this.pendingSync = false,
    required this.createdAt,
    required this.updatedAt,
  });

  EquipamentoEstoqueRecord copyWith({
    String? id,
    String? projectId,
    String? tipo,
    String? material,
    String? marca,
    String? descricao,
    String? terceiroNome,
    DateTime? periodoInicio,
    DateTime? periodoFim,
    String? locadora,
    String? centroCusto,
    double? valor,
    bool? deleted,
    bool? pendingSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipamentoEstoqueRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      tipo: tipo ?? this.tipo,
      material: material ?? this.material,
      marca: marca ?? this.marca,
      descricao: descricao ?? this.descricao,
      terceiroNome: terceiroNome ?? this.terceiroNome,
      periodoInicio: periodoInicio ?? this.periodoInicio,
      periodoFim: periodoFim ?? this.periodoFim,
      locadora: locadora ?? this.locadora,
      centroCusto: centroCusto ?? this.centroCusto,
      valor: valor ?? this.valor,
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

  static DateTime? _toDateOrNull(dynamic value) {
    if (value == null) return null;
    return _toDate(value);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'tipo': tipo,
      'material': material,
      'marca': marca,
      'descricao': descricao,
      'terceiroNome': terceiroNome,
      'periodoInicio': periodoInicio == null ? null : Timestamp.fromDate(periodoInicio!),
      'periodoFim': periodoFim == null ? null : Timestamp.fromDate(periodoFim!),
      'locadora': locadora,
      'centroCusto': centroCusto,
      'valor': valor,
      'deleted': deleted,
      'pendingSync': pendingSync,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EquipamentoEstoqueRecord.fromMap(Map<String, dynamic> map) {
    return EquipamentoEstoqueRecord(
      id: (map['id'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      tipo: (map['tipo'] ?? '').toString(),
      material: (map['material'] ?? '').toString(),
      marca: map['marca']?.toString(),
      descricao: map['descricao']?.toString(),
      terceiroNome: map['terceiroNome']?.toString(),
      periodoInicio: _toDateOrNull(map['periodoInicio']),
      periodoFim: _toDateOrNull(map['periodoFim']),
      locadora: map['locadora']?.toString(),
      centroCusto: map['centroCusto']?.toString(),
      valor: (map['valor'] as num?)?.toDouble(),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
