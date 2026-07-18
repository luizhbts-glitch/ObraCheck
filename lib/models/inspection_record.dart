import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/fvs_data.dart';
import 'inspection_status.dart';
import '../utils/project_identity.dart';
import '../utils/app_log.dart';

part 'inspection_record.g.dart';

@HiveType(typeId: 1)
class InspectionRecord extends HiveObject {
  /// Dominio de status da inspeção.
  /// Mantemos `finalized` por compatibilidade com dados legados.
  static const String statusDraft = 'draft';
  static const String statusFinal = 'final';
  static const String statusFinalizedLegacy = 'finalized';

  @HiveField(0)
  final String obra; // "Arsen SabiÃ¡" (fixo no V1)

  @HiveField(1)
  final String torre;

  @HiveField(2)
  final int andar;

  @HiveField(3)
  final String apto;

  @HiveField(4)
  final String fvsCodigo;

  @HiveField(5)
  final String fvsNome;

  /// lista de itens (cada item tem status + obs)
  @HiveField(6)
  final List<InspectionItemResult> itens;

  @HiveField(7)
  final DateTime createdAt;

  // âœ… NOVOS CAMPOS (adicionei NO FINAL pra nÃ£o quebrar Ã­ndices antigos)
  @HiveField(8)
  final String id; // chave estável (evita duplicidade local/cloud)

  @HiveField(9)
  final DateTime updatedAt; // carimbo de última alteração local/remota

  /// Estado de ciclo de vida da inspeção.
  /// Valores válidos no projeto: draft | final | finalized(legado)
  @HiveField(10)
  final String status;

  @HiveField(11)
  final DateTime? finalizedAt; // data efetiva de finalização

  @HiveField(12)
  final String? localRef;

  @HiveField(13)
  final bool? locked; // lock explícito (compatibilidade com versões antigas)

  @HiveField(14)
  final DateTime? lockedAt;

  @HiveField(15)
  final String? actionType;

  @HiveField(16)
  final String? actionByUid;

  @HiveField(17)
  final String? actionByName;

  @HiveField(18)
  final String? actionByCargo;

  @HiveField(19)
  final DateTime? actionAt; // timestamp da ação registrada em actionType

  @HiveField(20)
  final bool deleted; // tombstone lógico para sincronização

  @HiveField(21)
  final bool pendingSync; // true => precisa enviar para cloud

  @HiveField(22)
  final DateTime? deletedAt;

  @HiveField(23)
  final String? ncCompanyId;

  @HiveField(24)
  final String? ncCompanyName;

  /// Complemento opcional para diferenciar inspeções no mesmo local/FVS.
  /// Exemplos: Pilar, Viga, Laje.
  @HiveField(25)
  final String? inspectionElement;

  /// Identificador lógico da obra/projeto para isolamento multi-obra.
  /// Mantém fallback legado para registros antigos sem campo.
  @HiveField(26)
  final String projectId;

  @HiveField(27)
  final String? operationalSheetId;

  @HiveField(28)
  final String? operationalSheetLabel;

  InspectionRecord({
    required this.obra,
    required this.torre,
    required this.andar,
    required this.apto,
    required this.fvsCodigo,
    required this.fvsNome,
    required this.itens,
    required this.createdAt,
    required this.id,
    required this.updatedAt,
    required this.status,
    this.finalizedAt,
    this.localRef,
    this.locked,
    this.lockedAt,
    this.actionType,
    this.actionByUid,
    this.actionByName,
    this.actionByCargo,
    this.actionAt,
    this.deleted = false,
    this.pendingSync = false,
    this.deletedAt,
    this.ncCompanyId,
    this.ncCompanyName,
    this.inspectionElement,
    this.projectId = kLegacyProjectId,
    this.operationalSheetId,
    this.operationalSheetLabel,
  });

  InspectionRecord copyWith({
    String? obra,
    String? torre,
    int? andar,
    String? apto,
    String? fvsCodigo,
    String? fvsNome,
    List<InspectionItemResult>? itens,
    DateTime? createdAt,
    String? id,
    DateTime? updatedAt,
    String? status,
    DateTime? finalizedAt,
    String? localRef,
    bool? locked,
    DateTime? lockedAt,
    String? actionType,
    String? actionByUid,
    String? actionByName,
    String? actionByCargo,
    DateTime? actionAt,
    bool? deleted,
    bool? pendingSync,
    DateTime? deletedAt,
    String? ncCompanyId,
    String? ncCompanyName,
    String? inspectionElement,
    String? projectId,
    String? operationalSheetId,
    String? operationalSheetLabel,
  }) {
    return InspectionRecord(
      obra: obra ?? this.obra,
      torre: torre ?? this.torre,
      andar: andar ?? this.andar,
      apto: apto ?? this.apto,
      fvsCodigo: fvsCodigo ?? this.fvsCodigo,
      fvsNome: fvsNome ?? this.fvsNome,
      itens: itens ?? this.itens,
      createdAt: createdAt ?? this.createdAt,
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      localRef: localRef ?? this.localRef,
      locked: locked ?? this.locked,
      lockedAt: lockedAt ?? this.lockedAt,
      actionType: actionType ?? this.actionType,
      actionByUid: actionByUid ?? this.actionByUid,
      actionByName: actionByName ?? this.actionByName,
      actionByCargo: actionByCargo ?? this.actionByCargo,
      actionAt: actionAt ?? this.actionAt,
      deleted: deleted ?? this.deleted,
      pendingSync: pendingSync ?? this.pendingSync,
      deletedAt: deletedAt ?? this.deletedAt,
      ncCompanyId: ncCompanyId ?? this.ncCompanyId,
      ncCompanyName: ncCompanyName ?? this.ncCompanyName,
      inspectionElement: inspectionElement ?? this.inspectionElement,
      projectId: normalizeProjectId(projectId ?? this.projectId),
      operationalSheetId: operationalSheetId ?? this.operationalSheetId,
      operationalSheetLabel: operationalSheetLabel ?? this.operationalSheetLabel,
    );
  }

  static String normalizeInspectionElement(String? raw) {
    final value = raw?.trim() ?? '';
    return value;
  }

  static String inspectionElementKey(String? raw) {
    final normalized = normalizeInspectionElement(raw);
    if (normalized.isEmpty) return 'SEM_ELEMENTO';
    return normalized.toUpperCase().replaceAll(RegExp(r'\s+'), '_');
  }

  String get normalizedInspectionElement => normalizeInspectionElement(inspectionElement);

  bool get hasInspectionElement => normalizedInspectionElement.isNotEmpty;

  String get inspectionElementLabel => hasInspectionElement ? normalizedInspectionElement : 'Sem elemento';

  static String normalizeStatus(String rawStatus) {
    return inspectionStatusToStorage(inspectionStatusFromStorage(rawStatus));
  }

  static bool isDraftStatus(String rawStatus) {
    return inspectionStatusFromStorage(rawStatus) == InspectionRecordStatus.draft;
  }

  static bool isFinalStatus(String rawStatus) {
    return inspectionStatusFromStorage(rawStatus) == InspectionRecordStatus.finalStatus;
  }

  static bool expectedLockedForStatus(String rawStatus) {
    return isFinalStatus(rawStatus);
  }

  InspectionRecordStatus get statusEnum => inspectionStatusFromStorage(status);

  static bool matchesListingStatus({
    required String rawStatus,
    required bool includeDrafts,
  }) {
    if (includeDrafts) {
      return isDraftStatus(rawStatus) || isFinalStatus(rawStatus);
    }
    return isFinalStatus(rawStatus);
  }

  static String actionTypeFromStatus(String rawStatus) {
    return isFinalStatus(rawStatus) ? 'finalizou' : 'rascunho';
  }

  static String canonicalActionType(String rawStatus) {
    return actionTypeFromStatus(normalizeStatus(rawStatus));
  }

  bool get isDraft => statusEnum == InspectionRecordStatus.draft;
  bool get isFinalized => statusEnum == InspectionRecordStatus.finalStatus;
  bool get isFinalState => statusEnum == InspectionRecordStatus.finalStatus;
  bool get isLockedState => (locked == true) || isFinalState;
  bool get hasOpenNc => itens.any((item) => item.status == 'nok');

  /// Status normalizado para evitar divergência entre `final` e `finalized`.
  String get canonicalStatus {
    return inspectionStatusToStorage(statusEnum);
  }

  /// Data de negócio da inspeção:
  /// - finalizada: finalizedAt > actionAt > updatedAt
  /// - rascunho: createdAt
  DateTime get businessDate {
    if (isFinalState) return finalizedAt ?? actionAt ?? updatedAt;
    return createdAt;
  }

  static String _normalizeLogicalToken(String? raw) {
    return (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _dayKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String resolveLocationForLogicalKey({
    required String apto,
    required String? localRef,
  }) {
    final ref = (localRef ?? '').trim();
    final local = ref.isNotEmpty ? ref : apto;
    return _normalizeLogicalToken(local);
  }

  static String inspectionLogicalKey({
    required String projectId,
    required String torre,
    required String apto,
    required String? localRef,
    required String fvsCodigo,
    String? operationalSheetId,
    required DateTime businessDate,
  }) {
    return '${_normalizeLogicalToken(projectId)}|'
        '${_normalizeLogicalToken(torre)}|'
        '${resolveLocationForLogicalKey(apto: apto, localRef: localRef)}|'
        '${_normalizeLogicalToken(fvsCodigo)}|'
        '${_normalizeLogicalToken(operationalSheetId)}|'
        '${_dayKey(businessDate)}';
  }

  String logicalBusinessKey({DateTime? businessDateOverride}) {
    return inspectionLogicalKey(
      projectId: projectId,
      torre: torre,
      apto: apto,
      localRef: localRef,
      fvsCodigo: fvsCodigo,
      operationalSheetId: operationalSheetId,
      businessDate: businessDateOverride ?? businessDate,
    );
  }

  bool get hasPendingPhotoSync => itens.any((item) => item.photos.any((photo) => photo.pendingSync));

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  static int _asInt(
    dynamic raw, {
    required String field,
    int defaultValue = 0,
  }) {
    if (raw == null) {
      if (AppLog.enableSyncLogs) {
        debugPrint('[SYNC][NULL_INT_FIX] campo=$field valor=null fallback=$defaultValue');
      }
      return defaultValue;
    }
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse(raw.toString());
    if (parsed != null) return parsed;
    if (AppLog.enableSyncLogs) {
      debugPrint(
        '[SYNC][NULL_INT_FIX] campo=$field valor_invalido="${raw.toString()}" fallback=$defaultValue',
      );
    }
    return defaultValue;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'obra': obra,
      'torre': torre,
      'andar': andar,
      'apto': apto,
      'fvsCodigo': fvsCodigo,
      'fvsNome': fvsNome,
      'itens': itens.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status,
      'finalizedAt': finalizedAt == null ? null : Timestamp.fromDate(finalizedAt!),
      'localRef': localRef,
      'locked': locked,
      'lockedAt': lockedAt == null ? null : Timestamp.fromDate(lockedAt!),
      'actionType': actionType,
      'actionByUid': actionByUid,
      'actionByName': actionByName,
      'actionByCargo': actionByCargo,
      'actionAt': actionAt == null ? null : Timestamp.fromDate(actionAt!),
      'deleted': deleted,
      'pendingSync': pendingSync,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      'ncCompanyId': ncCompanyId,
      'ncCompanyName': ncCompanyName,
      'inspectionElement': normalizeInspectionElement(inspectionElement),
      'projectId': normalizeProjectId(projectId),
      'operationalSheetId': operationalSheetId,
      'operationalSheetLabel': operationalSheetLabel,
    };
  }

  factory InspectionRecord.fromMap(Map<String, dynamic> map) {
    final statusRaw = (map['status'] ?? 'draft').toString();
    final normalizedStatus = normalizeStatus(statusRaw);
    final createdAt = _toDate(map['createdAt']);
    final updatedAt = _toDate(map['updatedAt']);
    final finalizedAtRaw =
        map['finalizedAt'] == null ? null : _toDate(map['finalizedAt']);
    final lockedAt = map['lockedAt'] == null ? null : _toDate(map['lockedAt']);
    final actionAt = map['actionAt'] == null ? null : _toDate(map['actionAt']);
    final resolvedFinalizedAt = isFinalStatus(normalizedStatus)
        ? (finalizedAtRaw ?? actionAt ?? lockedAt)
        : null;

    return InspectionRecord(
      id: (map['id'] ?? '').toString(),
      obra: (map['obra'] ?? '').toString(),
      torre: (map['torre'] ?? '').toString(),
      andar: _asInt(map['andar'], field: 'InspectionRecord.andar', defaultValue: 0),
      apto: (map['apto'] ?? '').toString(),
      fvsCodigo: (map['fvsCodigo'] ?? '').toString(),
      fvsNome: (map['fvsNome'] ?? '').toString(),
      itens: ((map['itens'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => InspectionItemResult.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: normalizedStatus,
      finalizedAt: resolvedFinalizedAt,
      localRef: map['localRef']?.toString(),
      locked: map['locked'] as bool?,
      lockedAt: lockedAt,
      actionType: map['actionType']?.toString(),
      actionByUid: map['actionByUid']?.toString(),
      actionByName: map['actionByName']?.toString(),
      actionByCargo: map['actionByCargo']?.toString(),
      actionAt: actionAt,
      deleted: map['deleted'] == true,
      pendingSync: map['pendingSync'] == true,
      deletedAt: map['deletedAt'] == null ? null : _toDate(map['deletedAt']),
      ncCompanyId: map['ncCompanyId']?.toString(),
      ncCompanyName: map['ncCompanyName']?.toString(),
      inspectionElement: normalizeInspectionElement(map['inspectionElement']?.toString()),
      projectId: inferProjectId(
        projectId: map['projectId']?.toString(),
        obra: map['obra']?.toString(),
      ),
      operationalSheetId: map['operationalSheetId']?.toString(),
      operationalSheetLabel: map['operationalSheetLabel']?.toString(),
    );
  }
}

@HiveType(typeId: 2)
class InspectionItemResult {
  static const String proofVisual = FvsProofType.visual;
  static const String proofPhotoRequired = FvsProofType.photoRequired;
  static const String proofMeasurement = FvsProofType.measurement;
  static const String proofTechnicalNote = FvsProofType.technicalNote;
  static const String proofSampledLocation = FvsProofType.sampledLocation;

  static String normalizeProofType(String? raw) {
    switch ((raw ?? '').trim()) {
      case proofPhotoRequired:
      case proofMeasurement:
      case proofTechnicalNote:
      case proofSampledLocation:
      case proofVisual:
        return (raw ?? proofVisual).trim();
      default:
        return proofVisual;
    }
  }

  @HiveField(0)
  final int index;

  @HiveField(1)
  final String descricao;

  @HiveField(2)
  final String dica;

  /// "none" | "ok" | "nok" | "okAfterFix"
  @HiveField(3)
  final String status;

  @HiveField(4)
  final String obs;

  @HiveField(5)
  final List<String> photoPaths;

  @HiveField(6)
  final List<InspectionPhotoData> photos;

  @HiveField(7)
  final String? ncCompanyId;

  @HiveField(8)
  final String? ncCompanyName;

  @HiveField(9)
  final String proofType;

  @HiveField(10)
  final bool requiresPhoto;

  @HiveField(11)
  final double? measuredValue;

  @HiveField(12)
  final String? measuredUnit;

  @HiveField(13)
  final String? technicalNote;

  @HiveField(14)
  final List<String> sampledLocations;

  @HiveField(15)
  final double? measurementToleranceMin;

  @HiveField(16)
  final double? measurementToleranceMax;

  @HiveField(17)
  final bool requiresTechnicalNote;

  @HiveField(18)
  final bool supportsSampling;

  InspectionItemResult({
    required this.index,
    required this.descricao,
    required this.dica,
    required this.status,
    required this.obs,
    this.photoPaths = const [],
    this.photos = const [],
    this.ncCompanyId,
    this.ncCompanyName,
    this.proofType = proofVisual,
    this.requiresPhoto = false,
    this.measuredValue,
    this.measuredUnit,
    this.technicalNote,
    this.sampledLocations = const [],
    this.measurementToleranceMin,
    this.measurementToleranceMax,
    this.requiresTechnicalNote = false,
    this.supportsSampling = false,
  });

  InspectionItemResult copyWith({
    int? index,
    String? descricao,
    String? dica,
    String? status,
    String? obs,
    List<String>? photoPaths,
    List<InspectionPhotoData>? photos,
    String? ncCompanyId,
    String? ncCompanyName,
    String? proofType,
    bool? requiresPhoto,
    double? measuredValue,
    String? measuredUnit,
    String? technicalNote,
    List<String>? sampledLocations,
    double? measurementToleranceMin,
    double? measurementToleranceMax,
    bool? requiresTechnicalNote,
    bool? supportsSampling,
  }) {
    return InspectionItemResult(
      index: index ?? this.index,
      descricao: descricao ?? this.descricao,
      dica: dica ?? this.dica,
      status: status ?? this.status,
      obs: obs ?? this.obs,
      photoPaths: photoPaths ?? this.photoPaths,
      photos: photos ?? this.photos,
      ncCompanyId: ncCompanyId ?? this.ncCompanyId,
      ncCompanyName: ncCompanyName ?? this.ncCompanyName,
      proofType: normalizeProofType(proofType ?? this.proofType),
      requiresPhoto: requiresPhoto ?? this.requiresPhoto,
      measuredValue: measuredValue ?? this.measuredValue,
      measuredUnit: measuredUnit ?? this.measuredUnit,
      technicalNote: technicalNote ?? this.technicalNote,
      sampledLocations: sampledLocations ?? this.sampledLocations,
      measurementToleranceMin: measurementToleranceMin ?? this.measurementToleranceMin,
      measurementToleranceMax: measurementToleranceMax ?? this.measurementToleranceMax,
      requiresTechnicalNote: requiresTechnicalNote ?? this.requiresTechnicalNote,
      supportsSampling: supportsSampling ?? this.supportsSampling,
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedPhotoPaths = photos
        .map((e) => e.photoUrl.trim().isNotEmpty ? e.photoUrl : e.localPath)
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final normalizedPhotoUrls = photos
        .map((e) => e.photoUrl)
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return {
      'index': index,
      'descricao': descricao,
      'dica': dica,
      'status': status,
      'obs': obs,
      'photoPaths': normalizedPhotoPaths,
      'photoUrls': normalizedPhotoUrls,
      'photos': photos.map((e) => e.toMap()).toList(),
      'ncCompanyId': ncCompanyId,
      'ncCompanyName': ncCompanyName,
      'proofType': normalizeProofType(proofType),
      'requiresPhoto': requiresPhoto,
      'measuredValue': measuredValue,
      'measuredUnit': measuredUnit,
      'technicalNote': technicalNote,
      'sampledLocations': sampledLocations,
      'measurementToleranceMin': measurementToleranceMin,
      'measurementToleranceMax': measurementToleranceMax,
      'requiresTechnicalNote': requiresTechnicalNote,
      'supportsSampling': supportsSampling,
    };
  }

  static double? _asDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    return double.tryParse(raw.toString().replaceAll(',', '.'));
  }

  factory InspectionItemResult.fromMap(Map<String, dynamic> map) {
    return InspectionItemResult(
      index: InspectionRecord._asInt(
        map['index'],
        field: 'InspectionItemResult.index',
        defaultValue: 0,
      ),
      descricao: (map['descricao'] ?? '').toString(),
      dica: (map['dica'] ?? '').toString(),
      status: (map['status'] ?? 'none').toString(),
      obs: (map['obs'] ?? '').toString(),
      photoPaths: ((map['photoPaths'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      photos: _extractPhotos(map),
      ncCompanyId: map['ncCompanyId']?.toString(),
      ncCompanyName: map['ncCompanyName']?.toString(),
      proofType: normalizeProofType(map['proofType']?.toString()),
      requiresPhoto: map['requiresPhoto'] == true,
      measuredValue: _asDouble(map['measuredValue']),
      measuredUnit: map['measuredUnit']?.toString(),
      technicalNote: map['technicalNote']?.toString(),
      sampledLocations: ((map['sampledLocations'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      measurementToleranceMin: _asDouble(map['measurementToleranceMin']),
      measurementToleranceMax: _asDouble(map['measurementToleranceMax']),
      requiresTechnicalNote: map['requiresTechnicalNote'] == true,
      supportsSampling: map['supportsSampling'] == true,
    );
  }

  static List<InspectionPhotoData> _extractPhotos(Map<String, dynamic> map) {
    final explicitPhotos = ((map['photos'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => InspectionPhotoData.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.photoUrl.trim().isNotEmpty || e.localPath.trim().isNotEmpty)
        .toList();
    if (explicitPhotos.isNotEmpty) return explicitPhotos;

    final photoPaths = ((map['photoPaths'] as List?) ?? const []).map((e) => e.toString()).toList();
    final photoUrls = ((map['photoUrls'] as List?) ?? const []).map((e) => e.toString()).toList();

    final pairs = <InspectionPhotoData>[];
    final maxLength = photoUrls.length > photoPaths.length ? photoUrls.length : photoPaths.length;
    for (var i = 0; i < maxLength; i++) {
      final url = i < photoUrls.length ? photoUrls[i] : '';
      final path = i < photoPaths.length ? photoPaths[i] : '';
      final trimmedUrl = url.trim();
      final trimmedPath = path.trim();
      if (trimmedUrl.isEmpty && trimmedPath.isEmpty) continue;

      final isRemote =
          trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://');
      final isDataUrl = trimmedUrl.startsWith('data:image/');
      final isOnline = isRemote || isDataUrl;
      final storagePath = isRemote ? trimmedPath : '';
      pairs.add(
        InspectionPhotoData(
          photoUrl: isOnline ? trimmedUrl : '',
          storagePath: storagePath,
          localPath: isOnline ? '' : trimmedPath,
          pendingSync: !isOnline,
          syncError: null,
        ),
      );
    }
    return pairs;
  }
}

@HiveType(typeId: 5)
class InspectionPhotoData {
  /// URL remota da foto no Storage (quando já sincronizada).
  @HiveField(0)
  final String photoUrl;

  /// Caminho remoto no Firebase Storage.
  @HiveField(1)
  final String storagePath;

  /// Caminho local no dispositivo (offline-first).
  @HiveField(2)
  final String localPath;

  @HiveField(3)
  final bool pendingSync;

  @HiveField(4)
  final String? syncError;

  const InspectionPhotoData({
    required this.photoUrl,
    required this.storagePath,
    this.localPath = '',
    this.pendingSync = false,
    this.syncError,
  });

  InspectionPhotoData copyWith({
    String? photoUrl,
    String? storagePath,
    String? localPath,
    bool? pendingSync,
    String? syncError,
  }) {
    return InspectionPhotoData(
      photoUrl: photoUrl ?? this.photoUrl,
      storagePath: storagePath ?? this.storagePath,
      localPath: localPath ?? this.localPath,
      pendingSync: pendingSync ?? this.pendingSync,
      syncError: syncError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoUrl': photoUrl,
      'storagePath': storagePath,
      'localPath': localPath,
      'pendingSync': pendingSync,
      'syncError': syncError,
    };
  }

  factory InspectionPhotoData.fromMap(Map<String, dynamic> map) {
    return InspectionPhotoData(
      photoUrl: (map['photoUrl'] ?? '').toString(),
      storagePath: (map['storagePath'] ?? '').toString(),
      localPath: (map['localPath'] ?? '').toString(),
      pendingSync: map['pendingSync'] == true,
      syncError: map['syncError']?.toString(),
    );
  }
}

