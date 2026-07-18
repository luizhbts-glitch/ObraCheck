import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/project_identity.dart';

part 'company_record.g.dart';

@HiveType(typeId: 4)
class CompanyRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nome;

  @HiveField(2)
  final String especialidade;

  @HiveField(3)
  final String? cnpj;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime updatedAt;

  @HiveField(6)
  final bool deleted;

  @HiveField(7)
  final bool pendingSync;

  @HiveField(8)
  final DateTime? deletedAt;

  @HiveField(9)
  final String projectId;

  @HiveField(10)
  final String? phone;

  CompanyRecord({
    required this.id,
    required this.nome,
    required this.especialidade,
    this.cnpj,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.pendingSync = false,
    this.deletedAt,
    this.projectId = kLegacyProjectId,
    this.phone,
  });

  CompanyRecord copyWith({
    String? id,
    String? nome,
    String? especialidade,
    String? cnpj,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    bool? pendingSync,
    DateTime? deletedAt,
    String? projectId,
    String? phone,
  }) {
    return CompanyRecord(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      especialidade: especialidade ?? this.especialidade,
      cnpj: cnpj ?? this.cnpj,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      pendingSync: pendingSync ?? this.pendingSync,
      deletedAt: deletedAt ?? this.deletedAt,
      projectId: normalizeProjectId(projectId ?? this.projectId),
      phone: phone ?? this.phone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'especialidade': especialidade,
      'cnpj': cnpj,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deleted': deleted,
      'pendingSync': pendingSync,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      'projectId': normalizeProjectId(projectId),
      'phone': phone,
    };
  }

  factory CompanyRecord.fromMap(Map<String, dynamic> map) {
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return CompanyRecord(
      id: (map['id'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      especialidade: (map['especialidade'] ?? '').toString(),
      cnpj: map['cnpj']?.toString(),
      createdAt: toDate(map['createdAt']),
      updatedAt: toDate(map['updatedAt']),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      deletedAt: map['deletedAt'] == null ? null : toDate(map['deletedAt']),
      projectId: inferProjectId(
        projectId: map['projectId']?.toString(),
        obra: map['obra']?.toString(),
      ),
      phone: map['phone']?.toString() ?? map['whatsappPhone']?.toString(),
    );
  }
}

