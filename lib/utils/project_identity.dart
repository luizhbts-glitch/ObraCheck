const String kLegacyProjectId = 'arsen_sabia';
const String kLegacyProjectName = 'Arsen Sabiá';
const String kLegacyProjectCode = 'ARSEN-SABIA';

String normalizeProjectId(String? value) {
  return (value ?? '').trim();
}

String inferProjectId({
  String? projectId,
  String? obra,
}) {
  final normalized = normalizeProjectId(projectId);
  if (normalized.isNotEmpty) return normalized;

  final obraLower = (obra ?? '').trim().toLowerCase();
  if (obraLower.contains('arsen')) {
    return kLegacyProjectId;
  }

  return kLegacyProjectId;
}

