import 'fvs_catalog.dart';
import '../services/project_settings_service.dart';

enum FvsLocationKind { unit, structural, facade, sector, free }

class FvsLocationContextOption {
  const FvsLocationContextOption({
    required this.id,
    required this.label,
    required this.kind,
  });

  final String id;
  final String label;
  final FvsLocationKind kind;
}

class FvsLocationProfile {
  const FvsLocationProfile({
    required this.defaultKind,
    this.contexts = const <FvsLocationContextOption>[],
  });

  final FvsLocationKind defaultKind;
  final List<FvsLocationContextOption> contexts;

  bool get hasVariableContext => contexts.length > 1;

  String get defaultContextId => contexts.isEmpty ? '' : contexts.first.id;

  FvsLocationKind resolveKind(String? contextId) {
    final normalized = (contextId ?? '').trim();
    if (normalized.isEmpty || contexts.isEmpty) return defaultKind;
    for (final ctx in contexts) {
      if (ctx.id == normalized) return ctx.kind;
    }
    return defaultKind;
  }
}

class FvsLocationCatalog {
  FvsLocationCatalog._();

  static const String contextUnit = 'unit';
  static const String contextFacade = 'facade';

  static const Map<String, FvsLocationProfile> _explicitByCode = {
    // Monocapa pode seguir fluxo por unidade ou por fachada.
    '4.5': FvsLocationProfile(
      defaultKind: FvsLocationKind.unit,
      contexts: <FvsLocationContextOption>[
        FvsLocationContextOption(
          id: contextUnit,
          label: 'Unidade / Interno',
          kind: FvsLocationKind.unit,
        ),
        FvsLocationContextOption(
          id: contextFacade,
          label: 'Fachada / Frente',
          kind: FvsLocationKind.facade,
        ),
      ],
    ),
  };

  static FvsLocationProfile profileForTemplate(FvsTemplate template) {
    return profileForCode(template.codigo);
  }

  static FvsLocationProfile profileForCode(String code) {
    final normalized = code.trim();

    final configured = _profileFromProjectSettings(normalized);
    if (configured != null) return configured;

    final explicit = _explicitByCode[normalized];
    if (explicit != null) return explicit;

    if (normalized.startsWith('2.') || normalized.startsWith('3.') || normalized.startsWith('9.')) {
      return const FvsLocationProfile(defaultKind: FvsLocationKind.structural);
    }
    if (normalized == '7.2') {
      return const FvsLocationProfile(defaultKind: FvsLocationKind.facade);
    }
    if (normalized.startsWith('1.') || normalized.startsWith('5.')) {
      return const FvsLocationProfile(defaultKind: FvsLocationKind.sector);
    }
    if (normalized.startsWith('8.')) {
      return const FvsLocationProfile(defaultKind: FvsLocationKind.sector);
    }

    return const FvsLocationProfile(defaultKind: FvsLocationKind.unit);
  }

  static FvsLocationProfile? _profileFromProjectSettings(String code) {
    final raw = ProjectSettingsService.instance.currentProjectSettingsSync?.fvsContextOverrides[code];
    if (raw == null) return null;

    if (raw is String) {
      final kind = _tryParseKind(raw);
      if (kind == null) return null;
      return FvsLocationProfile(defaultKind: kind);
    }

    if (raw is Map) {
      final defaultKindRaw = raw['defaultKind']?.toString() ?? raw['kind']?.toString() ?? '';
      final defaultKind = _tryParseKind(defaultKindRaw);
      if (defaultKind == null) return null;

      final contextsRaw = raw['contexts'];
      final contexts = <FvsLocationContextOption>[];
      if (contextsRaw is List) {
        for (final e in contextsRaw) {
          if (e is! Map) continue;
          final id = (e['id'] ?? '').toString().trim();
          final label = (e['label'] ?? id).toString().trim();
          final kind = _tryParseKind((e['kind'] ?? '').toString());
          if (id.isEmpty || label.isEmpty || kind == null) continue;
          contexts.add(FvsLocationContextOption(id: id, label: label, kind: kind));
        }
      }

      return FvsLocationProfile(
        defaultKind: defaultKind,
        contexts: contexts,
      );
    }

    return null;
  }

  static FvsLocationKind? _tryParseKind(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final kind in FvsLocationKind.values) {
      if (kind.name == normalized) return kind;
    }
    return null;
  }

  static String buildLocalRef({
    required FvsLocationKind kind,
    required String rawLabel,
  }) {
    final normalized = rawLabel
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Z0-9_]'), '');

    final safe = normalized.isEmpty ? 'LOCAL' : normalized;
    switch (kind) {
      case FvsLocationKind.unit:
        return safe.startsWith('APTO_') ? safe : 'APTO_$safe';
      case FvsLocationKind.structural:
        return 'STRUCT_$safe';
      case FvsLocationKind.facade:
        return 'FACADE_$safe';
      case FvsLocationKind.sector:
        return 'SECTOR_$safe';
      case FvsLocationKind.free:
        return 'FREE_$safe';
    }
  }
}

