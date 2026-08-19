import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'fornecedor_record.g.dart';

/// Fornecedor de material — cadastro próprio de Compras, independente de
/// `CompanyRecord` (Empreiteiros). São coisas diferentes de propósito
/// (decidido em 2026-07-18): empreiteiro presta serviço, fornecedor vende
/// material. Escopo por construtora, não por obra — um fornecedor de
/// material tipicamente atende várias obras da mesma construtora.
@HiveType(typeId: 20)
class FornecedorRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String orgId;

  @HiveField(2)
  final String nome;

  @HiveField(3)
  final String? cnpj;

  @HiveField(4)
  final String categoria;

  @HiveField(5)
  final String? telefone;

  @HiveField(6)
  final bool isActive;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  FornecedorRecord({
    required this.id,
    required this.orgId,
    required this.nome,
    this.cnpj,
    this.categoria = '',
    this.telefone,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  FornecedorRecord copyWith({
    String? id,
    String? orgId,
    String? nome,
    String? cnpj,
    String? categoria,
    String? telefone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FornecedorRecord(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      nome: nome ?? this.nome,
      cnpj: cnpj ?? this.cnpj,
      categoria: categoria ?? this.categoria,
      telefone: telefone ?? this.telefone,
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
      'cnpj': cnpj,
      'categoria': categoria,
      'telefone': telefone,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory FornecedorRecord.fromMap(Map<String, dynamic> map) {
    return FornecedorRecord(
      id: (map['id'] ?? '').toString(),
      orgId: (map['orgId'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      cnpj: map['cnpj']?.toString(),
      categoria: (map['categoria'] ?? '').toString(),
      telefone: map['telefone']?.toString(),
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
