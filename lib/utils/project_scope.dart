import '../utils/project_identity.dart';

const String kInspectionDraftPrefix = 'draft';

String? currentProjectIdOrNull(String? value) {
  final normalized = normalizeProjectId(value);
  if (normalized.isEmpty) return null;
  return normalized;
}

String requireCurrentProjectId(String? value) {
  final normalized = currentProjectIdOrNull(value);
  if (normalized != null) return normalized;
  throw StateError('Nenhuma obra ativa selecionada');
}

bool matchesActiveProject({
  required String? activeProjectId,
  required String? recordProjectId,
  String? recordObra,
}) {
  final active = currentProjectIdOrNull(activeProjectId);
  if (active == null) return false;
  return recordInProjectScope(
    recordProjectId: recordProjectId,
    recordObra: recordObra,
    currentProjectId: active,
  );
}

String buildInspectionDraftKey({
  required String projectId,
  required String obra,
  required String torre,
  required String andar,
  required String localRef,
  required String fvsCodigo,
  String? inspectionElement,
  String? operationalSheetId,
}) {
  final normalizedProjectId = normalizeProjectId(projectId);
  final elementKey = (inspectionElement ?? '').trim();
  final sheetKey = (operationalSheetId ?? '').trim();
  return '$kInspectionDraftPrefix:$normalizedProjectId:$obra:$torre:$andar:$localRef:$fvsCodigo:$elementKey:$sheetKey';
}

String buildInspectionLegacyDraftKey({
  required String obra,
  required String torre,
  required String andar,
  required String localRef,
  required String fvsCodigo,
}) {
  return '$kInspectionDraftPrefix:$obra:$torre:$andar:$localRef:$fvsCodigo';
}

String currentProjectIdFromPrefs(Map<dynamic, dynamic> prefs, {String? fallbackObra}) {
  return inferProjectId(
    projectId: prefs['current_project_id']?.toString(),
    obra: fallbackObra,
  );
}

bool recordInProjectScope({
  required String? recordProjectId,
  required String? recordObra,
  required String currentProjectId,
}) {
  final scoped = inferProjectId(projectId: recordProjectId, obra: recordObra);
  return scoped == currentProjectId;
}

Iterable<T> filterRecordsByProjectScope<T>(
  Iterable<T> input, {
  required String currentProjectId,
  required String? Function(T record) projectId,
  String? Function(T record)? obra,
}) {
  return input.where(
    (record) => recordInProjectScope(
      recordProjectId: projectId(record),
      recordObra: obra?.call(record),
      currentProjectId: currentProjectId,
    ),
  );
}

Iterable<Map<String, dynamic>> filterMapByProjectScope(
  Iterable<Map<String, dynamic>> input, {
  required String currentProjectId,
}) {
  return input.where(
    (record) => recordInProjectScope(
      recordProjectId: record['projectId']?.toString(),
      recordObra: record['obra']?.toString(),
      currentProjectId: currentProjectId,
    ),
  );
}

