import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/inspection_record.dart';
import 'photo_service.dart';

class InspectionLegacyMigrationService {
  InspectionLegacyMigrationService._();

  static final InspectionLegacyMigrationService instance =
      InspectionLegacyMigrationService._();

  Future<InspectionLegacyDiagnosis> diagnoseLegacyInspections({
    bool verboseLogs = true,
  }) async {
    return _run(applyChanges: false, verboseLogs: verboseLogs);
  }

  Future<InspectionLegacyMigrationResult> migrateLegacyInspections({
    bool dryRun = true,
    bool verboseLogs = true,
  }) async {
    final diagnosis = await _run(
      applyChanges: !dryRun,
      verboseLogs: verboseLogs,
    );
    return InspectionLegacyMigrationResult(
      diagnosis: diagnosis,
      applied: !dryRun,
      migratedRecordIds: diagnosis.migratedRecordIds,
    );
  }

  Future<InspectionLegacyDiagnosis> _run({
    required bool applyChanges,
    required bool verboseLogs,
  }) async {
    final box = Hive.box<InspectionRecord>('inspections');

    final allRecords = <InspectionLegacyRecordDiagnosis>[];
    final migratedRecordIds = <String>[];

    for (final record in box.values) {
      final analysis = await _analyzeRecord(record);
      final diagnosis = analysis.diagnosis;
      allRecords.add(diagnosis);

      if (diagnosis.isLegacySuspect && verboseLogs) {
        diagnosis.debugPrintDetails();
      }

      if (!applyChanges) continue;
      if (!diagnosis.isLegacySuspect) continue;

      final migrated = analysis.migratedRecordCandidate;
      if (_recordsEquivalent(record, migrated)) continue;

      await box.put(record.id, migrated);
      migratedRecordIds.add(record.id);
      if (verboseLogs) {
        debugPrint(
          '[INSPECTION][LEGACY][MIGRATE] '
          'id=${record.id} status:${record.status}->${migrated.status} '
          'locked:${record.locked}->${migrated.locked} pendingSync:${record.pendingSync}->${migrated.pendingSync}',
        );
      }
    }

    final suspects = allRecords.where((e) => e.isLegacySuspect).toList();
    final diagnosis = InspectionLegacyDiagnosis(
      applyChanges: applyChanges,
      totalAnalyzed: allRecords.length,
      totalLegacySuspects: suspects.length,
      totalLegacyStatus: suspects.where((e) => e.hasLegacyStatus).length,
      totalLockedInconsistent:
          suspects.where((e) => e.hasLockedInconsistency).length,
      totalWithPendingPhotos: allRecords.where((e) => e.pendingPhotos > 0).length,
      totalOrphanPhotos:
          allRecords.fold<int>(0, (acc, e) => acc + e.orphanPhotos),
      totalPendingPhotos:
          allRecords.fold<int>(0, (acc, e) => acc + e.pendingPhotos),
      totalMigrationEligible:
          suspects.where((e) => e.isEligibleForMigration).length,
      totalMigrated: migratedRecordIds.length,
      records: suspects,
      migratedRecordIds: migratedRecordIds,
    );

    if (verboseLogs) {
      diagnosis.debugPrintSummary();
    }
    return diagnosis;
  }

  Future<_RecordAnalysis> _analyzeRecord(InspectionRecord record) async {
    final canonicalStatus = InspectionRecord.normalizeStatus(record.status);
    final expectedLocked = InspectionRecord.expectedLockedForStatus(canonicalStatus);
    final lockedInconsistent = (record.locked ?? false) != expectedLocked;
    final hasLegacyStatus =
        record.status.trim() == InspectionRecord.statusFinalizedLegacy;

    var totalPhotos = 0;
    var pendingPhotos = 0;
    var photosWithLocalPath = 0;
    var localPathValidPhotos = 0;
    var missingLocalFilePhotos = 0;
    var orphanPhotos = 0;
    var pendingWithoutRemoteOrStorage = 0;
    var hasLegacyStructure = false;

    final migratedItems = <InspectionItemResult>[];

    for (final item in record.itens) {
      final currentPhotos = item.photos.isNotEmpty
          ? item.photos
          : item.photoPaths
              .where((path) => path.trim().isNotEmpty)
              .map((path) {
              final raw = path.trim();
              final isOnline = PhotoService.instance.isRemoteUrl(raw);
              return InspectionPhotoData(
                photoUrl: isOnline ? raw : '',
                storagePath: isOnline
                    ? (PhotoService.instance.extractStoragePathFromUrl(raw) ?? '')
                    : '',
                localPath: isOnline ? '' : raw,
                pendingSync: !isOnline,
                syncError: null,
              );
            }).toList();

      if (item.photos.isEmpty && item.photoPaths.any((p) => p.trim().isNotEmpty)) {
        hasLegacyStructure = true;
      }

      final migratedPhotos = <InspectionPhotoData>[];
      for (final photo in currentPhotos) {
        totalPhotos++;

        final normalized = await _normalizePhotoForMigration(photo);
        final normalizedPhoto = normalized.photo;

        final hasRemoteUrl =
            PhotoService.instance.isRemoteUrl(normalizedPhoto.photoUrl);
        final hasStoragePath = normalizedPhoto.storagePath.trim().isNotEmpty;
        final hasLocalPath = normalizedPhoto.localPath.trim().isNotEmpty;

        if (normalizedPhoto.pendingSync) pendingPhotos++;
        if (hasLocalPath) photosWithLocalPath++;
        if (normalized.hasValidLocalPath) localPathValidPhotos++;
        if (normalized.localFileMissing) missingLocalFilePhotos++;
        if (normalized.isOrphan) orphanPhotos++;

        if (normalizedPhoto.pendingSync && !hasRemoteUrl && !hasStoragePath) {
          pendingWithoutRemoteOrStorage++;
        }

        if (!PhotoService.instance.isRemoteUrl(photo.photoUrl) &&
            photo.photoUrl.trim().isNotEmpty &&
            photo.localPath.trim().isEmpty) {
          hasLegacyStructure = true;
        }

        migratedPhotos.add(normalizedPhoto);
      }

      migratedItems.add(
        item.copyWith(
          photos: migratedPhotos,
          photoPaths: migratedPhotos
              .map((p) => p.photoUrl.trim().isNotEmpty ? p.photoUrl : p.localPath)
              .where((v) => v.trim().isNotEmpty)
              .toList(),
        ),
      );
    }

    final reopenedLegacy = InspectionRecord.isDraftStatus(canonicalStatus) &&
        (record.finalizedAt != null ||
            record.lockedAt != null ||
            (record.actionType ?? '').trim() == 'finalizou' ||
            record.locked == true);

    final hasFieldIncoherence = record.id.trim().isEmpty ||
        record.projectId.trim().isEmpty ||
        record.updatedAt.isBefore(record.createdAt);

    final reasons = <String>[];
    if (hasLegacyStatus) reasons.add('status_legacy_finalized');
    if (lockedInconsistent) reasons.add('locked_inconsistente_com_status');
    if (pendingWithoutRemoteOrStorage > 0) {
      reasons.add('foto_pending_sem_photoUrl_storagePath');
    }
    if (hasLegacyStructure) reasons.add('estrutura_legada_detectada');
    if (reopenedLegacy) reasons.add('reabertura_edicao_fluxo_antigo');
    if (hasFieldIncoherence) reasons.add('campos_atuais_ausentes_ou_incoerentes');

    final diagnosis = InspectionLegacyRecordDiagnosis(
      id: record.id,
      projectId: record.projectId,
      tower: record.torre,
      location: _formatLocation(record),
      fvsCode: record.fvsCodigo,
      fvsName: record.fvsNome,
      statusAtual: record.status,
      canonicalStatus: canonicalStatus,
      locked: record.locked,
      expectedLocked: expectedLocked,
      pendingSync: record.pendingSync,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      finalizedAt: record.finalizedAt,
      actionAt: record.actionAt,
      totalPhotos: totalPhotos,
      pendingPhotos: pendingPhotos,
      photosWithLocalPath: photosWithLocalPath,
      localPathValidPhotos: localPathValidPhotos,
      missingLocalFilePhotos: missingLocalFilePhotos,
      orphanPhotos: orphanPhotos,
      reasons: reasons,
      hasLegacyStatus: hasLegacyStatus,
      hasLockedInconsistency: lockedInconsistent,
      hasPendingPhotoWithoutRemoteOrStorage:
          pendingWithoutRemoteOrStorage > 0,
      hasLegacyStructure: hasLegacyStructure,
      reopenedLegacyFlow: reopenedLegacy,
      hasFieldIncoherence: hasFieldIncoherence,
    );

    final migratedCandidate = record.copyWith(
      status: canonicalStatus,
      locked: expectedLocked,
      finalizedAt: expectedLocked
          ? (record.finalizedAt ?? record.actionAt ?? record.lockedAt)
          : null,
      lockedAt: expectedLocked
          ? (record.lockedAt ??
              record.finalizedAt ??
              record.actionAt ??
              record.updatedAt)
          : null,
      actionType: InspectionRecord.canonicalActionType(canonicalStatus),
      itens: migratedItems,
      pendingSync: _shouldMarkRecordPendingSync(record: record, itens: migratedItems),
      updatedAt: diagnosis.isLegacySuspect ? DateTime.now() : record.updatedAt,
    );

    return _RecordAnalysis(
      diagnosis: diagnosis,
      migratedRecordCandidate: migratedCandidate,
    );
  }

  Future<_NormalizedPhoto> _normalizePhotoForMigration(
    InspectionPhotoData photo,
  ) async {
    var next = photo;

    final currentPhotoUrl = next.photoUrl.trim();
    final currentLocalPath = next.localPath.trim();

    // Compatibilidade: fluxo legado gravava caminho local em photoUrl.
    if (!PhotoService.instance.isRemoteUrl(currentPhotoUrl) &&
        currentPhotoUrl.isNotEmpty &&
        currentLocalPath.isEmpty) {
      next = next.copyWith(
        photoUrl: '',
        localPath: currentPhotoUrl,
        pendingSync: true,
        syncError: null,
      );
    }

    var storagePath = next.storagePath.trim();
    if (storagePath.isEmpty && PhotoService.instance.isRemoteUrl(next.photoUrl)) {
      storagePath =
          PhotoService.instance.extractStoragePathFromUrl(next.photoUrl) ?? '';
      next = next.copyWith(storagePath: storagePath);
    }

    final hasRemoteUrl = PhotoService.instance.isRemoteUrl(next.photoUrl);
    final hasLocalPath = next.localPath.trim().isNotEmpty;

    bool localFileMissing = false;
    bool hasValidLocalPath = false;

    if (hasLocalPath) {
      if (kIsWeb) {
        // No web não existe acesso a File; tratamos como potencialmente válido.
        hasValidLocalPath = true;
      } else {
        final file = File(next.localPath.trim());
        hasValidLocalPath = await file.exists();
        localFileMissing = !hasValidLocalPath;
      }
    }

    final noRemoteAndNoStorage =
        !hasRemoteUrl && next.storagePath.trim().isEmpty;
    final isOrphan = noRemoteAndNoStorage && !hasValidLocalPath;

    if (hasRemoteUrl) {
      next = next.copyWith(
        pendingSync: false,
        syncError: null,
      );
    } else if (hasValidLocalPath) {
      next = next.copyWith(
        pendingSync: true,
        syncError: null,
      );
    } else if (isOrphan) {
      next = next.copyWith(
        pendingSync: false,
        syncError: 'LEGACY_ORPHAN_PHOTO_NO_SOURCE',
      );
    }

    return _NormalizedPhoto(
      photo: next,
      localFileMissing: localFileMissing,
      hasValidLocalPath: hasValidLocalPath,
      isOrphan: isOrphan,
    );
  }

  bool _shouldMarkRecordPendingSync({
    required InspectionRecord record,
    required List<InspectionItemResult> itens,
  }) {
    final hasPendingPhotoSync = itens.any(
      (item) => item.photos.any((photo) => photo.pendingSync),
    );

    final normalizedStatus = InspectionRecord.normalizeStatus(record.status);
    final statusChanged = normalizedStatus != record.status;
    final expectedLocked =
        InspectionRecord.expectedLockedForStatus(normalizedStatus);
    final lockedChanged = (record.locked ?? false) != expectedLocked;
    final actionTypeChanged =
        (record.actionType ?? '').trim() !=
            InspectionRecord.canonicalActionType(normalizedStatus);

    return record.pendingSync ||
        hasPendingPhotoSync ||
        statusChanged ||
        lockedChanged ||
        actionTypeChanged;
  }

  bool _recordsEquivalent(InspectionRecord a, InspectionRecord b) {
    return a.toMap().toString() == b.toMap().toString();
  }

  String _formatLocation(InspectionRecord record) {
    final localRef = (record.localRef ?? '').trim();
    if (localRef.isNotEmpty) return localRef;
    return 'Apto ${record.apto} / Andar ${record.andar}';
  }
}

class InspectionLegacyDiagnosis {
  const InspectionLegacyDiagnosis({
    required this.applyChanges,
    required this.totalAnalyzed,
    required this.totalLegacySuspects,
    required this.totalLegacyStatus,
    required this.totalLockedInconsistent,
    required this.totalWithPendingPhotos,
    required this.totalOrphanPhotos,
    required this.totalPendingPhotos,
    required this.totalMigrationEligible,
    required this.totalMigrated,
    required this.records,
    required this.migratedRecordIds,
  });

  final bool applyChanges;
  final int totalAnalyzed;
  final int totalLegacySuspects;
  final int totalLegacyStatus;
  final int totalLockedInconsistent;
  final int totalWithPendingPhotos;
  final int totalOrphanPhotos;
  final int totalPendingPhotos;
  final int totalMigrationEligible;
  final int totalMigrated;
  final List<InspectionLegacyRecordDiagnosis> records;
  final List<String> migratedRecordIds;

  Map<String, dynamic> toMap() {
    return {
      'applyChanges': applyChanges,
      'totalAnalyzed': totalAnalyzed,
      'totalLegacySuspects': totalLegacySuspects,
      'totalLegacyStatus': totalLegacyStatus,
      'totalLockedInconsistent': totalLockedInconsistent,
      'totalWithPendingPhotos': totalWithPendingPhotos,
      'totalOrphanPhotos': totalOrphanPhotos,
      'totalPendingPhotos': totalPendingPhotos,
      'totalMigrationEligible': totalMigrationEligible,
      'totalMigrated': totalMigrated,
      'migratedRecordIds': migratedRecordIds,
      'records': records.map((e) => e.toMap()).toList(),
    };
  }

  void debugPrintSummary() {
    debugPrint(
      '[INSPECTION][LEGACY][SUMMARY] mode=${applyChanges ? 'MIGRATION' : 'DIAGNOSTIC'} '
      'analyzed=$totalAnalyzed suspects=$totalLegacySuspects legacyStatus=$totalLegacyStatus '
      'lockedInconsistent=$totalLockedInconsistent withPendingPhotos=$totalWithPendingPhotos '
      'pendingPhotos=$totalPendingPhotos orphanPhotos=$totalOrphanPhotos '
      'eligible=$totalMigrationEligible migrated=$totalMigrated',
    );
  }
}

class InspectionLegacyMigrationResult {
  const InspectionLegacyMigrationResult({
    required this.diagnosis,
    required this.applied,
    required this.migratedRecordIds,
  });

  final InspectionLegacyDiagnosis diagnosis;
  final bool applied;
  final List<String> migratedRecordIds;

  int get migratedCount => migratedRecordIds.length;

  Map<String, dynamic> toMap() {
    return {
      'applied': applied,
      'migratedCount': migratedCount,
      'migratedRecordIds': migratedRecordIds,
      'diagnosis': diagnosis.toMap(),
    };
  }
}

class InspectionLegacyRecordDiagnosis {
  const InspectionLegacyRecordDiagnosis({
    required this.id,
    required this.projectId,
    required this.tower,
    required this.location,
    required this.fvsCode,
    required this.fvsName,
    required this.statusAtual,
    required this.canonicalStatus,
    required this.locked,
    required this.expectedLocked,
    required this.pendingSync,
    required this.createdAt,
    required this.updatedAt,
    required this.finalizedAt,
    required this.actionAt,
    required this.totalPhotos,
    required this.pendingPhotos,
    required this.photosWithLocalPath,
    required this.localPathValidPhotos,
    required this.missingLocalFilePhotos,
    required this.orphanPhotos,
    required this.reasons,
    required this.hasLegacyStatus,
    required this.hasLockedInconsistency,
    required this.hasPendingPhotoWithoutRemoteOrStorage,
    required this.hasLegacyStructure,
    required this.reopenedLegacyFlow,
    required this.hasFieldIncoherence,
  });

  final String id;
  final String projectId;
  final String tower;
  final String location;
  final String fvsCode;
  final String fvsName;
  final String statusAtual;
  final String canonicalStatus;
  final bool? locked;
  final bool expectedLocked;
  final bool pendingSync;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;
  final DateTime? actionAt;
  final int totalPhotos;
  final int pendingPhotos;
  final int photosWithLocalPath;
  final int localPathValidPhotos;
  final int missingLocalFilePhotos;
  final int orphanPhotos;
  final List<String> reasons;

  final bool hasLegacyStatus;
  final bool hasLockedInconsistency;
  final bool hasPendingPhotoWithoutRemoteOrStorage;
  final bool hasLegacyStructure;
  final bool reopenedLegacyFlow;
  final bool hasFieldIncoherence;

  bool get isLegacySuspect => reasons.isNotEmpty;

  bool get isEligibleForMigration =>
      isLegacySuspect && (!hasFieldIncoherence || hasLegacyStatus || hasLockedInconsistency);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'tower': tower,
      'location': location,
      'fvsCode': fvsCode,
      'fvsName': fvsName,
      'statusAtual': statusAtual,
      'canonicalStatus': canonicalStatus,
      'locked': locked,
      'expectedLocked': expectedLocked,
      'pendingSync': pendingSync,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'finalizedAt': finalizedAt?.toIso8601String(),
      'actionAt': actionAt?.toIso8601String(),
      'totalPhotos': totalPhotos,
      'pendingPhotos': pendingPhotos,
      'photosWithLocalPath': photosWithLocalPath,
      'localPathValidPhotos': localPathValidPhotos,
      'missingLocalFilePhotos': missingLocalFilePhotos,
      'orphanPhotos': orphanPhotos,
      'reasons': reasons,
      'hasLegacyStatus': hasLegacyStatus,
      'hasLockedInconsistency': hasLockedInconsistency,
      'hasPendingPhotoWithoutRemoteOrStorage':
          hasPendingPhotoWithoutRemoteOrStorage,
      'hasLegacyStructure': hasLegacyStructure,
      'reopenedLegacyFlow': reopenedLegacyFlow,
      'hasFieldIncoherence': hasFieldIncoherence,
      'isEligibleForMigration': isEligibleForMigration,
    };
  }

  void debugPrintDetails() {
    debugPrint(
      '[INSPECTION][LEGACY][SUSPECT] '
      'id=$id projectId="$projectId" tower="$tower" location="$location" '
      'fvs="$fvsCode - $fvsName" status=$statusAtual canonical=$canonicalStatus '
      'locked=$locked expectedLocked=$expectedLocked pendingSync=$pendingSync '
      'createdAt=$createdAt updatedAt=$updatedAt finalizedAt=$finalizedAt actionAt=$actionAt '
      'photos(total=$totalPhotos pending=$pendingPhotos localPath=$photosWithLocalPath '
      'localPathValid=$localPathValidPhotos missingLocalFile=$missingLocalFilePhotos orphan=$orphanPhotos) '
      'reasons=${reasons.join(',')}',
    );
  }
}

class _RecordAnalysis {
  const _RecordAnalysis({
    required this.diagnosis,
    required this.migratedRecordCandidate,
  });

  final InspectionLegacyRecordDiagnosis diagnosis;
  final InspectionRecord migratedRecordCandidate;
}

class _NormalizedPhoto {
  const _NormalizedPhoto({
    required this.photo,
    required this.localFileMissing,
    required this.hasValidLocalPath,
    required this.isOrphan,
  });

  final InspectionPhotoData photo;
  final bool localFileMissing;
  final bool hasValidLocalPath;
  final bool isOrphan;
}

