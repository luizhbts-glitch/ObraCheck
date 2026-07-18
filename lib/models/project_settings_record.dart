class ProjectSettingsRecord {
  ProjectSettingsRecord({
    required this.projectId,
    required this.updatedAt,
    required this.towers,
    required this.totalResidentialFloors,
    required this.apartmentsPerFloor,
    required this.hasRooftop,
    required this.specialAreasByTower,
    required this.structuralElements,
    required this.facadeOrientations,
    required this.sectorPrincipals,
    required this.sectorSubLocations,
    required this.fvsContextOverrides,
    required this.operationalSheets,
    required this.fvsProofPhotoOverrides,
  });

  final String projectId;
  final DateTime updatedAt;

  final List<String> towers;
  final int totalResidentialFloors;
  final int apartmentsPerFloor;
  final bool hasRooftop;
  final Map<String, List<ProjectSpecialArea>> specialAreasByTower;

  final List<String> structuralElements;
  final List<String> facadeOrientations;
  final List<String> sectorPrincipals;
  final Map<String, List<String>> sectorSubLocations;

  /// Reserva para evolução futura (tipo de localização/contexto por FVS).
  final Map<String, dynamic> fvsContextOverrides;

  /// Camada operacional por obra/FVS (sem alterar FVS oficial).
  final List<FvsOperationalSheetConfig> operationalSheets;

  /// Override de foto obrigatória por FVS/itemIndex.
  final Map<String, Map<int, bool>> fvsProofPhotoOverrides;

  ProjectSettingsRecord copyWith({
    String? projectId,
    DateTime? updatedAt,
    List<String>? towers,
    int? totalResidentialFloors,
    int? apartmentsPerFloor,
    bool? hasRooftop,
    Map<String, List<ProjectSpecialArea>>? specialAreasByTower,
    List<String>? structuralElements,
    List<String>? facadeOrientations,
    List<String>? sectorPrincipals,
    Map<String, List<String>>? sectorSubLocations,
    Map<String, dynamic>? fvsContextOverrides,
    List<FvsOperationalSheetConfig>? operationalSheets,
    Map<String, Map<int, bool>>? fvsProofPhotoOverrides,
  }) {
    return ProjectSettingsRecord(
      projectId: projectId ?? this.projectId,
      updatedAt: updatedAt ?? this.updatedAt,
      towers: towers ?? this.towers,
      totalResidentialFloors:
          totalResidentialFloors ?? this.totalResidentialFloors,
      apartmentsPerFloor: apartmentsPerFloor ?? this.apartmentsPerFloor,
      hasRooftop: hasRooftop ?? this.hasRooftop,
      specialAreasByTower: specialAreasByTower ?? this.specialAreasByTower,
      structuralElements: structuralElements ?? this.structuralElements,
      facadeOrientations: facadeOrientations ?? this.facadeOrientations,
      sectorPrincipals: sectorPrincipals ?? this.sectorPrincipals,
      sectorSubLocations: sectorSubLocations ?? this.sectorSubLocations,
      fvsContextOverrides: fvsContextOverrides ?? this.fvsContextOverrides,
      operationalSheets: operationalSheets ?? this.operationalSheets,
      fvsProofPhotoOverrides:
          fvsProofPhotoOverrides ?? this.fvsProofPhotoOverrides,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'updatedAt': updatedAt.toIso8601String(),
      'towers': towers,
      'totalResidentialFloors': totalResidentialFloors,
      'apartmentsPerFloor': apartmentsPerFloor,
      'hasRooftop': hasRooftop,
      'specialAreasByTower': specialAreasByTower.map(
        (key, value) =>
            MapEntry(key, value.map((e) => e.toMap()).toList(growable: false)),
      ),
      'structuralElements': structuralElements,
      'facadeOrientations': facadeOrientations,
      'sectorPrincipals': sectorPrincipals,
      'sectorSubLocations': sectorSubLocations,
      'fvsContextOverrides': fvsContextOverrides,
      'operationalSheets': operationalSheets
          .map((e) => e.toMap())
          .toList(growable: false),
      'fvsProofPhotoOverrides': fvsProofPhotoOverrides.map(
        (key, value) => MapEntry(
          key,
          value.map((idx, val) => MapEntry(idx.toString(), val)),
        ),
      ),
    };
  }

  factory ProjectSettingsRecord.fromMap(Map<dynamic, dynamic> map) {
    List<String> toStringList(dynamic raw) {
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
      return const <String>[];
    }

    Map<String, List<ProjectSpecialArea>> parseSpecialAreas(dynamic raw) {
      final out = <String, List<ProjectSpecialArea>>{};
      if (raw is Map) {
        raw.forEach((key, value) {
          final tower = key.toString().trim();
          if (tower.isEmpty) return;
          if (value is! List) return;
          out[tower] = value
              .whereType<Map>()
              .map((row) => ProjectSpecialArea.fromMap(row))
              .where(
                (e) =>
                    e.label.trim().isNotEmpty && e.localRef.trim().isNotEmpty,
              )
              .toList(growable: false);
        });
      }
      return out;
    }

    Map<String, List<String>> parseSubLocations(dynamic raw) {
      final out = <String, List<String>>{};
      if (raw is Map) {
        raw.forEach((key, value) {
          final sector = key.toString().trim();
          if (sector.isEmpty || value is! List) return;
          out[sector] = value
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false);
        });
      }
      return out;
    }

    List<FvsOperationalSheetConfig> parseOperationalSheets(dynamic raw) {
      if (raw is! List) return const <FvsOperationalSheetConfig>[];
      return raw
          .whereType<Map>()
          .map(
            (e) => FvsOperationalSheetConfig.fromMap(
              Map<dynamic, dynamic>.from(e),
            ),
          )
          .where(
            (e) => e.fvsCode.trim().isNotEmpty && e.label.trim().isNotEmpty,
          )
          .toList(growable: false);
    }

    Map<String, Map<int, bool>> parseProofPhotoOverrides(dynamic raw) {
      final out = <String, Map<int, bool>>{};
      if (raw is! Map) return out;
      raw.forEach((fvsCode, items) {
        if (fvsCode is! String || fvsCode.trim().isEmpty) return;
        if (items is! Map) return;
        final itemMap = <int, bool>{};
        items.forEach((idx, required) {
          final itemIndex = int.tryParse(idx.toString());
          if (itemIndex == null) return;
          itemMap[itemIndex] = required == true;
        });
        if (itemMap.isNotEmpty) {
          out[fvsCode.trim()] = itemMap;
        }
      });
      return out;
    }

    final updatedAtRaw = map['updatedAt'];
    final updatedAt = updatedAtRaw is String
        ? (DateTime.tryParse(updatedAtRaw) ?? DateTime.now())
        : DateTime.now();

    return ProjectSettingsRecord(
      projectId: (map['projectId'] ?? '').toString(),
      updatedAt: updatedAt,
      towers: toStringList(map['towers']),
      totalResidentialFloors:
          int.tryParse((map['totalResidentialFloors'] ?? '').toString()) ?? 16,
      apartmentsPerFloor:
          int.tryParse((map['apartmentsPerFloor'] ?? '').toString()) ?? 4,
      hasRooftop: map['hasRooftop'] != false,
      specialAreasByTower: parseSpecialAreas(map['specialAreasByTower']),
      structuralElements: toStringList(map['structuralElements']),
      facadeOrientations: toStringList(map['facadeOrientations']),
      sectorPrincipals: toStringList(map['sectorPrincipals']),
      sectorSubLocations: parseSubLocations(map['sectorSubLocations']),
      fvsContextOverrides: map['fvsContextOverrides'] is Map
          ? Map<String, dynamic>.from(map['fvsContextOverrides'] as Map)
          : const <String, dynamic>{},
      operationalSheets: parseOperationalSheets(map['operationalSheets']),
      fvsProofPhotoOverrides: parseProofPhotoOverrides(
        map['fvsProofPhotoOverrides'],
      ),
    );
  }
}

class FvsOperationalSheetConfig {
  const FvsOperationalSheetConfig({
    required this.id,
    required this.fvsCode,
    required this.label,
    this.tower,
    this.sector,
    this.context,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fvsCode;
  final String label;
  final String? tower;
  final String? sector;
  final String? context;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  FvsOperationalSheetConfig copyWith({
    String? id,
    String? fvsCode,
    String? label,
    String? tower,
    String? sector,
    String? context,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FvsOperationalSheetConfig(
      id: id ?? this.id,
      fvsCode: fvsCode ?? this.fvsCode,
      label: label ?? this.label,
      tower: tower ?? this.tower,
      sector: sector ?? this.sector,
      context: context ?? this.context,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fvsCode': fvsCode,
      'label': label,
      'tower': tower,
      'sector': sector,
      'context': context,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FvsOperationalSheetConfig.fromMap(Map<dynamic, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return FvsOperationalSheetConfig(
      id: (map['id'] ?? '').toString(),
      fvsCode: (map['fvsCode'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      tower: map['tower']?.toString(),
      sector: map['sector']?.toString(),
      context: map['context']?.toString(),
      enabled: map['enabled'] != false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class ProjectSpecialArea {
  const ProjectSpecialArea({required this.label, required this.localRef});

  final String label;
  final String localRef;

  Map<String, dynamic> toMap() {
    return {'label': label, 'localRef': localRef};
  }

  factory ProjectSpecialArea.fromMap(Map<dynamic, dynamic> map) {
    return ProjectSpecialArea(
      label: (map['label'] ?? '').toString(),
      localRef: (map['localRef'] ?? '').toString(),
    );
  }
}
