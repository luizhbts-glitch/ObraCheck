import 'package:hive/hive.dart';

import '../data/arsen_structure.dart';
import '../data/fvs_data.dart';
import '../data/location_guided_catalog.dart';
import '../models/project_settings_record.dart';
import 'project_context_service.dart';

class ProjectSettingsService {
  ProjectSettingsService._();

  static final ProjectSettingsService instance = ProjectSettingsService._();
  static const String boxName = 'project_settings';

  Box get _box => Hive.box(boxName);

  ProjectSettingsRecord? getForProjectSync(String projectId) {
    final key = projectId.trim();
    if (key.isEmpty || !_box.isOpen) return null;
    final raw = _box.get(key);
    if (raw is! Map) return null;
    final parsed = ProjectSettingsRecord.fromMap(raw);
    if (parsed.projectId.trim().isEmpty) {
      return parsed.copyWith(projectId: key);
    }
    return parsed;
  }

  ProjectSettingsRecord? get currentProjectSettingsSync {
    final projectId = ProjectContextService.instance.currentProjectIdSync.trim();
    if (projectId.isEmpty) return null;
    return getForProjectSync(projectId);
  }

  Future<void> saveForProject(ProjectSettingsRecord record) async {
    final key = record.projectId.trim();
    if (key.isEmpty) return;
    await _box.put(key, record.copyWith(updatedAt: DateTime.now()).toMap());
  }

  Future<void> saveForCurrentProject(ProjectSettingsRecord record) async {
    final projectId = ProjectContextService.instance.currentProjectIdSync.trim();
    if (projectId.isEmpty) return;
    await saveForProject(record.copyWith(projectId: projectId));
  }

  Future<void> clearForCurrentProject() async {
    final projectId = ProjectContextService.instance.currentProjectIdSync.trim();
    if (projectId.isEmpty) return;
    await _box.delete(projectId);
  }

  List<FvsOperationalSheetConfig> activeOperationalSheetsForFvsSync(String fvsCode) {
    final code = fvsCode.trim();
    if (code.isEmpty) return const <FvsOperationalSheetConfig>[];
    final current = currentProjectSettingsSync;
    if (current == null) return const <FvsOperationalSheetConfig>[];
    return current.operationalSheets
        .where((e) => e.enabled && e.fvsCode.trim() == code)
        .toList(growable: false)
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  ProjectSettingsRecord buildLegacyDefault({required String projectId}) {
    final specials = <String, List<ProjectSpecialArea>>{};
    for (final tower in ObraStructure.legacyTowers) {
      specials[tower] = ObraStructure.legacySpecialAreasForTower(tower)
          .map((e) => ProjectSpecialArea(label: e.label, localRef: e.localRef))
          .toList(growable: false);
    }

    final now = DateTime.now();
    final defaultOperationalSheets = <FvsOperationalSheetConfig>[
      FvsOperationalSheetConfig(
        id: 'ops_monocapa_paris_fachada',
        fvsCode: FvsData.fvs45Codigo,
        label: 'Paris — Fachada',
        tower: 'Paris',
        context: 'facade',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      FvsOperationalSheetConfig(
        id: 'ops_monocapa_viena_fachada',
        fvsCode: FvsData.fvs45Codigo,
        label: 'Viena — Fachada',
        tower: 'Viena',
        context: 'facade',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      FvsOperationalSheetConfig(
        id: 'ops_monocapa_paris_varanda',
        fvsCode: FvsData.fvs45Codigo,
        label: 'Paris — Varanda',
        tower: 'Paris',
        context: 'unit',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
      FvsOperationalSheetConfig(
        id: 'ops_monocapa_viena_varanda',
        fvsCode: FvsData.fvs45Codigo,
        label: 'Viena — Varanda',
        tower: 'Viena',
        context: 'unit',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    return ProjectSettingsRecord(
      projectId: projectId,
      updatedAt: DateTime.now(),
      towers: List<String>.from(ObraStructure.legacyTowers),
      totalResidentialFloors: ObraStructure.legacyTotalResidentialFloors,
      apartmentsPerFloor: ObraStructure.legacyApartmentsPerFloor,
      hasRooftop: true,
      specialAreasByTower: specials,
      structuralElements: List<String>.from(LocationGuidedCatalog.legacyStructuralElements),
      facadeOrientations: List<String>.from(LocationGuidedCatalog.legacyFacadeOrientations),
      sectorPrincipals: List<String>.from(LocationGuidedCatalog.legacySectorPrincipals),
      sectorSubLocations: Map<String, List<String>>.fromEntries(
        LocationGuidedCatalog.legacySectorSubLocations.entries.map(
          (e) => MapEntry(e.key, List<String>.from(e.value)),
        ),
      ),
      fvsContextOverrides: const <String, dynamic>{},
      operationalSheets: defaultOperationalSheets,
      fvsProofPhotoOverrides: const <String, Map<int, bool>>{},
    );
  }
}

