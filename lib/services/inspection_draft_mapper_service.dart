import 'package:hive/hive.dart';

import '../models/inspection_record.dart';
import '../utils/project_scope.dart';
import 'photo_service.dart';

class InspectionDraftFormState {
  final Map<int, String> statusByIndex;
  final Map<int, String> obsByIndex;
  final Map<int, List<InspectionPhotoData>> photosByIndex;
  final Map<int, double?> measuredValueByIndex;
  final Map<int, String> measuredUnitByIndex;
  final Map<int, String> technicalNoteByIndex;
  final Map<int, List<String>> sampledLocationsByIndex;
  final Map<int, String?> ncCompanyIdByIndex;
  final Map<int, String?> ncCompanyNameByIndex;

  const InspectionDraftFormState({
    required this.statusByIndex,
    required this.obsByIndex,
    required this.photosByIndex,
    this.measuredValueByIndex = const {},
    this.measuredUnitByIndex = const {},
    this.technicalNoteByIndex = const {},
    this.sampledLocationsByIndex = const {},
    this.ncCompanyIdByIndex = const {},
    this.ncCompanyNameByIndex = const {},
  });
}

class InspectionDraftMapperService {
  InspectionDraftMapperService._();

  static final InspectionDraftMapperService instance =
      InspectionDraftMapperService._();

  InspectionRecord? resolveDraftRecord({
    required Box<InspectionRecord> inspectionsBox,
    required Box prefs,
    required String draftKey,
    required String fallbackRecordId,
    String? currentProjectId,
  }) {
    String? draftId = prefs.get(draftKey) as String?;
    draftId ??= fallbackRecordId;

    final record = inspectionsBox.get(draftId);
    if (record == null || !record.isDraft) return null;
    final activeProjectId = currentProjectIdOrNull(currentProjectId);
    if (activeProjectId != null &&
        !matchesActiveProject(
          activeProjectId: activeProjectId,
          recordProjectId: record.projectId,
          recordObra: record.obra,
        )) {
      return null;
    }
    return record;
  }

  InspectionDraftFormState mapRecordToFormState(InspectionRecord record) {
    final statusByIndex = <int, String>{};
    final obsByIndex = <int, String>{};
    final photosByIndex = <int, List<InspectionPhotoData>>{};
    final measuredValueByIndex = <int, double?>{};
    final measuredUnitByIndex = <int, String>{};
    final technicalNoteByIndex = <int, String>{};
    final sampledLocationsByIndex = <int, List<String>>{};
    final ncCompanyIdByIndex = <int, String?>{};
    final ncCompanyNameByIndex = <int, String?>{};

    for (final item in record.itens) {
      final index = item.index;
      statusByIndex[index] = item.status;

      if (item.obs.isNotEmpty) {
        obsByIndex[index] = item.obs;
      }

      final mappedPhotos = item.photos.isNotEmpty
          ? List<InspectionPhotoData>.from(item.photos)
          : _mapLegacyPhotoPaths(item.photoPaths);

      if (mappedPhotos.isNotEmpty) {
        photosByIndex[index] = mappedPhotos;
      }

      if (item.measuredValue != null) {
        measuredValueByIndex[index] = item.measuredValue;
      }

      final measuredUnit = item.measuredUnit?.trim() ?? '';
      if (measuredUnit.isNotEmpty) {
        measuredUnitByIndex[index] = measuredUnit;
      }

      final technicalNote = item.technicalNote?.trim() ?? '';
      if (technicalNote.isNotEmpty) {
        technicalNoteByIndex[index] = technicalNote;
      }

      if (item.sampledLocations.isNotEmpty) {
        sampledLocationsByIndex[index] = List<String>.from(item.sampledLocations);
      }

      final ncCompanyId = item.ncCompanyId?.trim();
      if (ncCompanyId != null && ncCompanyId.isNotEmpty) {
        ncCompanyIdByIndex[index] = ncCompanyId;
      }

      final ncCompanyName = item.ncCompanyName?.trim();
      if (ncCompanyName != null && ncCompanyName.isNotEmpty) {
        ncCompanyNameByIndex[index] = ncCompanyName;
      }
    }

    return InspectionDraftFormState(
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
  }

  List<InspectionPhotoData> _mapLegacyPhotoPaths(List<String> photoPaths) {
    return photoPaths.map((source) {
      final trimmed = source.trim();
      if (trimmed.isEmpty) {
        return const InspectionPhotoData(
          photoUrl: '',
          storagePath: '',
          localPath: '',
          pendingSync: false,
          syncError: null,
        );
      }

      final isOnline =
          PhotoService.instance.isRemoteUrl(trimmed) ||
          PhotoService.instance.isDataUrl(trimmed);
      return InspectionPhotoData(
        photoUrl: isOnline ? trimmed : '',
        storagePath: PhotoService.instance.isRemoteUrl(trimmed)
            ? (PhotoService.instance.extractStoragePathFromUrl(trimmed) ?? '')
            : '',
        localPath: isOnline ? '' : trimmed,
        pendingSync: !isOnline,
        syncError: null,
      );
    }).where((photo) {
      return photo.photoUrl.trim().isNotEmpty || photo.localPath.trim().isNotEmpty;
    }).toList();
  }
}

