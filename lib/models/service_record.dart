import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/project_identity.dart';
import '../utils/app_log.dart';

part 'service_record.g.dart';

@HiveType(typeId: 3)
class ServiceRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String obra;

  @HiveField(2)
  final String torre;

  @HiveField(3)
  final int andar;

  @HiveField(4)
  final String localRef;

  @HiveField(5)
  final String localLabel;

  @HiveField(6)
  final String empresaId;

  @HiveField(7)
  final String empresaNome;

  @HiveField(8)
  final String servicoCodigo;

  @HiveField(9)
  final String servicoNome;

  @HiveField(10)
  final String status; // em_aberto | aguardando_inspecao

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final DateTime updatedAt;

  @HiveField(13)
  final bool deleted;

  @HiveField(14)
  final bool pendingSync;

  @HiveField(15)
  final DateTime? deletedAt;

  @HiveField(16)
  final String projectId;

  ServiceRecord({
    required this.id,
    required this.obra,
    required this.torre,
    required this.andar,
    required this.localRef,
    required this.localLabel,
    required this.empresaId,
    required this.empresaNome,
    required this.servicoCodigo,
    required this.servicoNome,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.pendingSync = false,
    this.deletedAt,
    this.projectId = kLegacyProjectId,
  });

  ServiceRecord copyWith({
    String? id,
    String? obra,
    String? torre,
    int? andar,
    String? localRef,
    String? localLabel,
    String? empresaId,
    String? empresaNome,
    String? servicoCodigo,
    String? servicoNome,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    bool? pendingSync,
    DateTime? deletedAt,
    String? projectId,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      obra: obra ?? this.obra,
      torre: torre ?? this.torre,
      andar: andar ?? this.andar,
      localRef: localRef ?? this.localRef,
      localLabel: localLabel ?? this.localLabel,
      empresaId: empresaId ?? this.empresaId,
      empresaNome: empresaNome ?? this.empresaNome,
      servicoCodigo: servicoCodigo ?? this.servicoCodigo,
      servicoNome: servicoNome ?? this.servicoNome,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      pendingSync: pendingSync ?? this.pendingSync,
      deletedAt: deletedAt ?? this.deletedAt,
      projectId: normalizeProjectId(projectId ?? this.projectId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'obra': obra,
      'torre': torre,
      'andar': andar,
      'localRef': localRef,
      'localLabel': localLabel,
      'empresaId': empresaId,
      'empresaNome': empresaNome,
      'servicoCodigo': servicoCodigo,
      'servicoNome': servicoNome,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deleted': deleted,
      'pendingSync': pendingSync,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      'projectId': normalizeProjectId(projectId),
    };
  }

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

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

    return ServiceRecord(
      id: (map['id'] ?? '').toString(),
      obra: (map['obra'] ?? '').toString(),
      torre: (map['torre'] ?? '').toString(),
      andar: toInt(map['andar'], field: 'ServiceRecord.andar', fallback: 0),
      localRef: (map['localRef'] ?? '').toString(),
      localLabel: (map['localLabel'] ?? '').toString(),
      empresaId: (map['empresaId'] ?? '').toString(),
      empresaNome: (map['empresaNome'] ?? '').toString(),
      servicoCodigo: (map['servicoCodigo'] ?? '').toString(),
      servicoNome: (map['servicoNome'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      createdAt: toDate(map['createdAt']),
      updatedAt: toDate(map['updatedAt']),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      deletedAt: map['deletedAt'] == null ? null : toDate(map['deletedAt']),
      projectId: inferProjectId(
        projectId: map['projectId']?.toString(),
        obra: map['obra']?.toString(),
      ),
    );
  }
}

