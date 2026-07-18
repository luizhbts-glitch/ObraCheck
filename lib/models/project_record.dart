import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'project_record.g.dart';

@HiveType(typeId: 6)
class ProjectRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String code;

  @HiveField(3)
  final bool isActive;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime updatedAt;

  /// Construtora dona da obra. Vazio em obras criadas antes da hierarquia
  /// de organizações — essas seguem funcionando sem vínculo até serem
  /// associadas pelo admin global.
  @HiveField(6, defaultValue: '')
  final String orgId;

  ProjectRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.orgId = '',
  });

  ProjectRecord copyWith({
    String? id,
    String? name,
    String? code,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? orgId,
  }) {
    return ProjectRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orgId: orgId ?? this.orgId,
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
      'name': name,
      'code': code,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'orgId': orgId,
    };
  }

  factory ProjectRecord.fromMap(Map<String, dynamic> map) {
    return ProjectRecord(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      code: (map['code'] ?? '').toString(),
      isActive: map['isActive'] == true,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
      orgId: (map['orgId'] ?? '').toString(),
    );
  }
}

