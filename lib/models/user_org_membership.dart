import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'user_org_membership.g.dart';

/// Vínculo usuário ↔ construtora (organização).
///
/// Diretores enxergam todas as obras da construtora; por padrão em modo
/// visualização, com elevação explícita para edição durante a sessão
/// (o toggle vive no contexto de sessão, não neste registro).
@HiveType(typeId: 14)
class UserOrgMembership extends HiveObject {
  static const String roleDiretor = 'diretor';

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String orgId;

  @HiveField(3)
  final String role;

  @HiveField(4)
  final bool isActive;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  UserOrgMembership({
    required this.id,
    required this.userId,
    required this.orgId,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  UserOrgMembership copyWith({
    String? id,
    String? userId,
    String? orgId,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserOrgMembership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orgId: orgId ?? this.orgId,
      role: role ?? this.role,
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
      'userId': userId,
      'orgId': orgId,
      'role': role,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserOrgMembership.fromMap(Map<String, dynamic> map) {
    return UserOrgMembership(
      id: (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      orgId: (map['orgId'] ?? '').toString(),
      role: (map['role'] ?? roleDiretor).toString(),
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  static bool isDiretor(String role) => role == roleDiretor;
}
