import '../services/project_settings_service.dart';

class ObraStructure {
  static const String obraNome = 'Arsen Sabiá';

  static const List<String> legacyTowers = ['Paris', 'Viena'];
  static const int legacyTotalResidentialFloors = 16;
  static const int legacyApartmentsPerFloor = 4;

  static List<String> get torres {
    final configured = ProjectSettingsService.instance.currentProjectSettingsSync?.towers ?? const <String>[];
    if (configured.isNotEmpty) return configured;
    return List<String>.from(legacyTowers);
  }

  static const Map<String, List<SpecialAreaDefinition>> _legacySpecialAreasByTower = {
    'Paris': <SpecialAreaDefinition>[
      SpecialAreaDefinition(label: 'Piscina', localRef: 'PISCINA'),
      SpecialAreaDefinition(label: 'Salão de Festas', localRef: 'SALAO_FESTAS'),
      SpecialAreaDefinition(label: 'Brinquedoteca', localRef: 'BRINQUEDOTECA'),
      SpecialAreaDefinition(label: 'Banheiro Feminino', localRef: 'BANHEIRO_FEMININO'),
      SpecialAreaDefinition(label: 'Banheiro Masculino', localRef: 'BANHEIRO_MASCULINO'),
    ],
    'Viena': <SpecialAreaDefinition>[
      SpecialAreaDefinition(label: 'Academia', localRef: 'ACADEMIA'),
      SpecialAreaDefinition(label: 'Salão de Jogos', localRef: 'SALAO_JOGOS'),
      SpecialAreaDefinition(label: 'Banheiro Feminino', localRef: 'BANHEIRO_FEMININO'),
      SpecialAreaDefinition(label: 'Banheiro Masculino', localRef: 'BANHEIRO_MASCULINO'),
    ],
  };

  // Andares: 1..16 + Rooftop
  static List<String> andares() {
    final cfg = ProjectSettingsService.instance.currentProjectSettingsSync;
    final totalFloors = cfg?.totalResidentialFloors ?? legacyTotalResidentialFloors;
    final hasRooftop = cfg?.hasRooftop ?? true;

    final lista = <String>[];
    for (var i = 1; i <= totalFloors; i++) {
      lista.add('$iº');
    }
    if (hasRooftop) {
      lista.add('Rooftop');
    }
    return lista;
  }

  // Apartamentos por andar: 01..04 (ex: 503 = 5º andar apto 03)
  static List<String> apartamentosDoAndar(int andar) {
    final amount = ProjectSettingsService.instance.currentProjectSettingsSync?.apartmentsPerFloor ?? legacyApartmentsPerFloor;
    final safeAmount = amount < 1 ? legacyApartmentsPerFloor : amount;
    return List<String>.generate(
      safeAmount,
      (index) => '$andar${(index + 1).toString().padLeft(2, '0')}',
    );
  }

  static List<SpecialAreaDefinition> legacySpecialAreasForTower(String tower) {
    return List<SpecialAreaDefinition>.from(_legacySpecialAreasByTower[tower] ?? const <SpecialAreaDefinition>[]);
  }

  static List<SpecialAreaDefinition> specialAreasForTower(String tower) {
    final configured = ProjectSettingsService.instance.currentProjectSettingsSync?.specialAreasByTower[tower] ?? const [];
    if (configured.isNotEmpty) {
      return configured
          .map((e) => SpecialAreaDefinition(label: e.label, localRef: e.localRef))
          .toList(growable: false);
    }
    return legacySpecialAreasForTower(tower);
  }

  static List<OperationalGridCell> operationalCellsForTower(String tower) {
    final out = <OperationalGridCell>[];

    for (final area in specialAreasForTower(tower)) {
      out.add(
        OperationalGridCell(
          label: area.label,
          localRef: area.localRef,
          andar: 17,
          isSpecialArea: true,
        ),
      );
    }

    final totalFloors = ProjectSettingsService.instance.currentProjectSettingsSync?.totalResidentialFloors ??
        legacyTotalResidentialFloors;
    final perFloor = ProjectSettingsService.instance.currentProjectSettingsSync?.apartmentsPerFloor ??
        legacyApartmentsPerFloor;

    for (int floor = totalFloors; floor >= 1; floor--) {
      for (int apt = 1; apt <= perFloor; apt++) {
        final code = '$floor${apt.toString().padLeft(2, '0')}';
        out.add(
          OperationalGridCell(
            label: code,
            localRef: 'APTO_$code',
            andar: floor,
            isSpecialArea: false,
          ),
        );
      }
    }

    return out;
  }

  static String resolveLocalRefForTower({
    required String tower,
    String? localRef,
    String? apto,
  }) {
    final rawRef = (localRef ?? '').trim();
    if (rawRef.isNotEmpty && rawRef != 'ROOFTOP' && rawRef != 'COBERTURA') return rawRef;

    final aptLabel = (apto ?? '').trim();
    if (aptLabel.isNotEmpty) {
      if (RegExp(r'^\d{3,4}$').hasMatch(aptLabel)) return 'APTO_$aptLabel';
      final normalized = _normalize(aptLabel);
      for (final area in specialAreasForTower(tower)) {
        if (_normalize(area.label) == normalized) return area.localRef;
      }
    }

    if (rawRef.isNotEmpty) return rawRef;
    return 'APTO_$aptLabel';
  }

  static String _normalize(String v) {
    const from = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
    const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var out = v;
    for (int i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class SpecialAreaDefinition {
  final String label;
  final String localRef;

  const SpecialAreaDefinition({required this.label, required this.localRef});
}

class OperationalGridCell {
  final String label;
  final String localRef;
  final int andar;
  final bool isSpecialArea;

  const OperationalGridCell({
    required this.label,
    required this.localRef,
    required this.andar,
    required this.isSpecialArea,
  });
}
