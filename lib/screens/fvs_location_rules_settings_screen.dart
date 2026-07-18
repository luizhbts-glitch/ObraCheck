import 'package:flutter/material.dart';

import '../data/fvs_catalog.dart';
import '../data/fvs_location_catalog.dart';
import '../services/project_context_service.dart';
import '../services/project_settings_service.dart';
import '../theme/app_colors.dart';

class FvsLocationRulesSettingsScreen extends StatefulWidget {
  const FvsLocationRulesSettingsScreen({super.key});

  @override
  State<FvsLocationRulesSettingsScreen> createState() =>
      _FvsLocationRulesSettingsScreenState();
}

class _FvsLocationRulesSettingsScreenState
    extends State<FvsLocationRulesSettingsScreen> {
  final ProjectSettingsService _settingsService =
      ProjectSettingsService.instance;
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic> _overrides = <String, dynamic>{};
  String _searchQuery = '';
  bool _hasChanges = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final record = _settingsService.currentProjectSettingsSync;
    if (record != null) {
      _overrides = Map<String, dynamic>.from(record.fvsContextOverrides);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveAndPop() async {
    if (_saving) return;
    _saving = true;
    if (_hasChanges) {
      final current = _settingsService.currentProjectSettingsSync;
      final projectId = (current?.projectId.trim().isNotEmpty == true)
          ? current!.projectId.trim()
          : ProjectContextService.instance.currentProjectIdSync.trim();
      if (projectId.isNotEmpty) {
        final base =
            current ??
            _settingsService.buildLegacyDefault(projectId: projectId);
        await _settingsService.saveForCurrentProject(
          base.copyWith(
            projectId: projectId,
            fvsContextOverrides: Map<String, dynamic>.from(_overrides),
          ),
        );
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _setDraft(String fvsCode, _RuleDraft draft) {
    setState(() {
      _overrides[fvsCode] = draft.toStoredValue();
      _hasChanges = true;
    });
  }

  void _resetDraft(String fvsCode) {
    setState(() {
      _overrides.remove(fvsCode);
      _hasChanges = true;
    });
  }

  _RuleDraft _draftFor(FvsTemplate template) {
    final code = template.codigo.trim();
    final raw = _overrides[code];
    if (raw != null) return _RuleDraft.fromStoredValue(raw);
    return _RuleDraft.fromProfile(FvsLocationCatalog.profileForCode(code));
  }

  bool _hasOverride(FvsTemplate template) {
    return _overrides.containsKey(template.codigo.trim());
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final filtered = FvsCatalog.all
        .where((template) {
          if (_searchQuery.trim().isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          return template.codigo.toLowerCase().contains(query) ||
              template.nome.toLowerCase().contains(query) ||
              template.profissao.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regras de local por FVS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async => _saveAndPop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () async => _saveAndPop(),
              child: const Text('Concluido'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: appColors.surfaceAlt.withValues(alpha: 0.5),
            child: Row(
              children: [
                Icon(Icons.route_outlined, color: appColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Marque um ou mais tipos de local para cada FVS. Quando houver mais de um, o app pede a escolha antes da inspecao.',
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar FVS por codigo, nome ou profissao...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final template = filtered[index];
                return _FvsLocationRuleCard(
                  template: template,
                  draft: _draftFor(template),
                  hasOverride: _hasOverride(template),
                  onChanged: (draft) =>
                      _setDraft(template.codigo.trim(), draft),
                  onReset: () => _resetDraft(template.codigo.trim()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FvsLocationRuleCard extends StatefulWidget {
  const _FvsLocationRuleCard({
    required this.template,
    required this.draft,
    required this.hasOverride,
    required this.onChanged,
    required this.onReset,
  });

  final FvsTemplate template;
  final _RuleDraft draft;
  final bool hasOverride;
  final void Function(_RuleDraft draft) onChanged;
  final VoidCallback onReset;

  @override
  State<_FvsLocationRuleCard> createState() => _FvsLocationRuleCardState();
}

class _FvsLocationRuleCardState extends State<_FvsLocationRuleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final selectedLabels = widget.draft.selectedKinds
        .map((kind) => _KindOption.byId(kind).shortLabel)
        .join(' + ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FVS ${widget.template.codigo}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.template.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: appColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedLabels,
                          style: TextStyle(
                            color: appColors.selected,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.hasOverride)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _StatusPill(text: 'Personalizada'),
                    ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: appColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  ..._KindOption.all.map((option) {
                    final selected = widget.draft.selectedKinds.contains(
                      option.id,
                    );
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: selected,
                      title: Text(option.label),
                      subtitle: Text(option.description),
                      onChanged: (checked) {
                        final next = widget.draft.copy();
                        if (checked == true) {
                          next.selectedKinds.add(option.id);
                          next.defaultKind = option.id;
                        } else if (next.selectedKinds.length > 1) {
                          next.selectedKinds.remove(option.id);
                          if (next.defaultKind == option.id) {
                            next.defaultKind = next.selectedKinds.first;
                          }
                        }
                        widget.onChanged(next);
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: widget.draft.defaultKind,
                    decoration: const InputDecoration(
                      labelText: 'Tipo padrao',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.draft.selectedKinds
                        .map(
                          (kind) => DropdownMenuItem<String>(
                            value: kind,
                            child: Text(_KindOption.byId(kind).label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      final next = widget.draft.copy()..defaultKind = value;
                      widget.onChanged(next);
                    },
                  ),
                  if (widget.hasOverride) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: widget.onReset,
                        icon: const Icon(Icons.restart_alt_outlined),
                        label: const Text('Voltar ao catalogo'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: appColors.selected.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: appColors.selected,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _RuleDraft {
  _RuleDraft({required this.selectedKinds, required this.defaultKind});

  final Set<String> selectedKinds;
  String defaultKind;

  _RuleDraft copy() {
    return _RuleDraft(
      selectedKinds: Set<String>.from(selectedKinds),
      defaultKind: defaultKind,
    );
  }

  dynamic toStoredValue() {
    if (selectedKinds.length == 1) return selectedKinds.first;
    final normalizedDefault = selectedKinds.contains(defaultKind)
        ? defaultKind
        : selectedKinds.first;
    return <String, dynamic>{
      'defaultKind': normalizedDefault,
      'contexts': selectedKinds
          .map((kind) {
            final option = _KindOption.byId(kind);
            return <String, dynamic>{
              'id': option.id,
              'label': option.label,
              'kind': option.id,
            };
          })
          .toList(growable: false),
    };
  }

  factory _RuleDraft.fromStoredValue(dynamic raw) {
    if (raw is String) {
      final kind = _KindOption.normalize(raw);
      return _RuleDraft(selectedKinds: <String>{kind}, defaultKind: kind);
    }
    if (raw is Map) {
      final kinds = <String>{};
      final contexts = raw['contexts'];
      if (contexts is List) {
        for (final item in contexts) {
          if (item is! Map) continue;
          kinds.add(_KindOption.normalize((item['kind'] ?? '').toString()));
        }
      }
      final defaultKind = _KindOption.normalize(
        (raw['defaultKind'] ?? raw['kind'] ?? '').toString(),
      );
      if (kinds.isEmpty) kinds.add(defaultKind);
      return _RuleDraft(
        selectedKinds: kinds,
        defaultKind: kinds.contains(defaultKind) ? defaultKind : kinds.first,
      );
    }
    return _RuleDraft(
      selectedKinds: const <String>{'unit'},
      defaultKind: 'unit',
    );
  }

  factory _RuleDraft.fromProfile(FvsLocationProfile profile) {
    final kinds = profile.contexts.isEmpty
        ? <String>{profile.defaultKind.name}
        : profile.contexts.map((ctx) => ctx.kind.name).toSet();
    return _RuleDraft(
      selectedKinds: kinds,
      defaultKind: kinds.contains(profile.defaultKind.name)
          ? profile.defaultKind.name
          : kinds.first,
    );
  }
}

class _KindOption {
  const _KindOption({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.description,
  });

  final String id;
  final String label;
  final String shortLabel;
  final String description;

  static const all = <_KindOption>[
    _KindOption(
      id: 'unit',
      label: 'Unidade / apartamento',
      shortLabel: 'Unidade',
      description: 'Usa torre, pavimento e apartamento.',
    ),
    _KindOption(
      id: 'structural',
      label: 'Estrutural',
      shortLabel: 'Estrutural',
      description: 'Usa torre, pavimento e elemento estrutural.',
    ),
    _KindOption(
      id: 'facade',
      label: 'Fachada',
      shortLabel: 'Fachada',
      description: 'Usa torre, pavimento e orientacao de fachada.',
    ),
    _KindOption(
      id: 'sector',
      label: 'Setor / area comum',
      shortLabel: 'Setor',
      description: 'Usa setor principal e sublocal.',
    ),
    _KindOption(
      id: 'free',
      label: 'Livre',
      shortLabel: 'Livre',
      description: 'Permite informar um local solto.',
    ),
  ];

  static _KindOption byId(String id) {
    final normalized = normalize(id);
    for (final option in all) {
      if (option.id == normalized) return option;
    }
    return all.first;
  }

  static String normalize(String raw) {
    final value = raw.trim().toLowerCase();
    for (final option in all) {
      if (option.id == value) return option.id;
    }
    return 'unit';
  }
}
