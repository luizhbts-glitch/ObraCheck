import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

import '../data/fvs_catalog.dart';
import '../data/fvs_data.dart';
import '../models/inspection_record.dart';
import '../utils/project_identity.dart';
import '../utils/project_scope.dart';
import 'project_context_service.dart';
import 'user_profile_service.dart';

class InspectionFinalizeValidation {
  const InspectionFinalizeValidation({
    required this.hasUnmarked,
    required this.nokWithoutObs,
    required this.itemsMissingRequiredPhoto,
  });

  final bool hasUnmarked;
  final List<int> nokWithoutObs;
  final List<int> itemsMissingRequiredPhoto;

  bool get canFinalize =>
      hasUnmarked == false &&
      nokWithoutObs.isEmpty &&
      itemsMissingRequiredPhoto.isEmpty;
}

class InspectionWorkflowService {
  InspectionWorkflowService._();

  static final InspectionWorkflowService instance =
      InspectionWorkflowService._();

  List<InspectionItemResult> composeItems({
    required FvsTemplate template,
    String? locationContext,
    required Map<int, String> statusByIndex,
    required Map<int, String> obsByIndex,
    required Map<int, List<InspectionPhotoData>> photosByIndex,
    Map<int, double?> measuredValueByIndex = const {},
    Map<int, String> measuredUnitByIndex = const {},
    Map<int, String> technicalNoteByIndex = const {},
    Map<int, List<String>> sampledLocationsByIndex = const {},
    Map<int, String?> ncCompanyIdByIndex = const {},
    Map<int, String?> ncCompanyNameByIndex = const {},
  }) {
    final itens = <InspectionItemResult>[];
    for (int i = 0; i < template.itens.length; i++) {
      final item = template.itens[i];
      final status = _normalizeItemStatus(statusByIndex[i]);
      final obs = (obsByIndex[i] ?? '').trim();
      final photos = List<InspectionPhotoData>.from(
        photosByIndex[i] ?? const [],
      );
      final proof = FvsProofCatalog.resolveForProject(
        fvsCode: template.codigo,
        itemIndex: i,
        locationContext: locationContext,
        fallback: item.proof,
      );
      final proofType = InspectionItemResult.normalizeProofType(
        proof.proofType,
      );
      final resolvedRequiresPhoto =
          proof.requiresPhoto ||
          proofType == InspectionItemResult.proofPhotoRequired;
      final measuredUnit = (measuredUnitByIndex[i] ?? '').trim();
      final technicalNote = (technicalNoteByIndex[i] ?? '').trim();
      final sampledLocations = (sampledLocationsByIndex[i] ?? const <String>[])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);

      itens.add(
        InspectionItemResult(
          index: i,
          descricao: item.descricao,
          dica: item.dica,
          status: status,
          obs: obs,
          photoPaths: photos
              .map(
                (photo) => photo.photoUrl.trim().isNotEmpty
                    ? photo.photoUrl
                    : photo.localPath,
              )
              .where((source) => source.trim().isNotEmpty)
              .toList(),
          photos: photos,
          ncCompanyId: status == 'nok' ? ncCompanyIdByIndex[i]?.trim() : null,
          ncCompanyName: status == 'nok'
              ? ncCompanyNameByIndex[i]?.trim()
              : null,
          proofType: proofType,
          requiresPhoto: resolvedRequiresPhoto,
          measuredValue: measuredValueByIndex[i],
          measuredUnit: measuredUnit.isEmpty
              ? proof.measurementUnit
              : measuredUnit,
          technicalNote: technicalNote,
          sampledLocations: sampledLocations,
          measurementToleranceMin: proof.measurementToleranceMin,
          measurementToleranceMax: proof.measurementToleranceMax,
          requiresTechnicalNote:
              proof.requiresTechnicalNote ||
              proofType == InspectionItemResult.proofTechnicalNote,
          supportsSampling:
              proof.supportsSampling ||
              proofType == InspectionItemResult.proofSampledLocation,
        ),
      );
    }
    return itens;
  }

  String _normalizeItemStatus(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'ok':
      case 'nok':
      case 'okAfterFix':
      case 'none':
        return (raw ?? 'none').trim();
      default:
        return 'none';
    }
  }

  (String?, String?) _firstNcCompanyFromItems(
    List<InspectionItemResult> itens,
  ) {
    for (final item in itens) {
      if (item.status != 'nok') continue;
      final id = item.ncCompanyId?.trim();
      final name = item.ncCompanyName?.trim();
      if ((id ?? '').isNotEmpty || (name ?? '').isNotEmpty) {
        return (id, name);
      }
    }
    return (null, null);
  }

  InspectionFinalizeValidation validateFinalize({
    required FvsTemplate template,
    String? locationContext,
    required Map<int, String> statusByIndex,
    required Map<int, String> obsByIndex,
    Map<int, List<InspectionPhotoData>> photosByIndex = const {},
    Map<int, double?> measuredValueByIndex = const {},
    Map<int, String> technicalNoteByIndex = const {},
  }) {
    bool hasUnmarked = false;
    final nokWithoutObs = <int>[];
    final itemsMissingRequiredPhoto = <int>[];

    for (int i = 0; i < template.itens.length; i++) {
      final status = _normalizeItemStatus(statusByIndex[i]);
      final obs = (obsByIndex[i] ?? '').trim();
      final proof = FvsProofCatalog.resolveForProject(
        fvsCode: template.codigo,
        itemIndex: i,
        locationContext: locationContext,
        fallback: template.itens[i].proof,
      );
      final proofType = InspectionItemResult.normalizeProofType(
        proof.proofType,
      );
      final photos = List<InspectionPhotoData>.from(
        photosByIndex[i] ?? const [],
      );
      final measured = measuredValueByIndex[i];
      final technicalNote = (technicalNoteByIndex[i] ?? '').trim();

      if (status == 'none') {
        hasUnmarked = true;
      }
      if (status == 'nok' && obs.isEmpty) {
        nokWithoutObs.add(i);
      }

      if (status != 'none') {
        final requiresPhoto =
            proof.requiresPhoto ||
            proofType == InspectionItemResult.proofPhotoRequired;
        if (requiresPhoto && photos.isEmpty) {
          itemsMissingRequiredPhoto.add(i);
        }

        if (proofType == InspectionItemResult.proofMeasurement &&
            measured == null) {
          nokWithoutObs.add(i);
        }

        final requiresTechnicalNote =
            proof.requiresTechnicalNote ||
            proofType == InspectionItemResult.proofTechnicalNote;
        if (requiresTechnicalNote && technicalNote.isEmpty) {
          nokWithoutObs.add(i);
        }
      }
    }

    return InspectionFinalizeValidation(
      hasUnmarked: hasUnmarked,
      nokWithoutObs: nokWithoutObs,
      itemsMissingRequiredPhoto: itemsMissingRequiredPhoto,
    );
  }

  bool hasNc(List<InspectionItemResult> itens) {
    return itens.any((item) => item.status == 'nok');
  }

  Future<void> _markInspectionPendingSync(String recordId) async {
    final prefs = Hive.box('prefs');
    await prefs.put('inspection_synced_$recordId', false);
  }

  Future<InspectionRecord> saveDraft({
    required Map<String, dynamic> location,
    required FvsTemplate template,
    required String draftKey,
    required String draftRecordId,
    String? currentRecordId,
    String? locationContext,
    required String? inspectionElement,
    String? operationalSheetId,
    String? operationalSheetLabel,
    List<InspectionItemResult>? itens,
    Map<int, String> statusByIndex = const {},
    Map<int, String> obsByIndex = const {},
    Map<int, List<InspectionPhotoData>> photosByIndex = const {},
    Map<int, double?> measuredValueByIndex = const {},
    Map<int, String> measuredUnitByIndex = const {},
    Map<int, String> technicalNoteByIndex = const {},
    Map<int, List<String>> sampledLocationsByIndex = const {},
    Map<int, String?> ncCompanyIdByIndex = const {},
    Map<int, String?> ncCompanyNameByIndex = const {},
    required UserProfileData? user,
  }) async {
    final torre = location['torre'] ?? '';
    final apto = location['apto'] ?? '';
    final localRef = location['localRef'] as String?;
    final andar = location['andar'] ?? 0;

    final prefs = Hive.box('prefs');
    final oldId = prefs.get(draftKey) as String?;

    final box = Hive.box<InspectionRecord>('inspections');
    final now = DateTime.now();
    final contextProjectId = await _safeCurrentProjectId();
    final explicitLocationProjectId = currentProjectIdOrNull(
      location['projectId']?.toString(),
    );
    final projectId =
        explicitLocationProjectId ??
        currentProjectIdOrNull(contextProjectId) ??
        inferProjectId(
          projectId: location['projectId']?.toString(),
          obra: location['obra']?.toString(),
        );
    final resolvedItens =
        itens ??
        composeItems(
          template: template,
          locationContext: locationContext,
          statusByIndex: statusByIndex,
          obsByIndex: obsByIndex,
          photosByIndex: photosByIndex,
          measuredValueByIndex: measuredValueByIndex,
          measuredUnitByIndex: measuredUnitByIndex,
          technicalNoteByIndex: technicalNoteByIndex,
          sampledLocationsByIndex: sampledLocationsByIndex,
          ncCompanyIdByIndex: ncCompanyIdByIndex,
          ncCompanyNameByIndex: ncCompanyNameByIndex,
        );
    final ncFromItems = _firstNcCompanyFromItems(resolvedItens);

    final reusable = _resolveReusableRecord(
      box: box,
      projectId: projectId.isNotEmpty ? projectId : contextProjectId,
      torre: '$torre',
      apto: '$apto',
      localRef: localRef,
      fvsCodigo: template.codigo,
      operationalSheetId: operationalSheetId,
      businessDate: now,
      preferredIds: [currentRecordId, draftRecordId, oldId],
    );
    final targetId = reusable?.id ?? draftRecordId;
    final existing = reusable ?? box.get(targetId);

    if (reusable != null && reusable.id != draftRecordId) {
      debugPrint(
        '[DUPLICATE_PREVENTED] mode=draft fvs=${template.codigo} '
        'local=${InspectionRecord.resolveLocationForLogicalKey(apto: '$apto', localRef: localRef)} '
        'date=${now.toLocal().toIso8601String()} reusedRecord=${reusable.id}',
      );
    }

    final projectName =
        location['obra']?.toString() ?? _safeCurrentProjectName();

    final record = InspectionRecord(
      id: targetId,
      obra: projectName,
      torre: torre,
      andar: andar,
      apto: apto,
      localRef: localRef,
      fvsCodigo: template.codigo,
      fvsNome: template.nome,
      itens: resolvedItens,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: InspectionRecord.statusDraft,
      locked: false,
      lockedAt: null,
      actionType: InspectionRecord.actionTypeFromStatus(
        InspectionRecord.statusDraft,
      ),
      actionByUid: user?.uid,
      actionByName: user?.nome,
      actionByCargo: user?.cargo,
      actionAt: now,
      deleted: false,
      pendingSync: true,
      deletedAt: null,
      ncCompanyId: ncFromItems.$1 ?? existing?.ncCompanyId,
      ncCompanyName: ncFromItems.$2 ?? existing?.ncCompanyName,
      inspectionElement: InspectionRecord.normalizeInspectionElement(
        inspectionElement,
      ),
      projectId: projectId.isNotEmpty ? projectId : contextProjectId,
      operationalSheetId: (operationalSheetId ?? '').trim().isEmpty
          ? null
          : operationalSheetId!.trim(),
      operationalSheetLabel: (operationalSheetLabel ?? '').trim().isEmpty
          ? null
          : operationalSheetLabel!.trim(),
    );

    await box.put(record.id, record);
    await _markInspectionPendingSync(record.id);

    await prefs.put(draftKey, record.id);
    await prefs.put('last_profissao', template.profissao);
    await prefs.put('last_fvs_codigo', template.codigo);

    return record;
  }

  Future<InspectionRecord> saveFinalized({
    required Map<String, dynamic> location,
    required FvsTemplate template,
    required String draftKey,
    required String draftRecordId,
    required String? currentRecordId,
    String? locationContext,
    required String? inspectionElement,
    String? operationalSheetId,
    String? operationalSheetLabel,
    List<InspectionItemResult>? itens,
    Map<int, String> statusByIndex = const {},
    Map<int, String> obsByIndex = const {},
    Map<int, List<InspectionPhotoData>> photosByIndex = const {},
    Map<int, double?> measuredValueByIndex = const {},
    Map<int, String> measuredUnitByIndex = const {},
    Map<int, String> technicalNoteByIndex = const {},
    Map<int, List<String>> sampledLocationsByIndex = const {},
    Map<int, String?> ncCompanyIdByIndex = const {},
    Map<int, String?> ncCompanyNameByIndex = const {},
    required UserProfileData? user,
    String? ncCompanyId,
    String? ncCompanyName,
  }) async {
    final torre = location['torre'] ?? '';
    final apto = location['apto'] ?? '';
    final localRef = location['localRef'] as String?;
    final andar = location['andar'] ?? 0;

    final prefs = Hive.box('prefs');
    final oldDraftId = prefs.get(draftKey) as String?;

    final box = Hive.box<InspectionRecord>('inspections');
    final now = DateTime.now();
    final contextProjectId = await _safeCurrentProjectId();
    final explicitLocationProjectId = currentProjectIdOrNull(
      location['projectId']?.toString(),
    );
    final projectId =
        explicitLocationProjectId ??
        currentProjectIdOrNull(contextProjectId) ??
        inferProjectId(
          projectId: location['projectId']?.toString(),
          obra: location['obra']?.toString(),
        );
    final resolvedItens =
        itens ??
        composeItems(
          template: template,
          locationContext: locationContext,
          statusByIndex: statusByIndex,
          obsByIndex: obsByIndex,
          photosByIndex: photosByIndex,
          measuredValueByIndex: measuredValueByIndex,
          measuredUnitByIndex: measuredUnitByIndex,
          technicalNoteByIndex: technicalNoteByIndex,
          sampledLocationsByIndex: sampledLocationsByIndex,
          ncCompanyIdByIndex: ncCompanyIdByIndex,
          ncCompanyNameByIndex: ncCompanyNameByIndex,
        );
    final ncFromItems = _firstNcCompanyFromItems(resolvedItens);

    final reusable = _resolveReusableRecord(
      box: box,
      projectId: projectId.isNotEmpty ? projectId : contextProjectId,
      torre: '$torre',
      apto: '$apto',
      localRef: localRef,
      fvsCodigo: template.codigo,
      operationalSheetId: operationalSheetId,
      businessDate: now,
      preferredIds: [currentRecordId, draftRecordId, oldDraftId],
    );
    final targetId = reusable?.id ?? currentRecordId ?? draftRecordId;
    final existing = reusable ?? box.get(targetId);

    if (reusable != null && reusable.id != (currentRecordId ?? draftRecordId)) {
      debugPrint(
        '[DUPLICATE_PREVENTED] mode=finalize fvs=${template.codigo} '
        'local=${InspectionRecord.resolveLocationForLogicalKey(apto: '$apto', localRef: localRef)} '
        'date=${now.toLocal().toIso8601String()} reusedRecord=${reusable.id}',
      );
    }

    final projectName =
        location['obra']?.toString() ?? _safeCurrentProjectName();

    final record = InspectionRecord(
      id: targetId,
      obra: projectName,
      torre: torre,
      andar: andar,
      apto: apto,
      localRef: localRef,
      fvsCodigo: template.codigo,
      fvsNome: template.nome,
      itens: resolvedItens,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: InspectionRecord.statusFinal,
      finalizedAt: now,
      locked: true,
      lockedAt: now,
      actionType: InspectionRecord.actionTypeFromStatus(
        InspectionRecord.statusFinal,
      ),
      actionByUid: user?.uid,
      actionByName: user?.nome,
      actionByCargo: user?.cargo,
      actionAt: now,
      deleted: false,
      pendingSync: true,
      deletedAt: null,
      ncCompanyId: ncCompanyId ?? ncFromItems.$1,
      ncCompanyName: ncCompanyName ?? ncFromItems.$2,
      inspectionElement: InspectionRecord.normalizeInspectionElement(
        inspectionElement,
      ),
      projectId: projectId.isNotEmpty ? projectId : contextProjectId,
      operationalSheetId: (operationalSheetId ?? '').trim().isEmpty
          ? null
          : operationalSheetId!.trim(),
      operationalSheetLabel: (operationalSheetLabel ?? '').trim().isEmpty
          ? null
          : operationalSheetLabel!.trim(),
    );

    await box.put(record.id, record);
    await _markInspectionPendingSync(record.id);

    await prefs.delete(draftKey);
    await prefs.put('last_profissao', template.profissao);
    await prefs.put('last_fvs_codigo', template.codigo);

    return record;
  }

  @visibleForTesting
  String normalizeItemStatusForTest(String? raw) => _normalizeItemStatus(raw);

  InspectionRecord? _resolveReusableRecord({
    required Box<InspectionRecord> box,
    required String projectId,
    required String torre,
    required String apto,
    required String? localRef,
    required String fvsCodigo,
    String? operationalSheetId,
    required DateTime businessDate,
    required List<String?> preferredIds,
  }) {
    for (final id in preferredIds) {
      final normalizedId = (id ?? '').trim();
      if (normalizedId.isEmpty) continue;
      final record = box.get(normalizedId);
      if (record != null && !record.deleted) {
        return record;
      }
    }

    final key = InspectionRecord.inspectionLogicalKey(
      projectId: projectId,
      torre: torre,
      apto: apto,
      localRef: localRef,
      fvsCodigo: fvsCodigo,
      operationalSheetId: operationalSheetId,
      businessDate: businessDate,
    );

    InspectionRecord? best;
    for (final record in box.values) {
      if (record.deleted) continue;
      if (record.logicalBusinessKey() != key) continue;
      if (best == null || record.updatedAt.isAfter(best.updatedAt)) {
        best = record;
      }
    }

    return best;
  }

  Future<String> _safeCurrentProjectId() async {
    try {
      return await ProjectContextService.instance.getCurrentProjectId();
    } catch (_) {
      try {
        return normalizeProjectId(
          Hive.box('prefs').get('current_project_id')?.toString(),
        );
      } catch (_) {
        return '';
      }
    }
  }

  String _safeCurrentProjectName() {
    try {
      return ProjectContextService.instance.currentProjectNameSync;
    } catch (_) {
      return kLegacyProjectName;
    }
  }
}
