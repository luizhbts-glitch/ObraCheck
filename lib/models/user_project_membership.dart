import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'user_project_membership.g.dart';

@HiveType(typeId: 7)
class UserProjectMembership extends HiveObject {
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleInspector = 'inspector';
  static const String roleViewer = 'viewer';

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String projectId;

  @HiveField(3)
  final String role;

  @HiveField(4)
  final bool isActive;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  UserProjectMembership({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProjectMembership copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProjectMembership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
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
      'projectId': projectId,
      'role': role,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserProjectMembership.fromMap(Map<String, dynamic> map) {
    return UserProjectMembership(
      id: (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      role: (map['role'] ?? roleViewer).toString(),
      isActive: map['isActive'] != false,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  static bool canManageProject(String role) {
    return role == roleAdmin || role == roleManager;
  }

  static bool canInspect(String role) {
    return role == roleAdmin || role == roleManager || role == roleInspector;
  }

  static bool canView(String role) {
    return role == roleAdmin ||
        role == roleManager ||
        role == roleInspector ||
        role == roleViewer;
  }
}

