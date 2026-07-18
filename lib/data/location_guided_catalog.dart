import 'arsen_structure.dart';
import '../services/project_settings_service.dart';

class LocationGuidedCatalog {
  LocationGuidedCatalog._();

  static const List<String> legacyStructuralElements = <String>[
    'Laje',
    'Escada',
    'Pilar',
    'Viga',
    'Viga do elevador',
    'Poço do elevador',
    'Shaft',
    'Parede estrutural',
    'Reservatório',
    'Rampa',
    'Muro',
    'Outro',
  ];

  static const List<String> legacyFacadeOrientations = <String>[
    'Frente',
    'Fundos',
    'Lateral esquerda',
    'Lateral direita',
  ];

  static const List<String> legacySectorPrincipals = <String>[
    'Garagem',
    'Paris',
    'Viena',
    'Cobertura',
    'Barrilete',
    'Reservatório',
    'Área técnica',
    'Área comum',
    'Outro',
  ];

  static const Map<String, List<String>> legacySectorSubLocations = <String, List<String>>{
    'Garagem': <String>['Subsolo', 'Térreo', 'G1', 'Módulo 1', 'Módulo 2', 'Módulo 3', 'Módulo 4', 'Rampa', 'Outro'],
    'Paris': <String>['Cobertura', 'Hall', 'Escada', 'Elevador', 'Outro'],
    'Viena': <String>['Cobertura', 'Hall', 'Escada', 'Elevador', 'Outro'],
    'Barrilete': <String>['Principal', 'Paris', 'Viena', 'Outro'],
    'Reservatório': <String>['Inferior', 'Superior', 'Outro'],
    'Área técnica': <String>['Casa de máquinas', 'Shaft', 'Duto', 'Outro'],
    'Área comum': <String>['Hall', 'Circulação', 'Escada', 'Elevador', 'Outro'],
    'Outro': <String>['Outro'],
  };

  static List<String> pavementsFor(String towerOrSector) {
    final normalized = towerOrSector.trim();
    if (normalized == 'Garagem') return garageLevels;

    if (normalized.isNotEmpty && normalized != 'Outros') {
      final out = <String>[...List<String>.generate(16, (i) => '${i + 1}º pavimento')];
      if (ProjectSettingsService.instance.currentProjectSettingsSync?.hasRooftop != false) {
        out.add('Cobertura');
      }
      return out;
    }
    return const <String>[];
  }

  static List<String> dynamicSectorSubLocations(String sector) {
    if (sector == 'Cobertura') {
      final fromParis = ObraStructure.specialAreasForTower('Paris').map((e) => e.label);
      final fromViena = ObraStructure.specialAreasForTower('Viena').map((e) => e.label);
      final unique = <String>{...fromParis, ...fromViena, 'Outro'};
      return unique.toList(growable: false);
    }
    final configured = ProjectSettingsService.instance.currentProjectSettingsSync?.sectorSubLocations[sector] ?? const <String>[];
    if (configured.isNotEmpty) return configured;
    return legacySectorSubLocations[sector] ?? const <String>['Outro'];
  }

  static List<String> get structuralElements {
    final configured = ProjectSettingsService.instance.currentProjectSettingsSync?.structuralElements ?? const <String>[];
    if (configured.isNotEmpty) return configured;
    return List<String>.from(legacyStructuralElements);
  }

  static List<String> get facadeOrientations {
    final configured = ProjectSettingsService.instance.currentProjectSettingsSync?.facadeOrientations ?? const <String>[];
    if (configured.isNotEmpty) return configured;
    return List<String>.from(legacyFacadeOrientations);
  }

  static List<String> get sectorPrincipals {
    final configured = ProjectSettingsService.instance.currentProjectSettingsSync?.sectorPrincipals ?? const <String>[];
    if (configured.isNotEmpty) return configured;
    return List<String>.from(legacySectorPrincipals);
  }

  static List<String> get garageModules {
    final garageEntries = ProjectSettingsService.instance.currentProjectSettingsSync?.sectorSubLocations['Garagem'] ??
        const <String>[];
    final parsed = garageEntries
        .where((e) => e.toLowerCase().contains('módulo') || e.toLowerCase().contains('modulo'))
        .toList(growable: false);
    if (parsed.isNotEmpty) return parsed;
    return const <String>['Módulo 1', 'Módulo 2', 'Módulo 3', 'Módulo 4'];
  }

  static List<String> get garageLevels {
    final garageEntries = ProjectSettingsService.instance.currentProjectSettingsSync?.sectorSubLocations['Garagem'] ??
        const <String>[];
    final parsed = garageEntries
        .where((e) {
          final lower = e.toLowerCase();
          return lower.contains('subsolo') || lower.contains('térreo') || lower.contains('terreo') || lower == 'g1';
        })
        .toList(growable: false);
    if (parsed.isNotEmpty) return parsed;
    return const <String>['Subsolo', 'Térreo', 'G1'];
  }

  static String sanitizeToken(String raw) {
    return raw
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Z0-9_]'), '');
  }
}

