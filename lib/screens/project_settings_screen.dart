import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../data/fvs_catalog.dart';
import '../models/inspection_record.dart';
import '../models/project_settings_record.dart';
import '../models/service_record.dart';
import '../services/photo_service.dart';
import '../services/project_context_service.dart';
import '../services/project_settings_service.dart';
import '../theme/app_colors.dart';
import '../utils/project_scope.dart';
import 'fvs_location_rules_settings_screen.dart';
import 'photo_requirement_settings_screen.dart';

class ProjectSettingsScreen extends StatefulWidget {
  const ProjectSettingsScreen({super.key});

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProjectContextService _projectContext = ProjectContextService.instance;
  final ProjectSettingsService _settingsService =
      ProjectSettingsService.instance;

  final TextEditingController _floorsController = TextEditingController();
  final TextEditingController _apartmentsController = TextEditingController();

  bool _hasRooftop = true;
  bool _loading = true;
  bool _saving = false;
  bool _apagandoInspecoes = false;

  List<String> _towers = <String>[];
  String _selectedTower = 'Paris';
  String _selectedSector = 'Garagem';

  List<_SpecialAreaDraft> _selectedTowerAreas = <_SpecialAreaDraft>[];
  List<String> _structuralElements = <String>[];
  List<String> _facadeOrientations = <String>[];
  List<String> _sectorPrincipals = <String>[];
  Map<String, List<String>> _sectorSubLocations = <String, List<String>>{};
  List<_FvsContextDraft> _fvsContexts = <_FvsContextDraft>[];
  Map<String, dynamic> _fvsContextOverrides = <String, dynamic>{};
  List<_OperationalSheetDraft> _operationalSheets = <_OperationalSheetDraft>[];
  Map<String, Map<int, bool>> _fvsProofPhotoOverrides =
      <String, Map<int, bool>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _floorsController.dispose();
    _apartmentsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final projectId = _projectContext.currentProjectIdSync.trim();
    final record =
        _settingsService.currentProjectSettingsSync ??
        _settingsService.buildLegacyDefault(projectId: projectId);
    _applyRecord(record);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _applyRecord(ProjectSettingsRecord record) {
    final towers = record.towers.toSet().toList(growable: true);
    if (towers.isEmpty) {
      towers.add('Paris');
    }

    _towers = towers;
    _selectedTower = _towers.first;

    _floorsController.text = record.totalResidentialFloors.toString();
    _apartmentsController.text = record.apartmentsPerFloor.toString();
    _hasRooftop = record.hasRooftop;

    _selectedTowerAreas =
        (record.specialAreasByTower[_selectedTower] ??
                const <ProjectSpecialArea>[])
            .map(_SpecialAreaDraft.fromRecord)
            .toList(growable: true);

    _structuralElements = record.structuralElements.toSet().toList(
      growable: true,
    );
    _facadeOrientations = record.facadeOrientations.toSet().toList(
      growable: true,
    );
    _sectorPrincipals = record.sectorPrincipals.toSet().toList(growable: true);
    if (_sectorPrincipals.isEmpty) {
      _sectorPrincipals.add('Garagem');
    }

    _sectorSubLocations = <String, List<String>>{};
    for (final sector in _sectorPrincipals) {
      final list = (record.sectorSubLocations[sector] ?? const <String>[])
          .where((e) => e.trim().isNotEmpty)
          .toSet()
          .toList(growable: true);
      _sectorSubLocations[sector] = list;
    }
    _selectedSector = _sectorPrincipals.first;

    final rawContexts = record.fvsContextOverrides;
    _fvsContextOverrides = Map<String, dynamic>.from(rawContexts);
    _fvsContexts = rawContexts.entries
        .where((e) => e.value is String)
        .map(
          (e) => _FvsContextDraft(
            fvsCode: e.key,
            contextId: (e.value as String).trim(),
          ),
        )
        .where(
          (e) => e.fvsCode.trim().isNotEmpty && e.contextId.trim().isNotEmpty,
        )
        .toList(growable: true);

    _operationalSheets = record.operationalSheets
        .map(_OperationalSheetDraft.fromRecord)
        .toList(growable: true);

    _fvsProofPhotoOverrides = Map.from(record.fvsProofPhotoOverrides);
  }

  List<String> _allFvsCodes() {
    final out =
        FvsCatalog.all
            .map((e) => e.codigo.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList(growable: true)
          ..sort((a, b) => a.compareTo(b));
    return out;
  }

  Future<void> _addOperationalSheetGuided() async {
    final fvsOptions = _allFvsCodes();
    if (fvsOptions.isEmpty) return;

    String selectedCode = fvsOptions.first;
    final labelController = TextEditingController();
    final towerController = TextEditingController();
    final sectorController = TextEditingController();
    final contextController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Adicionar folha operacional'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCode,
                      items: fvsOptions
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text('FVS $v'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) =>
                          setLocal(() => selectedCode = (v ?? selectedCode)),
                      decoration: const InputDecoration(
                        labelText: 'FVS oficial',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: 'Label operacional',
                        hintText: 'Ex.: Paris - Fachada',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: towerController,
                      decoration: const InputDecoration(
                        labelText: 'Torre (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: sectorController,
                      decoration: const InputDecoration(
                        labelText: 'Setor (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contextController,
                      decoration: const InputDecoration(
                        labelText: 'Contexto (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );

    final label = labelController.text.trim();
    final tower = towerController.text.trim();
    final sector = sectorController.text.trim();
    final contextValue = contextController.text.trim();
    labelController.dispose();
    towerController.dispose();
    sectorController.dispose();
    contextController.dispose();

    if (confirmed != true || label.isEmpty) return;

    final now = DateTime.now();
    final id =
        'ops_${now.microsecondsSinceEpoch}_${selectedCode.replaceAll('.', '_')}';
    setState(() {
      _operationalSheets.add(
        _OperationalSheetDraft(
          id: id,
          fvsCode: selectedCode,
          label: label,
          tower: tower,
          sector: sector,
          context: contextValue,
          enabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  Future<void> _addSimpleItem({
    required String title,
    required void Function(String value) onAdd,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    onAdd(value.trim());
  }

  String _sanitizeRef(String raw) {
    return raw
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Z0-9_]'), '');
  }

  String _suggestRefFromLabel(String label) {
    final base = _sanitizeRef(label);
    return base.isEmpty ? 'LOCAL' : base;
  }

  List<String> _garageModules() {
    final all = _sectorSubLocations['Garagem'] ?? <String>[];
    final out = all
        .where((e) {
          final lower = e.toLowerCase();
          return lower.contains('modulo') || lower.contains('modulo');
        })
        .toList(growable: false);
    return out;
  }

  List<String> _garageLevels() {
    final all = _sectorSubLocations['Garagem'] ?? <String>[];
    return all
        .where((e) {
          final lower = e.toLowerCase();
          return lower.contains('subsolo') ||
              lower.contains('terreo') ||
              lower.contains('terreo') ||
              lower == 'g1';
        })
        .toList(growable: false);
  }

  List<String> _garageAreas() {
    final all = _sectorSubLocations['Garagem'] ?? <String>[];
    final modules = _garageModules().toSet();
    final levels = _garageLevels().toSet();
    return all
        .where((e) => !modules.contains(e) && !levels.contains(e))
        .toList(growable: false);
  }

  void _setGarageParts({
    List<String>? modules,
    List<String>? levels,
    List<String>? areas,
  }) {
    final currentModules = modules ?? _garageModules();
    final currentLevels = levels ?? _garageLevels();
    final currentAreas = areas ?? _garageAreas();
    _sectorSubLocations['Garagem'] = {
      ...currentLevels,
      ...currentModules,
      ...currentAreas,
    }.toList(growable: true);
  }

  void _changeTower(String tower) {
    setState(() {
      _persistSelectedTowerAreas();
      _selectedTower = tower;
      _selectedTowerAreas = _areasForTower(tower);
    });
  }

  List<_SpecialAreaDraft> _areasForTower(String tower) {
    final base =
        _settingsService.currentProjectSettingsSync ??
        _settingsService.buildLegacyDefault(
          projectId: _projectContext.currentProjectIdSync,
        );
    final persisted =
        base.specialAreasByTower[tower] ?? const <ProjectSpecialArea>[];
    return persisted.map(_SpecialAreaDraft.fromRecord).toList(growable: true);
  }

  void _persistSelectedTowerAreas() {
    // Persistencia em memoria (estado da tela) para evitar perda ao alternar torre.
    final cache = <String, List<_SpecialAreaDraft>>{};
    for (final t in _towers) {
      cache[t] = <_SpecialAreaDraft>[];
    }
    cache[_selectedTower] = _selectedTowerAreas;

    final current =
        _settingsService.currentProjectSettingsSync ??
        _settingsService.buildLegacyDefault(
          projectId: _projectContext.currentProjectIdSync,
        );
    final merged = Map<String, List<ProjectSpecialArea>>.from(
      current.specialAreasByTower,
    );
    merged[_selectedTower] = _selectedTowerAreas
        .map(
          (e) => ProjectSpecialArea(
            label: e.label.trim(),
            localRef: _sanitizeRef(e.localRef),
          ),
        )
        .toList(growable: false);

    final temp = current.copyWith(specialAreasByTower: merged);
    _runtimeRecord = temp;
  }

  ProjectSettingsRecord? _runtimeRecord;

  List<ProjectSpecialArea> _effectiveAreasFor(String tower) {
    final runtime = _runtimeRecord;
    if (runtime != null && runtime.specialAreasByTower.containsKey(tower)) {
      return runtime.specialAreasByTower[tower] ?? const <ProjectSpecialArea>[];
    }
    final fromSaved = _settingsService.currentProjectSettingsSync;
    if (fromSaved != null) {
      return fromSaved.specialAreasByTower[tower] ??
          const <ProjectSpecialArea>[];
    }
    final legacy = _settingsService.buildLegacyDefault(
      projectId: _projectContext.currentProjectIdSync,
    );
    return legacy.specialAreasByTower[tower] ?? const <ProjectSpecialArea>[];
  }

  String? _validateBeforeSave() {
    if (!_formKey.currentState!.validate()) return 'Formulario invalido.';
    if (_towers.isEmpty) return 'Adicione ao menos uma torre.';

    final uniqueTowers = _towers.map((e) => e.trim().toUpperCase()).toSet();
    if (uniqueTowers.length != _towers.length) {
      return 'Existem torres duplicadas.';
    }

    final floors = int.tryParse(_floorsController.text.trim()) ?? 0;
    if (floors < 1) return 'Quantidade de pavimentos deve ser maior que zero.';

    final apartments = int.tryParse(_apartmentsController.text.trim()) ?? 0;
    if (apartments < 1) return 'Aptos por pavimento deve ser maior que zero.';

    _persistSelectedTowerAreas();
    for (final tower in _towers) {
      final areas = _effectiveAreasFor(tower);
      final labels = <String>{};
      final refs = <String>{};
      for (final area in areas) {
        final label = area.label.trim();
        final ref = _sanitizeRef(area.localRef);
        if (label.isEmpty) {
          return 'Ha area especial sem nome na torre $tower.';
        }
        if (ref.isEmpty) {
          return 'Ha area especial sem referencia na torre $tower.';
        }
        if (!RegExp(r'^[A-Z0-9_]+$').hasMatch(ref)) {
          return 'localRef invalido na torre $tower: $ref';
        }
        final labelKey = label.toUpperCase();
        if (!labels.add(labelKey)) {
          return 'area especial duplicada "$label" na torre $tower.';
        }
        if (!refs.add(ref)) return 'localRef duplicado "$ref" na torre $tower.';
      }
    }

    String dupMessage(List<String> values, String title) {
      final cleaned = values
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      final unique = cleaned.map((e) => e.toUpperCase()).toSet();
      if (cleaned.length != unique.length) {
        return '$title possui itens duplicados.';
      }
      return '';
    }

    final dupA = dupMessage(_structuralElements, 'Elementos estruturais');
    if (dupA.isNotEmpty) return dupA;
    final dupB = dupMessage(_facadeOrientations, 'Orientacoes de fachada');
    if (dupB.isNotEmpty) return dupB;
    final dupC = dupMessage(_sectorPrincipals, 'Setores');
    if (dupC.isNotEmpty) return dupC;

    for (final e in _fvsContexts) {
      if (e.fvsCode.trim().isEmpty || e.contextId.trim().isEmpty) {
        return 'Ha item vazio em FVS e contextos.';
      }
    }
    final fvsKeys = _fvsContexts
        .map((e) => e.fvsCode.trim().toUpperCase())
        .toList(growable: false);
    if (fvsKeys.length != fvsKeys.toSet().length) {
      return 'Existem codigos de FVS duplicados na secao de contextos.';
    }

    final opIds = <String>{};
    final opCombo = <String>{};
    for (final sheet in _operationalSheets) {
      final id = sheet.id.trim();
      final fvsCode = sheet.fvsCode.trim();
      final label = sheet.label.trim();
      if (id.isEmpty || fvsCode.isEmpty || label.isEmpty) {
        return 'Ha folha operacional com campos obrigatorios vazios.';
      }
      if (!opIds.add(id)) {
        return 'Existem folhas operacionais duplicadas (id repetido).';
      }
      final combo = '${fvsCode.toUpperCase()}|${label.toUpperCase()}';
      if (!opCombo.add(combo)) {
        return 'Existem folhas operacionais duplicadas para a mesma FVS/label.';
      }
    }

    return null;
  }

  Future<void> _save() async {
    final error = _validateBeforeSave();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final projectId = _projectContext.currentProjectIdSync.trim();
    if (projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma obra ativa para salvar.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final base =
          _settingsService.currentProjectSettingsSync ??
          _settingsService.buildLegacyDefault(projectId: projectId);

      final areasByTower = <String, List<ProjectSpecialArea>>{};
      for (final tower in _towers) {
        final list = _effectiveAreasFor(tower)
            .map(
              (e) => ProjectSpecialArea(
                label: e.label.trim(),
                localRef: _sanitizeRef(e.localRef),
              ),
            )
            .toList(growable: false);
        areasByTower[tower] = list;
      }

      final fvsMap = Map<String, dynamic>.from(_fvsContextOverrides);
      for (final e in _fvsContexts) {
        fvsMap[e.fvsCode.trim()] = e.contextId.trim();
      }

      final operationalSheets = _operationalSheets
          .map(
            (e) => FvsOperationalSheetConfig(
              id: e.id.trim(),
              fvsCode: e.fvsCode.trim(),
              label: e.label.trim(),
              tower: e.tower.trim().isEmpty ? null : e.tower.trim(),
              sector: e.sector.trim().isEmpty ? null : e.sector.trim(),
              context: e.context.trim().isEmpty ? null : e.context.trim(),
              enabled: e.enabled,
              createdAt: e.createdAt,
              updatedAt: DateTime.now(),
            ),
          )
          .toList(growable: false);

      final updated = base.copyWith(
        projectId: projectId,
        updatedAt: DateTime.now(),
        towers: _towers,
        totalResidentialFloors: int.parse(_floorsController.text.trim()),
        apartmentsPerFloor: int.parse(_apartmentsController.text.trim()),
        hasRooftop: _hasRooftop,
        specialAreasByTower: areasByTower,
        structuralElements: _structuralElements,
        facadeOrientations: _facadeOrientations,
        sectorPrincipals: _sectorPrincipals,
        sectorSubLocations: _sectorSubLocations,
        fvsContextOverrides: fvsMap,
        operationalSheets: operationalSheets,
        fvsProofPhotoOverrides: _fvsProofPhotoOverrides,
      );

      await _settingsService.saveForCurrentProject(updated);
      _runtimeRecord = updated;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuracoes salvas com sucesso.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restoreLegacy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar defaults legados?'),
        content: const Text(
          'A tela sera preenchida com os padroes legados. Essa acao nao salva automaticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final record = _settingsService.buildLegacyDefault(
      projectId: _projectContext.currentProjectIdSync,
    );
    setState(() {
      _runtimeRecord = record;
      _applyRecord(record);
    });
  }

  /// Reseta só as personalizações de FVS desta obra (comprovação por foto
  /// obrigatória, fichas operacionais, contexto por FVS) pro padrão do
  /// app — NÃO mexe em torres/pavimentos/elementos estruturais nem nos
  /// registros de inspeção já feitos. Renomeado em 2026-09-30: "padrão de
  /// fábrica" virou o nome do botão de apagar inspeções (veja
  /// `_apagarInspecoesDaObra`), então esse aqui ficou só "ajustes de FVS".
  Future<void> _restoreFvsDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar ajustes de FVS?'),
        content: const Text(
          'Remove os ajustes desta obra pra FVS — comprovação por foto '
          'obrigatória, fichas operacionais e contexto por FVS — e volta pro '
          'padrão original do app. Não mexe em torres, pavimentos, elementos '
          'estruturais nem nos registros de inspeção já feitos (isso é só '
          'configuração). Salva na hora, não dá pra desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final defaults = _settingsService.buildLegacyDefault(
      projectId: _projectContext.currentProjectIdSync,
    );

    setState(() {
      _fvsContextOverrides = Map<String, dynamic>.from(
        defaults.fvsContextOverrides,
      );
      _fvsContexts = defaults.fvsContextOverrides.entries
          .where((e) => e.value is String)
          .map(
            (e) => _FvsContextDraft(
              fvsCode: e.key,
              contextId: (e.value as String).trim(),
            ),
          )
          .where(
            (e) => e.fvsCode.trim().isNotEmpty && e.contextId.trim().isNotEmpty,
          )
          .toList(growable: true);
      _operationalSheets = defaults.operationalSheets
          .map(_OperationalSheetDraft.fromRecord)
          .toList(growable: true);
      _fvsProofPhotoOverrides = Map.from(defaults.fvsProofPhotoOverrides);
    });

    await _save();
  }

  Future<void> _resetCurrentConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetar configuracao da obra?'),
        content: const Text(
          'Essa acao remove a configuracao salva desta obra e volta ao fallback legado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resetar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _settingsService.clearForCurrentProject();
    final fallback = _settingsService.buildLegacyDefault(
      projectId: _projectContext.currentProjectIdSync,
    );
    setState(() {
      _runtimeRecord = fallback;
      _applyRecord(fallback);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuracao salva removida. Fallback legado ativo.'),
      ),
    );
  }

  /// "Limpar FVS (padrão de fábrica)" — pedido do usuário em 2026-09-30,
  /// depois de uma correção explícita: isso NÃO é reset de configuração
  /// (aquilo é `_restoreFvsDefaults`), é apagar de verdade tudo que já foi
  /// medido nessa obra — inspeções, marcações, NC (derivado do status dos
  /// itens, sem coleção própria) e fotos — pra "começar do zero" sem criar
  /// outra obra. Também reseta o status dos serviços pra `em_andamento`
  /// (confirmado com o usuário: "Sim, reseta também"), já que eles ficam
  /// sem sentido descolados das inspeções que motivaram o status. Não
  /// toca em torres/pavimentos/elementos estruturais nem em outras obras.
  /// Usa o mesmo padrão de tombstone (`deleted/pendingSync/deletedAt`) do
  /// resto do app — nunca hard-delete — pra sync poder propagar.
  Future<void> _apagarInspecoesDaObra() async {
    final projectId = _projectContext.currentProjectIdSync.trim();
    if (projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma obra ativa.')),
      );
      return;
    }

    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar todas as inspeções desta obra?'),
        content: const Text(
          'Isso apaga permanentemente TODAS as inspeções já feitas nesta '
          'obra: marcações, não conformidades e fotos. Os serviços voltam '
          'pro status "em andamento". Torres, pavimentos, elementos '
          'estruturais e outras obras não são afetados. Essa ação não '
          'pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (firstConfirm != true) return;
    if (!mounted) return;

    final typedController = TextEditingController();
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final canConfirm = typedController.text.trim() == 'APAGAR';
            return AlertDialog(
              title: const Text('Confirmação final'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Digite APAGAR para confirmar a exclusão.'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: typedController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'APAGAR',
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: canConfirm
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Apagar tudo'),
                ),
              ],
            );
          },
        );
      },
    );
    typedController.dispose();
    if (finalConfirm != true) return;
    if (!mounted) return;

    setState(() => _apagandoInspecoes = true);
    try {
      final inspectionsBox = Hive.box<InspectionRecord>('inspections');
      final inspections = filterRecordsByProjectScope(
        inspectionsBox.values.where((r) => !r.deleted),
        currentProjectId: projectId,
        projectId: (r) => r.projectId,
        obra: (r) => r.obra,
      ).toList();

      final prefsBox = Hive.box('prefs');
      final now = DateTime.now();

      for (final record in inspections) {
        for (final item in record.itens) {
          for (final photo in item.photos) {
            try {
              if (photo.storagePath.isNotEmpty) {
                await PhotoService.instance.deletePhoto(photo.storagePath);
              }
              await PhotoService.instance.deleteLocalPhotoIfExists(
                photo.localPath,
              );
            } catch (_) {
              // Best-effort: continua apagando o resto mesmo se uma foto falhar.
            }
          }
        }

        final tombstone = record.copyWith(
          deleted: true,
          pendingSync: true,
          deletedAt: now,
          updatedAt: now,
        );
        await inspectionsBox.put(tombstone.id, tombstone);
        await prefsBox.put('inspection_synced_${tombstone.id}', false);
      }

      final servicesBox = Hive.box<ServiceRecord>('services');
      final services = filterRecordsByProjectScope(
        servicesBox.values.where((s) => !s.deleted),
        currentProjectId: projectId,
        projectId: (s) => s.projectId,
        obra: (s) => s.obra,
      ).where((s) => s.status != 'em_andamento').toList();

      for (final service in services) {
        final atualizado = service.copyWith(
          status: 'em_andamento',
          pendingSync: true,
          updatedAt: now,
        );
        await servicesBox.put(atualizado.id, atualizado);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${inspections.length} inspeção(ões) apagada(s) e '
            '${services.length} serviço(s) resetado(s).',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _apagandoInspecoes = false);
    }
  }

  int _totalSpecialAreas() {
    _persistSelectedTowerAreas();
    var count = 0;
    for (final tower in _towers) {
      count += _effectiveAreasFor(tower).length;
    }
    return count;
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajuda - Configuracoes da Obra'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _helpSection(
                '1. Estrutura da obra',
                'Define o numero de torres, pavimentos e apartamentos por andar. '
                    'Essas informacoes sao usadas para gerar os layouts automaticos de inspecao.',
              ),
              _helpSection(
                '2. areas especiais por torre',
                'Cadastre areas que nao sao apartamentos normais, como salao de festas, academia, '
                    'copa, etc. Cada area tera sua propria referencia (localRef) para inspections.',
              ),
              _helpSection(
                '3. Localizacoes especiais',
                'Configure elementos estruturais (pilares, vigas, etc.), orientacoes de fachada '
                    '(norte, sul, leste, oeste) e setores do empreendimento (garagem, area comum, etc.). '
                    'Isso cria uma estrutura hierarquica de localizacao para as inspecoes.',
              ),
              _helpSection(
                '4. FVS e contextos',
                'Define qual "contexto" cada FVS usa por padrao. O contexto determina como a '
                    'localizacao e registrada: unit (apartamento), structural (estrutura), '
                    'facade (fachada), sector (setor) ou free (livre).',
              ),
              _helpSection(
                '5. Folhas operacionais',
                'Crie versoes customizadas de FVS para towers ou setores especificos. '
                    'Util quando uma mesma FVS tem regras diferentes conforme a localizacao.',
              ),
              _helpSection(
                '6. Comprovacao por foto',
                'Resumo rapido da configuracao. Toque em "Configurar" para abrir a tela '
                    'dedicada onde voce pode definir quais itens de cada FVS exigirao foto '
                    'na inspecao. As alteracoes sao salvas automaticamente ao voltar.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _helpSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectName = _projectContext.currentProjectNameSync;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracoes da obra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ajuda',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Obra ativa: $projectName',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _SummaryCard(
                towers: _towers,
                floors: int.tryParse(_floorsController.text.trim()) ?? 0,
                apartments:
                    int.tryParse(_apartmentsController.text.trim()) ?? 0,
                totalSpecialAreas: _totalSpecialAreas(),
                structuralCount: _structuralElements.length,
                facadeCount: _facadeOrientations.length,
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '1. Estrutura da obra',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EditableChipsField(
                      title: 'Torres',
                      items: _towers,
                      onAdd: () => _addSimpleItem(
                        title: 'Adicionar torre',
                        onAdd: (value) {
                          final normalized = value.trim();
                          if (normalized.isEmpty) return;
                          if (_towers
                              .map((e) => e.toUpperCase())
                              .contains(normalized.toUpperCase())) {
                            return;
                          }
                          setState(() {
                            _towers.add(normalized);
                            _selectedTower = normalized;
                            _selectedTowerAreas = <_SpecialAreaDraft>[];
                          });
                        },
                      ),
                      onRemove: (item) {
                        if (_towers.length <= 1) return;
                        setState(() {
                          _persistSelectedTowerAreas();
                          _towers.remove(item);
                          _selectedTower = _towers.first;
                          _selectedTowerAreas = _areasForTower(_selectedTower);
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _floorsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Pavimentos',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim()) ?? 0;
                              if (n < 1) return 'Invalido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _apartmentsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Aptos por pavimento',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim()) ?? 0;
                              if (n < 1) return 'Invalido';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Possui Rooftop/Cobertura'),
                      value: _hasRooftop,
                      onChanged: (v) => setState(() => _hasRooftop = v),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Layout por pavimento (preview)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            final current =
                                int.tryParse(
                                  _apartmentsController.text.trim(),
                                ) ??
                                4;
                            if (current <= 1) return;
                            setState(
                              () =>
                                  _apartmentsController.text = '${current - 1}',
                            );
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: Text(
                            '${_apartmentsController.text.trim().isEmpty ? '0' : _apartmentsController.text} unidades por pavimento',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final current =
                                int.tryParse(
                                  _apartmentsController.text.trim(),
                                ) ??
                                4;
                            setState(
                              () =>
                                  _apartmentsController.text = '${current + 1}',
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final amount =
                            int.tryParse(_apartmentsController.text.trim()) ??
                            4;
                        final count = amount < 1 ? 1 : amount;
                        final cols = count <= 2
                            ? 2
                            : count <= 4
                            ? 2
                            : count <= 6
                            ? 3
                            : 4;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.8,
                              ),
                          itemCount: count,
                          itemBuilder: (context, index) {
                            return Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.black.withValues(alpha: 0.04),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text('Unidade ${index + 1}'),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '2. areas especiais por torre',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _towers
                          .map(
                            (tower) => ChoiceChip(
                              label: Text(tower),
                              selected: tower == _selectedTower,
                              onSelected: (_) => _changeTower(tower),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedTowerAreas.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: item.label,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome da area',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      item.label = v;
                                      if (!item.isManualRef) {
                                        item.localRef = _suggestRefFromLabel(v);
                                      }
                                    });
                                  },
                                  validator: (v) {
                                    if ((v ?? '').trim().isEmpty) {
                                      return 'Obrigatorio';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: item.localRef,
                                  decoration: const InputDecoration(
                                    labelText: 'Referncia (localRef)',
                                    helperText: 'Ex.: SALAO_FESTAS',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      item.localRef = _sanitizeRef(v);
                                      item.isManualRef = true;
                                    });
                                  },
                                  validator: (v) {
                                    final sanitized = _sanitizeRef(v ?? '');
                                    if (sanitized.isEmpty) {
                                      return 'Obrigatorio';
                                    }
                                    if (!RegExp(
                                      r'^[A-Z0-9_]+$',
                                    ).hasMatch(sanitized)) {
                                      return 'Formato invalido';
                                    }
                                    return null;
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: 'Excluir area',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => setState(
                                      () => _selectedTowerAreas.removeAt(index),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedTowerAreas.add(
                            _SpecialAreaDraft(label: '', localRef: 'LOCAL'),
                          );
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar area especial'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '3. Localizacoes especiais',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EditableChipsField(
                      title: 'Elementos estruturais',
                      items: _structuralElements,
                      onAdd: () => _addSimpleItem(
                        title: 'Adicionar elemento estrutural',
                        onAdd: (v) => setState(() {
                          if (!_structuralElements
                              .map((e) => e.toUpperCase())
                              .contains(v.toUpperCase())) {
                            _structuralElements.add(v);
                          }
                        }),
                      ),
                      onRemove: (item) =>
                          setState(() => _structuralElements.remove(item)),
                    ),
                    const SizedBox(height: 8),
                    _EditableChipsField(
                      title: 'Orientacoes de fachada',
                      items: _facadeOrientations,
                      onAdd: () => _addSimpleItem(
                        title: 'Adicionar orientacao de fachada',
                        onAdd: (v) => setState(() {
                          if (!_facadeOrientations
                              .map((e) => e.toUpperCase())
                              .contains(v.toUpperCase())) {
                            _facadeOrientations.add(v);
                          }
                        }),
                      ),
                      onRemove: (item) =>
                          setState(() => _facadeOrientations.remove(item)),
                    ),
                    const SizedBox(height: 8),
                    _EditableChipsField(
                      title: 'Setores',
                      items: _sectorPrincipals,
                      onAdd: () => _addSimpleItem(
                        title: 'Adicionar setor',
                        onAdd: (v) => setState(() {
                          if (!_sectorPrincipals
                              .map((e) => e.toUpperCase())
                              .contains(v.toUpperCase())) {
                            _sectorPrincipals.add(v);
                            _sectorSubLocations.putIfAbsent(
                              v,
                              () => <String>[],
                            );
                            _selectedSector = v;
                          }
                        }),
                      ),
                      onRemove: (item) {
                        if (_sectorPrincipals.length <= 1) return;
                        setState(() {
                          _sectorPrincipals.remove(item);
                          _sectorSubLocations.remove(item);
                          if (_selectedSector == item) {
                            _selectedSector = _sectorPrincipals.first;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sublocais por setor',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _sectorPrincipals
                            .map(
                              (sector) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(sector),
                                  selected: sector == _selectedSector,
                                  onSelected: (_) =>
                                      setState(() => _selectedSector = sector),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _EditableChipsField(
                      title: 'Sublocais de $_selectedSector',
                      items:
                          _sectorSubLocations[_selectedSector] ??
                          const <String>[],
                      onAdd: () => _addSimpleItem(
                        title: 'Adicionar sublocal em $_selectedSector',
                        onAdd: (v) {
                          setState(() {
                            final current =
                                _sectorSubLocations[_selectedSector] ??
                                <String>[];
                            if (!current
                                .map((e) => e.toUpperCase())
                                .contains(v.toUpperCase())) {
                              current.add(v);
                            }
                            _sectorSubLocations[_selectedSector] = current;
                          });
                        },
                      ),
                      onRemove: (item) {
                        setState(() {
                          final current =
                              _sectorSubLocations[_selectedSector] ??
                              <String>[];
                          current.remove(item);
                          _sectorSubLocations[_selectedSector] = current;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Editor dedicado da garagem',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    _EditableChipsField(
                      title: 'Niveis da garagem',
                      items: _garageLevels(),
                      onAdd: () => _addSimpleItem(
                        title: 'Adicionar nivel da garagem',
                        onAdd: (v) => setState(() {
                          final levels = [..._garageLevels()];
                          if (!levels
                              .map((e) => e.toUpperCase())
                              .contains(v.toUpperCase())) {
                            levels.add(v);
                          }
                          _setGarageParts(levels: levels);
                        }),
                      ),
                      onRemove: (item) => setState(() {
                        final levels = [..._garageLevels()]..remove(item);
                        _setGarageParts(levels: levels);
                      }),
                    ),
                    const SizedBox(height: 8),
                    _EditableChipsField(
                      title: 'Modulos da garagem',
                      items: _garageModules(),
                      onAdd: () => _addSimpleItem(
                        title: 'Adicionar modulo da garagem',
                        onAdd: (v) => setState(() {
                          final modules = [..._garageModules()];
                          if (!modules
                              .map((e) => e.toUpperCase())
                              .contains(v.toUpperCase())) {
                            modules.add(v);
                          }
                          _setGarageParts(modules: modules);
                        }),
                      ),
                      onRemove: (item) => setState(() {
                        final modules = [..._garageModules()]..remove(item);
                        _setGarageParts(modules: modules);
                      }),
                    ),
                    const SizedBox(height: 8),
                    _EditableChipsField(
                      title:
                          'Sublocais/areas da garagem (rampas, tecnicas, etc.)',
                      items: _garageAreas(),
                      onAdd: () => _addSimpleItem(
                        title: 'Adicionar sublocal/area da garagem',
                        onAdd: (v) => setState(() {
                          final areas = [..._garageAreas()];
                          if (!areas
                              .map((e) => e.toUpperCase())
                              .contains(v.toUpperCase())) {
                            areas.add(v);
                          }
                          _setGarageParts(areas: areas);
                        }),
                      ),
                      onRemove: (item) => setState(() {
                        final areas = [..._garageAreas()]..remove(item);
                        _setGarageParts(areas: areas);
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FvsLocationRulesSummaryCard(
                overrides: _fvsContextOverrides,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FvsLocationRulesSettingsScreen(),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      final record =
                          _settingsService.currentProjectSettingsSync;
                      if (record != null) {
                        _fvsContextOverrides = Map<String, dynamic>.from(
                          record.fvsContextOverrides,
                        );
                        _fvsContexts = record.fvsContextOverrides.entries
                            .where((e) => e.value is String)
                            .map(
                              (e) => _FvsContextDraft(
                                fvsCode: e.key,
                                contextId: (e.value as String).trim(),
                              ),
                            )
                            .where(
                              (e) =>
                                  e.fvsCode.trim().isNotEmpty &&
                                  e.contextId.trim().isNotEmpty,
                            )
                            .toList(growable: true);
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              _PhotoRequirementSummaryCard(
                overrides: _fvsProofPhotoOverrides,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PhotoRequirementSettingsScreen(),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      final record =
                          _settingsService.currentProjectSettingsSync;
                      if (record != null) {
                        _fvsProofPhotoOverrides = Map.from(
                          record.fvsProofPhotoOverrides,
                        );
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '5. Folhas operacionais por FVS',
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _addOperationalSheetGuided,
                        icon: const Icon(Icons.playlist_add_check_outlined),
                        label: const Text('Adicionar folha operacional'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_operationalSheets.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Nenhuma folha operacional cadastrada. O app seguira com fallback para a FVS oficial.',
                        ),
                      )
                    else
                      ..._operationalSheets.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: item.fvsCode.isEmpty
                                        ? null
                                        : item.fvsCode,
                                    items: _allFvsCodes()
                                        .map(
                                          (v) => DropdownMenuItem(
                                            value: v,
                                            child: Text('FVS $v'),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (v) => setState(
                                      () => item.fvsCode = (v ?? '').trim(),
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'FVS oficial',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: item.label,
                                    decoration: const InputDecoration(
                                      labelText: 'Label operacional',
                                      hintText: 'Ex.: Paris - Fachada',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => item.label = v,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.tower,
                                          decoration: const InputDecoration(
                                            labelText: 'Torre (opcional)',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (v) => item.tower = v,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.sector,
                                          decoration: const InputDecoration(
                                            labelText: 'Setor (opcional)',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (v) => item.sector = v,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: item.context,
                                    decoration: const InputDecoration(
                                      labelText: 'Contexto (opcional)',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => item.context = v,
                                  ),
                                  const SizedBox(height: 4),
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Folha ativa'),
                                    value: item.enabled,
                                    onChanged: (v) =>
                                        setState(() => item.enabled = v),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => setState(
                                        () => _operationalSheets.removeAt(i),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ActionsCard(
                saving: _saving,
                onSave: _save,
                onRestoreLegacy: _restoreLegacy,
                onResetCurrentConfig: _resetCurrentConfig,
                onRestoreFvsDefaults: _restoreFvsDefaults,
                apagandoInspecoes: _apagandoInspecoes,
                onApagarInspecoes: _apagarInspecoesDaObra,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [child],
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.saving,
    required this.onSave,
    required this.onRestoreLegacy,
    required this.onResetCurrentConfig,
    required this.onRestoreFvsDefaults,
    required this.apagandoInspecoes,
    required this.onApagarInspecoes,
  });

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onRestoreFvsDefaults;
  final VoidCallback onRestoreLegacy;
  final VoidCallback onResetCurrentConfig;
  final bool apagandoInspecoes;
  final VoidCallback onApagarInspecoes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '6. Acoes gerais',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Salvando...' : 'Salvar configuracoes'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRestoreLegacy,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Restaurar defaults legados (na tela)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRestoreFvsDefaults,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Restaurar ajustes de FVS'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onResetCurrentConfig,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Resetar configuracao salva da obra'),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
            Text(
              'Zona de risco',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.redAccent.shade700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Apaga dados já registrados desta obra. Não pode ser desfeito.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: apagandoInspecoes ? null : onApagarInspecoes,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                icon: apagandoInspecoes
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(
                  apagandoInspecoes
                      ? 'Apagando...'
                      : 'Limpar FVS (padrão de fábrica)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.towers,
    required this.floors,
    required this.apartments,
    required this.totalSpecialAreas,
    required this.structuralCount,
    required this.facadeCount,
  });

  final List<String> towers;
  final int floors;
  final int apartments;
  final int totalSpecialAreas;
  final int structuralCount;
  final int facadeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _pill('Torres', towers.isEmpty ? '0' : towers.join(', ')),
            _pill('Pavimentos', '$floors'),
            _pill('Aptos/pav.', '$apartments'),
            _pill('areas especiais', '$totalSpecialAreas'),
            _pill('Estruturais', '$structuralCount'),
            _pill('Fachada', '$facadeCount'),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.05),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EditableChipsField extends StatelessWidget {
  const _EditableChipsField({
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final List<String> items;
  final VoidCallback onAdd;
  final void Function(String item) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (items.isEmpty)
          const Text('Nenhum item cadastrado.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => InputChip(
                    label: Text(item),
                    onDeleted: () => onRemove(item),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _SpecialAreaDraft {
  _SpecialAreaDraft({
    required this.label,
    required this.localRef,
    this.isManualRef = false,
  });

  factory _SpecialAreaDraft.fromRecord(ProjectSpecialArea area) {
    return _SpecialAreaDraft(
      label: area.label,
      localRef: area.localRef,
      isManualRef: true,
    );
  }

  String label;
  String localRef;
  bool isManualRef;
}

class _FvsLocationRulesSummaryCard extends StatelessWidget {
  const _FvsLocationRulesSummaryCard({
    required this.overrides,
    required this.onTap,
  });

  final Map<String, dynamic> overrides;
  final VoidCallback onTap;

  int _countMultiContextRules() {
    var count = 0;
    for (final raw in overrides.values) {
      if (raw is Map &&
          raw['contexts'] is List &&
          (raw['contexts'] as List).length > 1) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final configuredCount = overrides.length;
    final multiCount = _countMultiContextRules();
    final summaryText = configuredCount == 0
        ? 'Usando regras do catalogo, incluindo monocapa com unidade + fachada'
        : '$configuredCount FVS personalizada${configuredCount > 1 ? 's' : ''} - $multiCount com mais de um tipo';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: appColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.route_outlined, color: appColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '4. Regras de local por FVS',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summaryText,
                      style: TextStyle(
                        color: appColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: appColors.selected.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Configurar',
                      style: TextStyle(
                        color: appColors.selected,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: appColors.selected,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoRequirementSummaryCard extends StatelessWidget {
  const _PhotoRequirementSummaryCard({
    required this.overrides,
    required this.onTap,
  });

  final Map<String, Map<int, bool>> overrides;
  final VoidCallback onTap;

  int _countConfiguredFvs() {
    return overrides.keys.where((fvs) {
      final items = overrides[fvs]!;
      return items.values.any((v) => v == true);
    }).length;
  }

  int _countConfiguredItems() {
    int count = 0;
    for (final items in overrides.values) {
      count += items.values.where((v) => v == true).length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final fvsCount = _countConfiguredFvs();
    final itemsCount = _countConfiguredItems();

    final summaryText = fvsCount == 0
        ? 'Nenhum item com foto obrigatoria'
        : '$fvsCount FVS configurada${fvsCount > 1 ? 's' : ''} - $itemsCount itens com foto obrigatoria';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: appColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: appColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comprovacao por foto',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summaryText,
                      style: TextStyle(
                        color: appColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: appColors.selected.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Configurar',
                      style: TextStyle(
                        color: appColors.selected,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: appColors.selected,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FvsContextDraft {
  _FvsContextDraft({required this.fvsCode, required this.contextId});

  String fvsCode;
  String contextId;
}

class _OperationalSheetDraft {
  _OperationalSheetDraft({
    required this.id,
    required this.fvsCode,
    required this.label,
    required this.tower,
    required this.sector,
    required this.context,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _OperationalSheetDraft.fromRecord(FvsOperationalSheetConfig record) {
    return _OperationalSheetDraft(
      id: record.id,
      fvsCode: record.fvsCode,
      label: record.label,
      tower: record.tower ?? '',
      sector: record.sector ?? '',
      context: record.context ?? '',
      enabled: record.enabled,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  String id;
  String fvsCode;
  String label;
  String tower;
  String sector;
  String context;
  bool enabled;
  DateTime createdAt;
  DateTime updatedAt;
}
