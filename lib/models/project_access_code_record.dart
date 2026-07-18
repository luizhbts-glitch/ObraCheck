import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../utils/app_log.dart';

part 'project_access_code_record.g.dart';

@HiveType(typeId: 11)
class ProjectAccessCodeRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String code;

  @HiveField(3)
  final String role;

  @HiveField(4)
  final DateTime? expiresAt;

  @HiveField(5)
  final int maxUses;

  @HiveField(6)
  final int usedCount;

  @HiveField(7)
  final bool isActive;

  @HiveField(14)
  final bool isMaster;

  @HiveField(8)
  final String createdByUid;

  @HiveField(9)
  final String? createdByName;

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final DateTime updatedAt;

  @HiveField(12)
  final bool pendingSync;

  @HiveField(13)
  final String? syncError;

  ProjectAccessCodeRecord({
    required this.id,
    required this.projectId,
    required this.code,
    required this.role,
    required this.expiresAt,
    required this.maxUses,
    required this.usedCount,
    required this.isActive,
    this.isMaster = false,
    required this.createdByUid,
    required this.createdAt,
    required this.updatedAt,
    this.createdByName,
    this.pendingSync = false,
    this.syncError,
  });

  ProjectAccessCodeRecord copyWith({
    String? id,
    String? projectId,
    String? code,
    String? role,
    DateTime? expiresAt,
    int? maxUses,
    int? usedCount,
    bool? isActive,
    bool? isMaster,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pendingSync,
    String? syncError,
  }) {
    return ProjectAccessCodeRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      code: code ?? this.code,
      role: role ?? this.role,
      expiresAt: expiresAt ?? this.expiresAt,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
      isActive: isActive ?? this.isActive,
      isMaster: isMaster ?? this.isMaster,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      syncError: syncError,
    );
  }

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  bool get active => isActive;
  int get remainingUses {
    final remaining = maxUses - usedCount;
    return remaining < 0 ? 0 : remaining;
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
      'code': code,
      'role': role,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
      'maxUses': maxUses,
      'usedCount': usedCount,
      'isActive': isActive,
      'active': isActive,
      'isMaster': isMaster,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'pendingSync': pendingSync,
      'syncError': syncError,
    };
  }

  factory ProjectAccessCodeRecord.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic value, {required String field, int fallback = 0}) {
      if (value == null) {
        if (AppLog.enableSyncLogs) {
          debugPrint('[SYNC][NULL_INT_FIX] campo=$field valor=null fallback=$fallback');
        }
        return fallback;
      }
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
      if (AppLog.enableSyncLogs) {
        debugPrint('[SYNC][NULL_INT_FIX] campo=$field valor_invalido="$value" fallback=$fallback');
      }
      return fallback;
    }

    return ProjectAccessCodeRecord(
      id: (map['id'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      code: (map['code'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      expiresAt: map['expiresAt'] == null ? null : _toDate(map['expiresAt']),
      maxUses: toInt(map['maxUses'], field: 'ProjectAccessCodeRecord.maxUses', fallback: 1),
      usedCount: toInt(map['usedCount'], field: 'ProjectAccessCodeRecord.usedCount', fallback: 0),
      isActive: (map['active'] ?? map['isActive']) != false,
      isMaster: map['isMaster'] == true,
      createdByUid: (map['createdByUid'] ?? '').toString(),
      createdByName: map['createdByName']?.toString(),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
      pendingSync: map['pendingSync'] == true,
      syncError: map['syncError']?.toString(),
    );
  }
}

