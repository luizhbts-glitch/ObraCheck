import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'inspection_record.dart';
import '../utils/project_identity.dart';
import '../utils/app_log.dart';

part 'diary_record.g.dart';

int _safeDiaryInt(
  dynamic value, {
  required String field,
  int fallback = 0,
}) {
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

@HiveType(typeId: 8)
class DiaryServiceEntry {
  static const String statusFvsOpening = 'abertura_fvs';
  static const String statusContinuation = 'continuacao';

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String companyId;

  @HiveField(2)
  final String companyName;

  @HiveField(3)
  final String localRef;

  @HiveField(4)
  final String localLabel;

  @HiveField(5)
  final int peopleCount;

  @HiveField(6)
  final String serviceStatus;

  @HiveField(7)
  final String note;

  @HiveField(8)
  final List<InspectionPhotoData> photos;

  @HiveField(9)
  final String fvsCodigo;

  @HiveField(10)
  final String fvsNome;

  @HiveField(11)
  final String tower;

  @HiveField(12)
  final int floor;

  @HiveField(13)
  final String apartment;

  @HiveField(14)
  final String locationType;

  @HiveField(15)
  final String locationContext;

  @HiveField(16)
  final String inspectionElement;

  DiaryServiceEntry({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.localRef,
    required this.localLabel,
    required this.peopleCount,
    required this.serviceStatus,
    required this.note,
    this.photos = const [],
    this.fvsCodigo = '',
    this.fvsNome = '',
    this.tower = '',
    this.floor = 0,
    this.apartment = '',
    this.locationType = '',
    this.locationContext = '',
    this.inspectionElement = '',
  });

  DiaryServiceEntry copyWith({
    String? id,
    String? companyId,
    String? companyName,
    String? localRef,
    String? localLabel,
    int? peopleCount,
    String? serviceStatus,
    String? note,
    List<InspectionPhotoData>? photos,
    String? fvsCodigo,
    String? fvsNome,
    String? tower,
    int? floor,
    String? apartment,
    String? locationType,
    String? locationContext,
    String? inspectionElement,
  }) {
    return DiaryServiceEntry(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      localRef: localRef ?? this.localRef,
      localLabel: localLabel ?? this.localLabel,
      peopleCount: peopleCount ?? this.peopleCount,
      serviceStatus: serviceStatus ?? this.serviceStatus,
      note: note ?? this.note,
      photos: photos ?? this.photos,
      fvsCodigo: fvsCodigo ?? this.fvsCodigo,
      fvsNome: fvsNome ?? this.fvsNome,
      tower: tower ?? this.tower,
      floor: floor ?? this.floor,
      apartment: apartment ?? this.apartment,
      locationType: locationType ?? this.locationType,
      locationContext: locationContext ?? this.locationContext,
      inspectionElement: inspectionElement ?? this.inspectionElement,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'companyName': companyName,
      'localRef': localRef,
      'localLabel': localLabel,
      'peopleCount': peopleCount,
      'serviceStatus': serviceStatus,
      'note': note,
      'photos': photos.map((e) => e.toMap()).toList(),
      'fvsCodigo': fvsCodigo,
      'fvsNome': fvsNome,
      'tower': tower,
      'floor': floor,
      'apartment': apartment,
      'locationType': locationType,
      'locationContext': locationContext,
      'inspectionElement': inspectionElement,
    };
  }

  factory DiaryServiceEntry.fromMap(Map<String, dynamic> map) {
    return DiaryServiceEntry(
      id: (map['id'] ?? '').toString(),
      companyId: (map['companyId'] ?? '').toString(),
      companyName: (map['companyName'] ?? '').toString(),
      localRef: (map['localRef'] ?? '').toString(),
      localLabel: (map['localLabel'] ?? '').toString(),
      peopleCount: _safeDiaryInt(
        map['peopleCount'],
        field: 'DiaryServiceEntry.peopleCount',
        fallback: 0,
      ),
      serviceStatus: (map['serviceStatus'] ?? statusContinuation).toString(),
      note: (map['note'] ?? '').toString(),
      photos: ((map['photos'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => InspectionPhotoData.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.photoUrl.trim().isNotEmpty || e.localPath.trim().isNotEmpty)
          .toList(),
      fvsCodigo: (map['fvsCodigo'] ?? '').toString(),
      fvsNome: (map['fvsNome'] ?? '').toString(),
      tower: (map['tower'] ?? '').toString(),
      floor: _safeDiaryInt(
        map['floor'],
        field: 'DiaryServiceEntry.floor',
        fallback: 0,
      ),
      apartment: (map['apartment'] ?? '').toString(),
      locationType: (map['locationType'] ?? '').toString(),
      locationContext: (map['locationContext'] ?? '').toString(),
      inspectionElement: (map['inspectionElement'] ?? '').toString(),
    );
  }
}

@HiveType(typeId: 9)
class DiaryOwnLaborEntry {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String role;

  @HiveField(2)
  final int peopleCount;

  @HiveField(3)
  final int orderIndex;

  DiaryOwnLaborEntry({
    required this.id,
    required this.role,
    required this.peopleCount,
    this.orderIndex = 0,
  });

  DiaryOwnLaborEntry copyWith({
    String? id,
    String? role,
    int? peopleCount,
    int? orderIndex,
  }) {
    return DiaryOwnLaborEntry(
      id: id ?? this.id,
      role: role ?? this.role,
      peopleCount: peopleCount ?? this.peopleCount,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'peopleCount': peopleCount,
      'orderIndex': orderIndex,
    };
  }

  factory DiaryOwnLaborEntry.fromMap(Map<String, dynamic> map) {
    return DiaryOwnLaborEntry(
      id: (map['id'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      peopleCount: _safeDiaryInt(
        map['peopleCount'],
        field: 'DiaryOwnLaborEntry.peopleCount',
        fallback: 0,
      ),
      orderIndex: _safeDiaryInt(
        map['orderIndex'],
        field: 'DiaryOwnLaborEntry.orderIndex',
        fallback: 0,
      ),
    );
  }
}

@HiveType(typeId: 10)
class DiaryRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String obra;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String climate;

  @HiveField(5)
  final String generalNotes;

  @HiveField(6)
  final List<DiaryServiceEntry> serviceEntries;

  @HiveField(7)
  final List<DiaryOwnLaborEntry> ownLaborEntries;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime updatedAt;

  @HiveField(10)
  final bool deleted;

  @HiveField(11)
  final bool pendingSync;

  @HiveField(12)
  final DateTime? deletedAt;

  @HiveField(13)
  final List<InspectionPhotoData> generalPhotos;

  @HiveField(14)
  final String climateMorning;

  @HiveField(15)
  final String climateAfternoon;

  @HiveField(16)
  final String rentedMachinery;

  @HiveField(17)
  final String rentedEquipment;

  @HiveField(18)
  final String createdByName;

  @HiveField(19)
  final String approvedByName;

  @HiveField(20)
  final String approvalStatus;

  DiaryRecord({
    required this.id,
    required this.projectId,
    required this.obra,
    required this.date,
    required this.climate,
    required this.generalNotes,
    required this.serviceEntries,
    required this.ownLaborEntries,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.pendingSync = false,
    this.deletedAt,
    this.generalPhotos = const [],
    this.climateMorning = '',
    this.climateAfternoon = '',
    this.rentedMachinery = '',
    this.rentedEquipment = '',
    this.createdByName = '',
    this.approvedByName = '',
    this.approvalStatus = '',
  });

  DiaryRecord copyWith({
    String? id,
    String? projectId,
    String? obra,
    DateTime? date,
    String? climate,
    String? generalNotes,
    List<DiaryServiceEntry>? serviceEntries,
    List<DiaryOwnLaborEntry>? ownLaborEntries,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    bool? pendingSync,
    DateTime? deletedAt,
    List<InspectionPhotoData>? generalPhotos,
    String? climateMorning,
    String? climateAfternoon,
    String? rentedMachinery,
    String? rentedEquipment,
    String? createdByName,
    String? approvedByName,
    String? approvalStatus,
  }) {
    return DiaryRecord(
      id: id ?? this.id,
      projectId: normalizeProjectId(projectId ?? this.projectId),
      obra: obra ?? this.obra,
      date: date ?? this.date,
      climate: climate ?? this.climate,
      generalNotes: generalNotes ?? this.generalNotes,
      serviceEntries: serviceEntries ?? this.serviceEntries,
      ownLaborEntries: ownLaborEntries ?? this.ownLaborEntries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      pendingSync: pendingSync ?? this.pendingSync,
      deletedAt: deletedAt ?? this.deletedAt,
      generalPhotos: generalPhotos ?? this.generalPhotos,
      climateMorning: climateMorning ?? this.climateMorning,
      climateAfternoon: climateAfternoon ?? this.climateAfternoon,
      rentedMachinery: rentedMachinery ?? this.rentedMachinery,
      rentedEquipment: rentedEquipment ?? this.rentedEquipment,
      createdByName: createdByName ?? this.createdByName,
      approvedByName: approvedByName ?? this.approvedByName,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': normalizeProjectId(projectId),
      'obra': obra,
      'date': Timestamp.fromDate(date),
      'climate': climate,
      'generalNotes': generalNotes,
      'serviceEntries': serviceEntries.map((e) => e.toMap()).toList(),
      'ownLaborEntries': ownLaborEntries.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deleted': deleted,
      'pendingSync': pendingSync,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      'generalPhotos': generalPhotos.map((e) => e.toMap()).toList(),
      'climateMorning': climateMorning,
      'climateAfternoon': climateAfternoon,
      'rentedMachinery': rentedMachinery,
      'rentedEquipment': rentedEquipment,
      'createdByName': createdByName,
      'approvedByName': approvedByName,
      'approvalStatus': approvalStatus,
    };
  }

  factory DiaryRecord.fromMap(Map<String, dynamic> map) {
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final rawServices = (map['serviceEntries'] as List?) ?? const [];
    final rawOwnLabor = (map['ownLaborEntries'] as List?) ?? const [];
    final rawGeneralPhotos = (map['generalPhotos'] as List?) ?? const [];

    return DiaryRecord(
      id: (map['id'] ?? '').toString(),
      projectId: inferProjectId(
        projectId: map['projectId']?.toString(),
        obra: map['obra']?.toString(),
      ),
      obra: (map['obra'] ?? '').toString(),
      date: toDate(map['date']),
      climate: (map['climate'] ?? '').toString(),
      generalNotes: (map['generalNotes'] ?? '').toString(),
      serviceEntries: rawServices
          .whereType<Map>()
          .map((e) => DiaryServiceEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      ownLaborEntries: rawOwnLabor
          .whereType<Map>()
          .map((e) => DiaryOwnLaborEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: toDate(map['createdAt']),
      updatedAt: toDate(map['updatedAt']),
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      deletedAt: map['deletedAt'] == null ? null : toDate(map['deletedAt']),
      generalPhotos: rawGeneralPhotos
          .whereType<Map>()
          .map((e) => InspectionPhotoData.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.photoUrl.trim().isNotEmpty || e.localPath.trim().isNotEmpty)
          .toList(),
      climateMorning: (map['climateMorning'] ?? '').toString(),
      climateAfternoon: (map['climateAfternoon'] ?? '').toString(),
      rentedMachinery: (map['rentedMachinery'] ?? '').toString(),
      rentedEquipment: (map['rentedEquipment'] ?? '').toString(),
      createdByName: (map['createdByName'] ?? '').toString(),
      approvedByName: (map['approvedByName'] ?? '').toString(),
      approvalStatus: (map['approvalStatus'] ?? '').toString(),
    );
  }
}

