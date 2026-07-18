// ignore_for_file: unused_element, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/arsen_structure.dart';
import '../data/fvs_catalog.dart';
import '../data/fvs_location_catalog.dart';
import '../data/location_guided_catalog.dart';
import '../models/inspection_location.dart';
import '../models/inspection_record.dart';
import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../utils/project_scope.dart';
import 'select_fvs_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({
    super.key,
    required this.title,
    this.autoOpenFvsOnMap = true,
    this.template,
    this.locationContext = '',
  });

  final String title;
  final bool autoOpenFvsOnMap;
  final FvsTemplate? template;
  final String locationContext;

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  // ── Stage (lógica original preservada) ────────────────────────────────────
  // Stage 0 = seleção inicial (Paris, Vienne, Garagem, Outros)
  // Stage 1 = andar (para Paris/Vienna) ou módulo (para Garagem)
  // Stage 2 = apartamento (Paris/Vienna) ou nível (Garagem) ou ambiente customizado (Outros)
  int _stage = 0;

  // ── Seleções (originais preservadas) ─────────────────────────────────────
  String? _torreSelecionada;
  int? _andarSelecionado;
  String? _apartamentoSelecionado;
  String? _localRefSelecionado;
  String? _moduloSelecionado;
  String? _nivelSelecionado;
  String? _ambienteCustomizado;
  String? _ambienteRooftop;
  String? _guidedTowerOrSector;
  String? _guidedPavement;
  String? _guidedStructuralElement;
  String? _guidedFacadeOrientation;
  String? _guidedSectorMain;
  String? _guidedSectorSub;
  String? _guidedExtra;
  bool _isCompletingSelection = false;
  bool _isNavigatingToFvs = false;
  final TextEditingController _outrosController = TextEditingController();
  final ProjectContextService _projectContext = ProjectContextService.instance;

  // ── Stepper: passo visual atual (independente do _stage) ─────────────────
  // 0 = Torre/Setor  |  1 = Pavimento  |  2 = Local específico
  int _currentStep = 0;

  // ── Getters de tipo (originais preservados) ───────────────────────────────
  FvsLocationKind get _effectiveLocationKind {
    final template = widget.template;
    if (template == null) return FvsLocationKind.unit;
    final profile = FvsLocationCatalog.profileForTemplate(template);
    return profile.resolveKind(widget.locationContext);
  }

  bool get _usesUnitFlow => _effectiveLocationKind == FvsLocationKind.unit;
  bool get _usesGuidedStructural =>
      _effectiveLocationKind == FvsLocationKind.structural;
  bool get _usesGuidedFacade =>
      _effectiveLocationKind == FvsLocationKind.facade;
  bool get _usesGuidedSector =>
      _effectiveLocationKind == FvsLocationKind.sector;
  bool get _usesFreeFlow => _effectiveLocationKind == FvsLocationKind.free;

  String get _contextTypeLabel {
    switch (_effectiveLocationKind) {
      case FvsLocationKind.unit:
        return 'Unidade';
      case FvsLocationKind.structural:
        return 'Estrutural';
      case FvsLocationKind.sector:
        return 'Área comum';
      case FvsLocationKind.facade:
        return 'Fachada';
      case FvsLocationKind.free:
        return 'Livre';
    }
  }

  String get _manualLocationHint {
    switch (_effectiveLocationKind) {
      case FvsLocationKind.structural:
        return 'Ex: Pilar P12, Viga V04, Laje eixo B';
      case FvsLocationKind.facade:
        return 'Ex: Fachada Norte, Fachada Sul bloco A';
      case FvsLocationKind.sector:
        return 'Ex: Setor de carga, Barrilete, Casa de máquinas';
      case FvsLocationKind.free:
        return 'Ex: Local específico da inspeção';
      case FvsLocationKind.unit:
        return 'Ex: Hall social, Casa de máquinas, Barrilete, Portaria';
    }
  }

  String get _manualLocationLabel {
    switch (_effectiveLocationKind) {
      case FvsLocationKind.structural:
        return 'Elemento/trecho estrutural';
      case FvsLocationKind.facade:
        return 'Frente/trecho de fachada';
      case FvsLocationKind.sector:
        return 'Setor/área';
      case FvsLocationKind.free:
        return 'Local';
      case FvsLocationKind.unit:
        return 'Local';
    }
  }

  // ── Labels de stepper por tipo ────────────────────────────────────────────
  /// Retorna os rótulos das etapas visíveis para o tipo atual.
  List<String> get _stepLabels {
    if (_usesGuidedSector) return ['Setor', 'Sub-setor'];
    if (_usesGuidedStructural) return ['Torre', 'Pavimento', 'Elemento'];
    if (_usesGuidedFacade) return ['Torre', 'Pavimento', 'Orientação'];
    if (_usesFreeFlow) return ['Local'];
    // unit
    if (_torreSelecionada == 'Garagem') return ['Setor', 'Módulo', 'Nível'];
    if (_torreSelecionada == 'Outros') return ['Setor', 'Local'];
    return ['Torre', 'Pavimento', 'Apartamento'];
  }

  /// Quantos passos existem para o tipo/seleção atual.
  int get _totalSteps => _stepLabels.length;

  // ── Helpers (originais preservados) ──────────────────────────────────────
  String _buildOutrosLocalRef(String localLabel) {
    final sanitized = localLabel
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Z0-9_]'), '');
    return 'OUTROS_${sanitized.isEmpty ? 'LOCAL' : sanitized}';
  }

  String _labelPavimento(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    return value;
  }

  String _buildStructuralLabel() {
    final tower = (_guidedTowerOrSector ?? '').trim();
    final pav = _labelPavimento(_guidedPavement ?? '');
    final element = (_guidedStructuralElement ?? '').trim();
    final extra = (_guidedExtra ?? '').trim();
    final elementLabel = element == 'Outro' && extra.isNotEmpty
        ? extra
        : element;
    return [tower, pav, elementLabel].where((e) => e.isNotEmpty).join(' · ');
  }

  String _buildFacadeLabel() {
    final tower = (_guidedTowerOrSector ?? '').trim();
    final orientation = (_guidedFacadeOrientation ?? '').trim().toLowerCase();
    final pav = _labelPavimento(_guidedPavement ?? '');
    final trecho = (_guidedExtra ?? '').trim();
    final out = <String>[
      tower,
      if (orientation.isNotEmpty) 'fachada $orientation',
      pav,
    ];
    if (trecho.isNotEmpty) out.add(trecho);
    return out.where((e) => e.isNotEmpty).join(' · ');
  }

  String _buildSectorLabel() {
    final main = (_guidedSectorMain ?? '').trim();
    final sub = (_guidedSectorSub ?? '').trim();
    final extra = (_guidedExtra ?? '').trim();
    return [main, sub, extra].where((e) => e.isNotEmpty).join(' · ');
  }

  List<String> get _towerOptions => ObraStructure.torres.isNotEmpty
      ? ObraStructure.torres
      : const <String>['Paris', 'Viena'];

  bool _isResidentialTower(String? tower) {
    final t = (tower ?? '').trim();
    return t.isNotEmpty && t != 'Garagem' && t != 'Outros';
  }

  int get _rooftopFloorMarker {
    final labels = ObraStructure.andares();
    var max = 16;
    for (final label in labels) {
      final digits = label.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(digits);
      if (parsed != null && parsed > max) max = parsed;
    }
    return max + 1;
  }

  bool _isRooftopFloor(int? floor) =>
      floor != null && floor == _rooftopFloorMarker;

  // ── initState (original preservado) ──────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (!_usesUnitFlow) {
      _torreSelecionada = 'Outros';
      _stage = 2;
      if (_usesGuidedStructural || _usesGuidedFacade) {
        _guidedTowerOrSector = _towerOptions.first;
      }
      if (_usesGuidedSector) {
        _guidedSectorMain = LocationGuidedCatalog.sectorPrincipals.first;
      }
      // Para guided flows, começa no passo 0 do stepper visual
      _currentStep = 0;
    }
  }

  @override
  void dispose() {
    _outrosController.dispose();
    super.dispose();
  }

  // ── Suggestions (originais preservados) ──────────────────────────────────
  String _normalizeSuggestionKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _historicalOutrosSuggestions() {
    final activeProjectId = _projectContext.currentProjectIdSync;
    final inspections = Hive.box<InspectionRecord>('inspections').values;
    final mostRecentByLabel = <String, DateTime>{};
    final canonicalByKey = <String, String>{};

    for (final record in inspections) {
      if (!matchesActiveProject(
        activeProjectId: activeProjectId,
        recordProjectId: record.projectId,
        recordObra: record.obra,
      )) {
        continue;
      }
      final isOutros =
          (record.torre.trim().toLowerCase() == 'outros') ||
          ((record.localRef ?? '').trim().toUpperCase().startsWith('OUTROS_'));
      if (!isOutros) continue;

      final rawLabel = (record.localRef?.trim().isNotEmpty == true)
          ? record.localRef!
                .trim()
                .replaceFirst(RegExp(r'^OUTROS_'), '')
                .replaceAll('_', ' ')
          : record.apto.trim();
      final fromLabel =
          record.localRef?.trim().toUpperCase().startsWith('OUTROS_') == true
          ? (record.apto.trim().isNotEmpty ? record.apto.trim() : rawLabel)
          : rawLabel;
      final label = fromLabel.trim();
      if (label.isEmpty) continue;

      final key = _normalizeSuggestionKey(label);
      final current = mostRecentByLabel[key];
      if (current == null || record.updatedAt.isAfter(current)) {
        mostRecentByLabel[key] = record.updatedAt;
        canonicalByKey[key] = label;
      }
    }

    final keys = mostRecentByLabel.keys.toList()
      ..sort((a, b) => mostRecentByLabel[b]!.compareTo(mostRecentByLabel[a]!));
    return keys.map((k) => canonicalByKey[k]!).toList();
  }

  List<String> _filterOutrosSuggestions(List<String> all, String query) {
    final q = _normalizeSuggestionKey(query);
    if (q.isEmpty) return all;
    return all
        .where((item) => _normalizeSuggestionKey(item).contains(q))
        .toList();
  }

  // ── Navegação por etapa (original preservada) ────────────────────────────
  void _voltarEtapa() {
    if (!_usesUnitFlow) {
      if (_currentStep > 0) {
        setState(() => _currentStep--);
        return;
      }
      Navigator.pop(context);
      return;
    }

    if (_stage == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      if (_stage == 2) {
        if (_torreSelecionada == 'Outros') {
          _stage = 0;
          _ambienteCustomizado = null;
          _torreSelecionada = null;
          _currentStep = 0;
          return;
        }

        _stage = 1;
        _currentStep = 1;
        if (_torreSelecionada == 'Garagem') {
          _nivelSelecionado = null;
        } else {
          _apartamentoSelecionado = null;
          _localRefSelecionado = null;
          _ambienteRooftop = null;
          _ambienteCustomizado = null;
        }
        return;
      }

      _stage = 0;
      _currentStep = 0;
      _andarSelecionado = null;
      _apartamentoSelecionado = null;
      _localRefSelecionado = null;
      _ambienteRooftop = null;
      _ambienteCustomizado = null;
      _moduloSelecionado = null;
      _nivelSelecionado = null;
    });
  }

  // ── Seleção no mapa (original preservada) ────────────────────────────────
  Future<void> _onSelectMapLocal(_LocalSelection selection) async {
    if (_isCompletingSelection || _isNavigatingToFvs) return;

    setState(() {
      _localRefSelecionado = selection.ref;
      _apartamentoSelecionado = selection.label;
    });

    if (widget.autoOpenFvsOnMap) {
      await _goToFvsFromMap();
      return;
    }

    _confirmar();
  }

  Future<void> _goToFvsFromMap() async {
    if (_isNavigatingToFvs || !_podeConfirmar) return;
    _isNavigatingToFvs = true;

    final location = _getResult();
    final fvsResult = await Navigator.push<SelectFvsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectFvsScreen(
          torre: location['torre']?.toString(),
          andar: location['andar'] is int ? location['andar'] as int : null,
          localLabel: location['localLabel']?.toString(),
          localRef: location['localRef']?.toString(),
        ),
      ),
    );

    if (!mounted) return;
    _isNavigatingToFvs = false;

    if (fvsResult == null) return;

    _isCompletingSelection = true;
    Navigator.pop(context, {
      'location': location,
      'template': fvsResult.template,
      'element': fvsResult.inspectionElement,
      'inspectionElement': fvsResult.inspectionElement,
      'locationContext': fvsResult.locationContext,
    });
  }

  // ── _podeConfirmar (original preservado) ─────────────────────────────────
  bool get _podeConfirmar {
    if (_torreSelecionada == null) return false;

    if (_usesGuidedStructural) {
      final tower = (_guidedTowerOrSector ?? '').trim();
      final pav = (_guidedPavement ?? '').trim();
      final element = (_guidedStructuralElement ?? '').trim();
      if (tower.isEmpty || pav.isEmpty || element.isEmpty) return false;
      if (element == 'Outro') return (_guidedExtra ?? '').trim().isNotEmpty;
      return true;
    }

    if (_usesGuidedFacade) {
      return (_guidedTowerOrSector ?? '').trim().isNotEmpty &&
          (_guidedFacadeOrientation ?? '').trim().isNotEmpty &&
          (_guidedPavement ?? '').trim().isNotEmpty;
    }

    if (_usesGuidedSector) {
      final main = (_guidedSectorMain ?? '').trim();
      final sub = (_guidedSectorSub ?? '').trim();
      if (main.isEmpty || sub.isEmpty) return false;
      if (main == 'Outro' || sub == 'Outro') {
        return (_guidedExtra ?? '').trim().isNotEmpty;
      }
      return true;
    }

    if (_usesFreeFlow) {
      return (_ambienteCustomizado ?? '').trim().isNotEmpty;
    }

    if (_isResidentialTower(_torreSelecionada)) {
      if (_andarSelecionado == null) return false;
      if (_isRooftopFloor(_andarSelecionado)) return _ambienteRooftop != null;
      return _localRefSelecionado != null;
    } else if (_torreSelecionada == 'Garagem') {
      return _moduloSelecionado != null && _nivelSelecionado != null;
    } else if (_torreSelecionada == 'Outros') {
      return _ambienteCustomizado != null &&
          _ambienteCustomizado!.trim().isNotEmpty;
    }
    return false;
  }

  // ── Mensagem de bloqueio do botão (NOVO) ──────────────────────────────────
  String? get _bloqueioConfirmar {
    if (_podeConfirmar) return null;

    if (_usesGuidedStructural) {
      if ((_guidedTowerOrSector ?? '').trim().isEmpty)
        return 'Selecione a torre';
      if ((_guidedPavement ?? '').trim().isEmpty)
        return 'Selecione o pavimento';
      if ((_guidedStructuralElement ?? '').trim().isEmpty)
        return 'Selecione o elemento';
      if (_guidedStructuralElement == 'Outro' &&
          (_guidedExtra ?? '').trim().isEmpty) {
        return 'Informe o complemento do elemento';
      }
    }

    if (_usesGuidedFacade) {
      if ((_guidedTowerOrSector ?? '').trim().isEmpty)
        return 'Selecione a torre';
      if ((_guidedPavement ?? '').trim().isEmpty)
        return 'Selecione o pavimento';
      if ((_guidedFacadeOrientation ?? '').trim().isEmpty)
        return 'Selecione a orientação';
    }

    if (_usesGuidedSector) {
      if ((_guidedSectorMain ?? '').trim().isEmpty)
        return 'Selecione o setor principal';
      if ((_guidedSectorSub ?? '').trim().isEmpty)
        return 'Selecione o sub-setor';
      if ((_guidedSectorMain == 'Outro' || _guidedSectorSub == 'Outro') &&
          (_guidedExtra ?? '').trim().isEmpty) {
        return 'Informe o complemento';
      }
    }

    if (_usesFreeFlow) return 'Informe o nome do local';

    if (_torreSelecionada == null) return 'Selecione a torre ou setor';
    if (_torreSelecionada == 'Outros' &&
        (_ambienteCustomizado == null ||
            _ambienteCustomizado!.trim().isEmpty)) {
      return 'Informe o nome do local';
    }
    if (_isResidentialTower(_torreSelecionada)) {
      if (_andarSelecionado == null) return 'Selecione o pavimento';
      if (_isRooftopFloor(_andarSelecionado) && _ambienteRooftop == null) {
        return 'Selecione a área do rooftop';
      }
      if (_localRefSelecionado == null) return 'Selecione o apartamento';
    }
    if (_torreSelecionada == 'Garagem') {
      if (_moduloSelecionado == null) return 'Selecione o módulo';
      if (_nivelSelecionado == null) return 'Selecione o nível';
    }

    return 'Preencha todos os campos obrigatórios';
  }

  // ── _getResult (original preservado) ─────────────────────────────────────
  Map<String, dynamic> _getResult() {
    final currentProjectId = _projectContext.currentProjectIdSync;
    final result = <String, dynamic>{
      'obra': _projectContext.currentProjectNameSync,
      'projectId': currentProjectId,
      'locationType': _effectiveLocationKind.name,
      'locationContext': widget.locationContext,
    };

    if (!_usesUnitFlow) {
      if (_usesGuidedStructural) {
        final tower = (_guidedTowerOrSector ?? '').trim();
        final pav = (_guidedPavement ?? '').trim();
        final element = (_guidedStructuralElement ?? '').trim();
        final extra = (_guidedExtra ?? '').trim();
        final elementLabel = element == 'Outro' && extra.isNotEmpty
            ? extra
            : element;
        final localLabel = _buildStructuralLabel();
        final ref =
            'STRUCT_${LocationGuidedCatalog.sanitizeToken(tower)}_${LocationGuidedCatalog.sanitizeToken(pav)}_${LocationGuidedCatalog.sanitizeToken(elementLabel)}';

        result['torre'] = tower;
        result['andar'] = 0;
        result['apto'] = localLabel;
        result['ambiente'] = localLabel;
        result['localLabel'] = localLabel;
        result['localRef'] = ref;
        return _withInspectionLocation(result);
      }

      if (_usesGuidedFacade) {
        final tower = (_guidedTowerOrSector ?? '').trim();
        final orientation = (_guidedFacadeOrientation ?? '').trim();
        final pav = (_guidedPavement ?? '').trim();
        final trecho = (_guidedExtra ?? '').trim();
        final localLabel = _buildFacadeLabel();
        final baseRef =
            'FACADE_${LocationGuidedCatalog.sanitizeToken(tower)}_${LocationGuidedCatalog.sanitizeToken(orientation)}_${LocationGuidedCatalog.sanitizeToken(pav)}';
        final ref = trecho.isEmpty
            ? baseRef
            : '${baseRef}_${LocationGuidedCatalog.sanitizeToken(trecho)}';

        result['torre'] = tower;
        result['andar'] = 0;
        result['apto'] = localLabel;
        result['ambiente'] = localLabel;
        result['localLabel'] = localLabel;
        result['localRef'] = ref;
        return _withInspectionLocation(result);
      }

      if (_usesGuidedSector) {
        final main = (_guidedSectorMain ?? '').trim();
        final sub = (_guidedSectorSub ?? '').trim();
        final extra = (_guidedExtra ?? '').trim();
        final mainLabel = main == 'Outro' && extra.isNotEmpty ? extra : main;
        final localLabel = _buildSectorLabel();
        final ref =
            'SECTOR_${LocationGuidedCatalog.sanitizeToken(mainLabel)}_${LocationGuidedCatalog.sanitizeToken(sub)}${(main != 'Outro' && sub == 'Outro' && extra.isNotEmpty) ? '_${LocationGuidedCatalog.sanitizeToken(extra)}' : ''}';

        result['torre'] = mainLabel;
        result['andar'] = 0;
        result['apto'] = localLabel;
        result['ambiente'] = localLabel;
        result['localLabel'] = localLabel;
        result['localRef'] = ref;
        return _withInspectionLocation(result);
      }

      final local = (_ambienteCustomizado ?? '').trim();
      result['torre'] = (_torreSelecionada ?? 'Outros');
      result['andar'] = 0;
      result['apto'] = local;
      result['ambiente'] = local;
      result['localLabel'] = local;
      result['localRef'] = FvsLocationCatalog.buildLocalRef(
        kind: _effectiveLocationKind,
        rawLabel: local,
      );
      return _withInspectionLocation(result);
    }

    if (_isResidentialTower(_torreSelecionada)) {
      result['torre'] = _torreSelecionada;
      result['andar'] = _andarSelecionado;
      if (_isRooftopFloor(_andarSelecionado)) {
        result['apto'] = 'Rooftop';
        result['ambiente'] = _ambienteRooftop;
        result['localRef'] = 'ROOFTOP';
        result['localLabel'] = _ambienteRooftop;
      } else {
        result['apto'] = _apartamentoSelecionado;
        result['localRef'] = _localRefSelecionado;
        result['localLabel'] = _apartamentoSelecionado;
      }
    } else if (_torreSelecionada == 'Garagem') {
      result['torre'] = 'Garagem';
      result['modulo'] = _moduloSelecionado;
      result['nivel'] = _nivelSelecionado;
    } else if (_torreSelecionada == 'Outros') {
      final local = (_ambienteCustomizado ?? '').trim();
      result['torre'] = 'Outros';
      result['andar'] = 0;
      result['apto'] = local;
      result['ambiente'] = local;
      result['localLabel'] = local;
      result['localRef'] = _buildOutrosLocalRef(local);
    }

    return _withInspectionLocation(result);
  }

  Map<String, dynamic> _withInspectionLocation(Map<String, dynamic> raw) {
    final location = InspectionLocation.fromLegacyMap(raw);
    raw['inspectionLocation'] = location.toMap();
    return raw;
  }

  Future<void> _goToFvsFromManualLocation() async {
    if (_isNavigatingToFvs || !_podeConfirmar) return;
    _isNavigatingToFvs = true;

    final location = _getResult();
    final fvsResult = await Navigator.push<SelectFvsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectFvsScreen(
          torre: location['torre']?.toString(),
          andar: location['andar'] is int ? location['andar'] as int : null,
          localLabel: location['localLabel']?.toString(),
          localRef: location['localRef']?.toString(),
        ),
      ),
    );

    if (!mounted) return;
    _isNavigatingToFvs = false;

    if (fvsResult == null) return;

    _isCompletingSelection = true;
    Navigator.pop(context, {
      'location': location,
      'template': fvsResult.template,
      'element': fvsResult.inspectionElement,
      'inspectionElement': fvsResult.inspectionElement,
      'locationContext': fvsResult.locationContext,
    });
  }

  Future<void> _confirmar() async {
    if (_isCompletingSelection) return;
    if (!_podeConfirmar) {
      if (_torreSelecionada == 'Outros') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informe o nome do local para continuar.'),
          ),
        );
      }
      return;
    }

    if (_torreSelecionada == 'Outros' &&
        widget.autoOpenFvsOnMap &&
        widget.template == null) {
      await _goToFvsFromManualLocation();
      return;
    }

    _isCompletingSelection = true;
    Navigator.pop(context, _getResult());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS DO RESUMO (NOVO) — indica o que já foi preenchido
  // ─────────────────────────────────────────────────────────────────────────

  /// Retorna (label, valor, isDone) para cada linha do resumo.
  List<({String label, String value, bool isDone})> get _summaryRows {
    final rows = <({String label, String value, bool isDone})>[];

    if (_usesGuidedStructural) {
      rows.add((
        label: 'Torre',
        value: (_guidedTowerOrSector ?? '').isEmpty
            ? '—'
            : _guidedTowerOrSector!,
        isDone: (_guidedTowerOrSector ?? '').trim().isNotEmpty,
      ));
      rows.add((
        label: 'Pavimento',
        value: (_guidedPavement ?? '').isEmpty ? '—' : _guidedPavement!,
        isDone: (_guidedPavement ?? '').trim().isNotEmpty,
      ));
      rows.add((
        label: 'Elemento',
        value: (_guidedStructuralElement ?? '').isEmpty
            ? '—'
            : _guidedStructuralElement!,
        isDone: (_guidedStructuralElement ?? '').trim().isNotEmpty,
      ));
      return rows;
    }

    if (_usesGuidedFacade) {
      rows.add((
        label: 'Torre',
        value: (_guidedTowerOrSector ?? '').isEmpty
            ? '—'
            : _guidedTowerOrSector!,
        isDone: (_guidedTowerOrSector ?? '').trim().isNotEmpty,
      ));
      rows.add((
        label: 'Pavimento',
        value: (_guidedPavement ?? '').isEmpty ? '—' : _guidedPavement!,
        isDone: (_guidedPavement ?? '').trim().isNotEmpty,
      ));
      rows.add((
        label: 'Orientação',
        value: (_guidedFacadeOrientation ?? '').isEmpty
            ? '—'
            : _guidedFacadeOrientation!,
        isDone: (_guidedFacadeOrientation ?? '').trim().isNotEmpty,
      ));
      return rows;
    }

    if (_usesGuidedSector) {
      rows.add((
        label: 'Setor principal',
        value: (_guidedSectorMain ?? '').isEmpty ? '—' : _guidedSectorMain!,
        isDone: (_guidedSectorMain ?? '').trim().isNotEmpty,
      ));
      rows.add((
        label: 'Sub-setor',
        value: (_guidedSectorSub ?? '').isEmpty ? '—' : _guidedSectorSub!,
        isDone: (_guidedSectorSub ?? '').trim().isNotEmpty,
      ));
      return rows;
    }

    if (_usesFreeFlow) {
      rows.add((
        label: 'Local',
        value: (_ambienteCustomizado ?? '').isEmpty
            ? '—'
            : _ambienteCustomizado!,
        isDone: (_ambienteCustomizado ?? '').trim().isNotEmpty,
      ));
      return rows;
    }

    // unit
    rows.add((
      label: 'Torre / Setor',
      value: _torreSelecionada ?? '—',
      isDone: _torreSelecionada != null,
    ));

    if (_torreSelecionada != null && _torreSelecionada != 'Outros') {
      if (_torreSelecionada == 'Garagem') {
        rows.add((
          label: 'Módulo',
          value: _moduloSelecionado ?? '—',
          isDone: _moduloSelecionado != null,
        ));
        rows.add((
          label: 'Nível',
          value: _nivelSelecionado ?? '—',
          isDone: _nivelSelecionado != null,
        ));
      } else if (_isResidentialTower(_torreSelecionada)) {
        rows.add((
          label: 'Pavimento',
          value: _andarSelecionado == null
              ? '—'
              : _isRooftopFloor(_andarSelecionado)
              ? 'Rooftop'
              : '$_andarSelecionado° andar',
          isDone: _andarSelecionado != null,
        ));
        if (_isRooftopFloor(_andarSelecionado)) {
          rows.add((
            label: 'Área',
            value: _ambienteRooftop ?? '—',
            isDone: _ambienteRooftop != null,
          ));
        } else if (_andarSelecionado != null) {
          rows.add((
            label: 'Apartamento',
            value: _apartamentoSelecionado ?? '—',
            isDone: _apartamentoSelecionado != null,
          ));
        }
      }
    } else if (_torreSelecionada == 'Outros') {
      rows.add((
        label: 'Local',
        value: (_ambienteCustomizado ?? '').isEmpty
            ? '—'
            : _ambienteCustomizado!,
        isDone: (_ambienteCustomizado ?? '').trim().isNotEmpty,
      ));
    }

    return rows;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_usesUnitFlow || _stage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _voltarEtapa();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Escolher local'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _voltarEtapa,
          ),
        ),
        body: Column(
          children: [
            // ── Contexto (FVS + tipo) ────────────────────────────────────
            _buildContextHeader(),

            // ── Stepper visual ────────────────────────────────────────────
            _buildStepperBar(),

            // ── Conteúdo scrollável ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Resumo da seleção com status
                    _buildSummaryCard(),
                    const SizedBox(height: 16),

                    // Passo atual (apenas um por vez)
                    _buildCurrentStepContent(),
                  ],
                ),
              ),
            ),

            // ── Botão fixo no rodapé ──────────────────────────────────────
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildConfirmButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTEXT HEADER (substitui _buildHeader + _buildContextBadge duplicados)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContextHeader() {
    final fvsLabel = widget.template == null
        ? 'FVS não selecionada'
        : (widget.template!.nome.trim().isNotEmpty
              ? widget.template!.nome.trim()
              : 'FVS ${widget.template!.codigo}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.appColors.cardBackground,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fvsLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _ContextBadge(label: _contextTypeLabel),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEPPER VISUAL (NOVO)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStepperBar() {
    final labels = _stepLabels;
    final total = labels.length;

    // Para unit flow, o _currentStep é derivado do _stage
    final activeStep = _usesUnitFlow ? _stage : _currentStep;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(total * 2 - 1, (i) {
          if (i.isOdd) {
            // Linha conectora
            final stepIndex = i ~/ 2;
            final isCompleted = activeStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
            );
          }

          final stepIndex = i ~/ 2;
          final isActive = stepIndex == activeStep;
          final isCompleted = stepIndex < activeStep;

          return _StepDot(
            index: stepIndex,
            label: labels[stepIndex],
            isActive: isActive,
            isCompleted: isCompleted,
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUMMARY CARD COM STATUS (NOVO)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final rows = _summaryRows;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo da seleção',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...rows.map(
              (row) => _SummaryStatusLine(
                label: row.label,
                value: row.value,
                isDone: row.isDone,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTEÚDO DO PASSO ATUAL (NOVO — substitui 3 seções fixas)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCurrentStepContent() {
    // Para guided flows não-unit, usa _currentStep
    // Para unit flow, usa _stage
    final step = _usesUnitFlow ? _stage : _currentStep;
    final labels = _stepLabels;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título do passo atual
            Text(
              '${step + 1}. ${step < labels.length ? labels[step] : ''}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),

            // Conteúdo específico do passo
            _buildStepBody(step),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody(int step) {
    // ── FREE FLOW: único passo ─────────────────────────────────────────────
    if (_usesFreeFlow) return _buildOutrosTextStep();

    // ── SECTOR ────────────────────────────────────────────────────────────
    if (_usesGuidedSector) {
      if (step == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectorMainChips(),
            const SizedBox(height: 16),
            _buildNextStepButton(
              enabled: (_guidedSectorMain ?? '').trim().isNotEmpty,
              onTap: () => setState(() => _currentStep = 1),
            ),
          ],
        );
      }
      // step 1 = sub-setor
      return _buildSectorSubStep();
    }

    // ── STRUCTURAL ────────────────────────────────────────────────────────
    if (_usesGuidedStructural) {
      if (step == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGuidedTowerChips(),
            const SizedBox(height: 16),
            _buildNextStepButton(
              enabled: (_guidedTowerOrSector ?? '').trim().isNotEmpty,
              onTap: () => setState(() => _currentStep = 1),
            ),
          ],
        );
      }
      if (step == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGuidedPavementChips(),
            const SizedBox(height: 16),
            _buildNextStepButton(
              enabled: (_guidedPavement ?? '').trim().isNotEmpty,
              onTap: () => setState(() => _currentStep = 2),
            ),
          ],
        );
      }
      // step 2 = elemento
      return _buildStructuralElementStep();
    }

    // ── FACADE ────────────────────────────────────────────────────────────
    if (_usesGuidedFacade) {
      if (step == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGuidedTowerChips(),
            const SizedBox(height: 16),
            _buildNextStepButton(
              enabled: (_guidedTowerOrSector ?? '').trim().isNotEmpty,
              onTap: () => setState(() => _currentStep = 1),
            ),
          ],
        );
      }
      if (step == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGuidedPavementChips(),
            const SizedBox(height: 16),
            _buildNextStepButton(
              enabled: (_guidedPavement ?? '').trim().isNotEmpty,
              onTap: () => setState(() => _currentStep = 2),
            ),
          ],
        );
      }
      // step 2 = orientação
      return _buildFacadeOrientationStep();
    }

    // ── UNIT FLOW ─────────────────────────────────────────────────────────
    // step 0 = torre/setor
    if (step == 0) return _buildStage0Cards();

    // step 1 = pavimento/módulo (só renderiza se torre selecionada e não "Outros")
    if (step == 1) {
      if (_torreSelecionada == null) {
        return _buildStepHint('Selecione primeiro a torre/setor principal.');
      }
      return _buildStage1Cards();
    }

    // step 2 = local específico
    if (step == 2) {
      if (_torreSelecionada == null) {
        return _buildStepHint('Selecione primeiro a torre/setor principal.');
      }
      if (_isResidentialTower(_torreSelecionada) && _andarSelecionado == null) {
        return _buildStepHint('Selecione primeiro o pavimento.');
      }
      return _buildStage2Cards();
    }

    return const SizedBox.shrink();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTÃO "PRÓXIMO PASSO" (NOVO)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNextStepButton({
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: const Icon(Icons.arrow_forward, size: 18),
      label: const Text('Próximo passo'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildStepHint(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHIPS GUIDED (extraídos de _buildSectionOneContent/_buildSectionTwoContent)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGuidedTowerChips() {
    final options = <String>[..._towerOptions, 'Garagem'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((tower) {
        return ChoiceChip(
          label: Text(tower),
          selected: _guidedTowerOrSector == tower,
          onSelected: (_) => setState(() {
            _guidedTowerOrSector = tower;
            _guidedPavement = null;
            _guidedStructuralElement = null;
            _guidedFacadeOrientation = null;
          }),
        );
      }).toList(),
    );
  }

  Widget _buildGuidedPavementChips() {
    final pavOptions = LocationGuidedCatalog.pavementsFor(
      _guidedTowerOrSector ?? '',
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: pavOptions.map((pav) {
        return ChoiceChip(
          label: Text(pav),
          selected: _guidedPavement == pav,
          onSelected: (_) => setState(() => _guidedPavement = pav),
        );
      }).toList(),
    );
  }

  Widget _buildSectorMainChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: LocationGuidedCatalog.sectorPrincipals.map((s) {
        return ChoiceChip(
          label: Text(s),
          selected: _guidedSectorMain == s,
          onSelected: (_) => setState(() {
            _guidedSectorMain = s;
            _guidedSectorSub = null;
          }),
        );
      }).toList(),
    );
  }

  Widget _buildSectorSubStep() {
    final selectedMain = _guidedSectorMain ?? '';
    final subOptions = LocationGuidedCatalog.dynamicSectorSubLocations(
      selectedMain,
    );
    final needExtra =
        selectedMain == 'Outro' || (_guidedSectorSub ?? '') == 'Outro';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: subOptions.map((sub) {
            return ChoiceChip(
              label: Text(sub),
              selected: _guidedSectorSub == sub,
              onSelected: (_) => setState(() => _guidedSectorSub = sub),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: InputDecoration(
            labelText: needExtra
                ? 'Complemento (obrigatório)'
                : 'Complemento (opcional)',
            hintText: 'Ex: módulo 2 · rampa',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _guidedExtra = v),
        ),
      ],
    );
  }

  Widget _buildStructuralElementStep() {
    final showOutro = (_guidedStructuralElement ?? '') == 'Outro';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LocationGuidedCatalog.structuralElements.map((e) {
            return ChoiceChip(
              label: Text(e),
              selected: _guidedStructuralElement == e,
              onSelected: (_) => setState(() => _guidedStructuralElement = e),
            );
          }).toList(),
        ),
        if (showOutro) ...[
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Complemento do elemento (Outro)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _guidedExtra = v),
          ),
        ],
      ],
    );
  }

  Widget _buildFacadeOrientationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LocationGuidedCatalog.facadeOrientations.map((o) {
            return ChoiceChip(
              label: Text(o),
              selected: _guidedFacadeOrientation == o,
              onSelected: (_) => setState(() => _guidedFacadeOrientation = o),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Pano/trecho (opcional)',
            hintText: 'Ex: pano 3',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _guidedExtra = v),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE CARDS (originais preservados — apenas movidos)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStage0Cards() {
    final options = [
      ..._towerOptions.map((t) => {'key': t, 'label': t}),
      {'key': 'Garagem', 'label': 'Garagem'},
      {'key': 'Outros', 'label': 'Outros'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((opt) {
        final isSelected = _torreSelecionada == opt['key'];
        final optionKey = opt['key'] as String;
        return _SelectCard(
          label: opt['label'] as String,
          selected: isSelected,
          onTap: () {
            setState(() {
              _torreSelecionada = optionKey;
              _apartamentoSelecionado = null;
              _localRefSelecionado = null;
              _moduloSelecionado = null;
              _nivelSelecionado = null;
              _ambienteRooftop = null;
              _ambienteCustomizado = null;
              _outrosController.clear();
              _andarSelecionado = null;
              _stage = optionKey == 'Outros' ? 2 : 1;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildStage1Cards() {
    if (_torreSelecionada == 'Garagem') {
      final modules = LocationGuidedCatalog.garageModules;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: modules.map((mod) {
          final isSelected = _moduloSelecionado == mod;
          return _SelectCard(
            label: mod,
            selected: isSelected,
            onTap: () {
              setState(() {
                _moduloSelecionado = mod;
                _stage = 2;
              });
            },
          );
        }).toList(),
      );
    }

    final floorLabels = ObraStructure.andares();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: List.generate(floorLabels.length, (index) {
        final label = floorLabels[index];
        final digits = label.replaceAll(RegExp(r'[^0-9]'), '');
        final parsed = int.tryParse(digits);
        final floor = parsed ?? _rooftopFloorMarker;
        final isSelected = _andarSelecionado == floor;
        return _SelectCard(
          label: label,
          selected: isSelected,
          onTap: () {
            setState(() {
              _andarSelecionado = floor;
              _stage = 2;
            });
          },
        );
      }),
    );
  }

  Widget _buildStage2Cards() {
    if (_torreSelecionada == 'Garagem') {
      final levels = LocationGuidedCatalog.garageLevels;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: levels.map((level) {
          final isSelected = _nivelSelecionado == level;
          return _SelectCard(
            label: level,
            selected: isSelected,
            onTap: () => setState(() => _nivelSelecionado = level),
          );
        }).toList(),
      );
    }

    if (_torreSelecionada == 'Outros') return _buildOutrosTextStep();

    if (_isRooftopFloor(_andarSelecionado)) {
      final ambientes = ObraStructure.specialAreasForTower(
        _torreSelecionada ?? '',
      ).map((area) => area.label).toList(growable: false);

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: ambientes.map((amb) {
          final isSelected = _ambienteRooftop == amb;
          return _SelectCard(
            label: amb,
            selected: isSelected,
            onTap: () => setState(() => _ambienteRooftop = amb),
          );
        }).toList(),
      );
    }

    return ValueListenableBuilder<Box<InspectionRecord>>(
      valueListenable: Hive.box<InspectionRecord>('inspections').listenable(),
      builder: (context, box, child) {
        final activeProjectId = _projectContext.currentProjectIdSync;
        final scopedRecords = filterRecordsByProjectScope(
          box.values,
          currentProjectId: activeProjectId,
          projectId: (r) => r.projectId,
          obra: (r) => r.obra,
        ).toList(growable: false);
        final statusByLocalRef = _buildLocalStatusMap(scopedRecords);
        return _ApartmentMapSelector(
          torre: _torreSelecionada ?? '',
          andar: _andarSelecionado,
          selectedLocalRef: _localRefSelecionado,
          onSelect: _onSelectMapLocal,
          statusByLocalRef: statusByLocalRef,
        );
      },
    );
  }

  Map<String, _LocalStatusVisual> _buildLocalStatusMap(
    List<InspectionRecord> allRecords,
  ) {
    final appColors = context.appColors;
    final activeProjectId = _projectContext.currentProjectIdSync;
    final torre = _torreSelecionada;
    final andar = _andarSelecionado;
    if (torre == null || andar == null) return const {};

    final filtered = allRecords.where(
      (r) =>
          r.torre == torre &&
          r.andar == andar &&
          matchesActiveProject(
            activeProjectId: activeProjectId,
            recordProjectId: r.projectId,
            recordObra: r.obra,
          ),
    );

    final grouped = <String, List<InspectionRecord>>{};
    for (final record in filtered) {
      final localRef = record.localRef?.trim();
      if (localRef == null || localRef.isEmpty) continue;
      grouped.putIfAbsent(localRef, () => <InspectionRecord>[]).add(record);
    }

    final out = <String, _LocalStatusVisual>{};
    for (final entry in grouped.entries) {
      final records = entry.value
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final ncOpen = records.fold<int>(
        0,
        (acc, r) => acc + r.itens.where((item) => item.status == 'nok').length,
      );
      if (ncOpen > 0) {
        out[entry.key] = _LocalStatusVisual.ncOpen(ncOpen, appColors);
        continue;
      }
      final latest = records.first;
      if (latest.isDraft) {
        out[entry.key] = _LocalStatusVisual.draft(appColors);
      } else if (latest.isFinalState) {
        out[entry.key] = _LocalStatusVisual.finalized(appColors);
      } else {
        out[entry.key] = _LocalStatusVisual.none(appColors);
      }
    }
    return out;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTÃO CONFIRMAR COM LEGENDA DE BLOQUEIO (ATUALIZADO)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildConfirmButton() {
    final bloqueio = _bloqueioConfirmar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: _podeConfirmar ? () async => await _confirmar() : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Confirmar local', style: TextStyle(fontSize: 16)),
        ),
        if (bloqueio != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Falta: $bloqueio',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEXT STEP (original preservado)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOutrosTextStep() {
    return ValueListenableBuilder<Box<InspectionRecord>>(
      valueListenable: Hive.box<InspectionRecord>('inspections').listenable(),
      builder: (context, value, child) {
        final allSuggestions = _historicalOutrosSuggestions();
        final filteredSuggestions = _filterOutrosSuggestions(
          allSuggestions,
          _outrosController.text,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _outrosController,
              decoration: InputDecoration(
                labelText: _manualLocationLabel,
                hintText: _manualLocationHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onChanged: (value) =>
                  setState(() => _ambienteCustomizado = value),
              onSubmitted: (_) async => await _confirmar(),
            ),
            const SizedBox(height: 10),
            if (filteredSuggestions.isNotEmpty) ...[
              const Text(
                'Sugestões já usadas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filteredSuggestions.take(8).map((suggestion) {
                  return ActionChip(
                    label: Text(suggestion),
                    onPressed: () {
                      setState(() {
                        _outrosController.text = suggestion;
                        _outrosController.selection = TextSelection.collapsed(
                          offset: suggestion.length,
                        );
                        _ambienteCustomizado = suggestion;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOVOS WIDGETS DE UI
// ─────────────────────────────────────────────────────────────────────────────

/// Badge colorido de contexto (compacto, canto superior direito do header)
class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Bolinha do stepper com número + label abaixo
class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final int index;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dotColor = isCompleted || isActive
        ? scheme.primary
        : scheme.outlineVariant;
    final textColor = isCompleted || isActive
        ? scheme.primary
        : scheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted
                ? scheme.primary
                : isActive
                ? scheme.primaryContainer
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: isActive ? 2 : 1.5),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// Linha do resumo com ícone de status (pendente / concluído)
class _SummaryStatusLine extends StatelessWidget {
  const _SummaryStatusLine({
    required this.label,
    required this.value,
    required this.isDone,
  });

  final String label;
  final String value;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = isDone ? Colors.green.shade600 : scheme.outlineVariant;
    final valueColor = isDone ? scheme.onSurface : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
                color: valueColor,
                fontStyle: isDone ? FontStyle.normal : FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS ORIGINAIS PRESERVADOS (sem alteração)
// ─────────────────────────────────────────────────────────────────────────────

class _SelectCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: theme.cardColor,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _ApartmentMapSelector extends StatelessWidget {
  const _ApartmentMapSelector({
    required this.torre,
    required this.andar,
    required this.selectedLocalRef,
    required this.onSelect,
    required this.statusByLocalRef,
  });

  final String torre;
  final int? andar;
  final String? selectedLocalRef;
  final ValueChanged<_LocalSelection> onSelect;
  final Map<String, _LocalStatusVisual> statusByLocalRef;

  int _normalizeFloor(dynamic value) {
    if (value is int && value > 0) return value;
    final raw = value?.toString() ?? '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(digits);
    if (parsed != null && parsed > 0) return parsed;
    return 1;
  }

  List<String> get _orderedAptos {
    final floor = _normalizeFloor(andar);
    final configured = ObraStructure.apartamentosDoAndar(floor);
    if (configured.isNotEmpty) return configured;
    final base = floor * 100;
    return <String>['${base + 1}', '${base + 2}', '${base + 3}', '${base + 4}'];
  }

  _LocalSelection _apto(String apto) =>
      _LocalSelection(ref: 'APTO_$apto', label: apto);

  @override
  Widget build(BuildContext context) {
    final aptos = _orderedAptos;
    final crossAxisCount = aptos.length <= 4
        ? 2
        : aptos.length <= 6
        ? 3
        : 4;

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
          ),
          itemCount: aptos.length,
          itemBuilder: (context, index) {
            final apto = aptos[index];
            final ref = 'APTO_$apto';
            return _ApartmentCard(
              apto: apto,
              selected: selectedLocalRef == ref,
              status:
                  statusByLocalRef[ref] ??
                  _LocalStatusVisual.none(context.appColors),
              onTap: () => onSelect(_apto(apto)),
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              <_LocalSelection>[
                    const _LocalSelection(ref: 'HALL', label: 'Hall'),
                    const _LocalSelection(ref: 'ESCADA', label: 'Escada'),
                    const _LocalSelection(ref: 'ELEVADOR', label: 'Elevador'),
                    const _LocalSelection(ref: 'LAJE', label: 'Laje'),
                  ]
                  .map((option) {
                    return _LocalChip(
                      option: option,
                      selected: selectedLocalRef == option.ref,
                      status:
                          statusByLocalRef[option.ref] ??
                          _LocalStatusVisual.none(context.appColors),
                      icon: option.ref == 'LAJE'
                          ? Icons.layers_outlined
                          : option.ref == 'ELEVADOR'
                          ? Icons.elevator
                          : option.ref == 'ESCADA'
                          ? Icons.directions_walk
                          : Icons.home_work_outlined,
                      onTap: onSelect,
                      compact: true,
                    );
                  })
                  .toList(growable: false),
        ),
      ],
    );
  }
}

class _LocalSelection {
  final String ref;
  final String label;
  const _LocalSelection({required this.ref, required this.label});
}

class _LocalChip extends StatelessWidget {
  const _LocalChip({
    required this.option,
    required this.selected,
    required this.status,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  final _LocalSelection option;
  final bool selected;
  final _LocalStatusVisual status;
  final IconData icon;
  final ValueChanged<_LocalSelection> onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final bg = selected
        ? Color.alphaBlend(
            status.color.withValues(alpha: 0.22),
            status.lightColor,
          )
        : status.lightColor;
    final border = selected
        ? status.color
        : status.color.withValues(alpha: 0.72);
    final fg = selected ? appColors.textPrimary : appColors.textSecondary;

    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: selected ? 2 : 1),
      ),
      child: Stack(
        children: [
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 16 : 18, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    option.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (status.ncCount > 0)
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: appColors.danger,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${status.ncCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.check_circle,
                color: appColors.selected,
                size: 16,
              ),
            ),
        ],
      ),
    );

    return Tooltip(
      message: 'Selecionar ${option.label}',
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Selecionar ${option.label}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(option),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ApartmentCard extends StatelessWidget {
  const _ApartmentCard({
    required this.apto,
    required this.selected,
    required this.status,
    required this.onTap,
  });

  final String apto;
  final bool selected;
  final _LocalStatusVisual status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final color = selected
        ? Color.alphaBlend(
            status.color.withValues(alpha: 0.20),
            status.lightColor,
          )
        : status.lightColor;
    final borderColor = selected
        ? status.color
        : status.color.withValues(alpha: 0.65);

    return Tooltip(
      message: 'Selecionar apartamento $apto',
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Selecionar apartamento $apto',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 2 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apto,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: selected
                                ? appColors.textPrimary
                                : appColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: status.color,
                          ),
                        ),
                        if (status.ncCount > 0)
                          Text(
                            '${status.ncCount} NC aberta${status.ncCount > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: appColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.check_circle,
                        color: appColors.selected,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalStatusVisual {
  final String label;
  final Color color;
  final Color lightColor;
  final int ncCount;

  const _LocalStatusVisual({
    required this.label,
    required this.color,
    required this.lightColor,
    this.ncCount = 0,
  });

  factory _LocalStatusVisual.none(AppColors colors) => _LocalStatusVisual(
    label: 'Sem vistoria',
    color: colors.cardBackgroundText,
    lightColor: colors.cardBackground,
  );

  factory _LocalStatusVisual.draft(AppColors colors) => _LocalStatusVisual(
    label: 'Rascunho',
    color: colors.cardNCAbertaText,
    lightColor: colors.cardNCAberta,
  );

  factory _LocalStatusVisual.finalized(AppColors colors) => _LocalStatusVisual(
    label: 'Finalizado',
    color: colors.cardSemNCText,
    lightColor: colors.cardSemNC,
  );

  factory _LocalStatusVisual.ncOpen(int count, AppColors colors) =>
      _LocalStatusVisual(
        label: 'NC aberta',
        color: colors.danger,
        lightColor: colors.cardNCAberta,
        ncCount: count,
      );
}
