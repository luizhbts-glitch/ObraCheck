import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'construtora_record.g.dart';

/// Construtora (organização) dona de um conjunto de obras.
///
/// Nível intermediário da hierarquia de acesso:
/// admin global > diretoria da construtora > engenheiro da obra > administrativo.
/// Cadastro é feito apenas pelo admin global.
@HiveType(typeId: 13)
class ConstrutoraRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final bool isActive;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  ConstrutoraRecord({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  ConstrutoraRecord copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConstrutoraRecord(
      id: id ?? this.id,
      name: name ?? this.name,
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
      'name': name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ConstrutoraRecord.fromMap(Map<String, dynamic> map) {
    return ConstrutoraRecord(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }
}
