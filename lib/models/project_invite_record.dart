import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'project_invite_record.g.dart';

@HiveType(typeId: 8)
class ProjectInviteRecord extends HiveObject {
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusCanceled = 'canceled';

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String emailLower;

  @HiveField(4)
  final String role;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final String invitedByUid;

  @HiveField(7)
  final String? invitedByName;

  @HiveField(8)
  final DateTime invitedAt;

  @HiveField(9)
  final DateTime updatedAt;

  @HiveField(10)
  final String? acceptedByUid;

  @HiveField(11)
  final DateTime? acceptedAt;

  @HiveField(12)
  final bool pendingSync;

  @HiveField(13)
  final String? syncError;

  ProjectInviteRecord({
    required this.id,
    required this.projectId,
    required this.email,
    required this.emailLower,
    required this.role,
    required this.status,
    required this.invitedByUid,
    required this.invitedAt,
    required this.updatedAt,
    this.invitedByName,
    this.acceptedByUid,
    this.acceptedAt,
    this.pendingSync = false,
    this.syncError,
  });

  ProjectInviteRecord copyWith({
    String? id,
    String? projectId,
    String? email,
    String? emailLower,
    String? role,
    String? status,
    String? invitedByUid,
    String? invitedByName,
    DateTime? invitedAt,
    DateTime? updatedAt,
    String? acceptedByUid,
    DateTime? acceptedAt,
    bool? pendingSync,
    String? syncError,
  }) {
    return ProjectInviteRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      email: email ?? this.email,
      emailLower: emailLower ?? this.emailLower,
      role: role ?? this.role,
      status: status ?? this.status,
      invitedByUid: invitedByUid ?? this.invitedByUid,
      invitedByName: invitedByName ?? this.invitedByName,
      invitedAt: invitedAt ?? this.invitedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedByUid: acceptedByUid ?? this.acceptedByUid,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      syncError: syncError,
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
      'email': email,
      'emailLower': emailLower,
      'role': role,
      'status': status,
      'invitedByUid': invitedByUid,
      'invitedByName': invitedByName,
      'invitedAt': Timestamp.fromDate(invitedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'acceptedByUid': acceptedByUid,
      'acceptedAt': acceptedAt == null ? null : Timestamp.fromDate(acceptedAt!),
      'pendingSync': pendingSync,
      'syncError': syncError,
    };
  }

  factory ProjectInviteRecord.fromMap(Map<String, dynamic> map) {
    return ProjectInviteRecord(
      id: (map['id'] ?? '').toString(),
      projectId: (map['projectId'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      emailLower: (map['emailLower'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      status: (map['status'] ?? statusPending).toString(),
      invitedByUid: (map['invitedByUid'] ?? '').toString(),
      invitedByName: map['invitedByName']?.toString(),
      invitedAt: _toDate(map['invitedAt']),
      updatedAt: _toDate(map['updatedAt']),
      acceptedByUid: map['acceptedByUid']?.toString(),
      acceptedAt: map['acceptedAt'] == null ? null : _toDate(map['acceptedAt']),
      pendingSync: map['pendingSync'] == true,
      syncError: map['syncError']?.toString(),
    );
  }
}

