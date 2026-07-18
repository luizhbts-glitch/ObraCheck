import 'package:flutter/material.dart';

import '../data/fvs_catalog.dart';
import '../data/fvs_data.dart';
import '../services/project_context_service.dart';
import '../services/project_settings_service.dart';
import '../theme/app_colors.dart';

class PhotoRequirementSettingsScreen extends StatefulWidget {
  const PhotoRequirementSettingsScreen({super.key});

  @override
  State<PhotoRequirementSettingsScreen> createState() =>
      _PhotoRequirementSettingsScreenState();
}

class _PhotoRequirementSettingsScreenState
    extends State<PhotoRequirementSettingsScreen> {
  final ProjectSettingsService _settingsService =
      ProjectSettingsService.instance;

  Map<String, Map<int, bool>> _overrides = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _hasChanges = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadOverrides();
  }

  void _loadOverrides() {
    final record = _settingsService.currentProjectSettingsSync;
    if (record != null) {
      _overrides = _cloneOverrides(record.fvsProofPhotoOverrides);
    }
  }

  Map<String, Map<int, bool>> _cloneOverrides(
    Map<String, Map<int, bool>> source,
  ) {
    return source.map(
      (fvsCode, items) => MapEntry(fvsCode, Map<int, bool>.from(items)),
    );
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
        final updated = base.copyWith(
          projectId: projectId,
          fvsProofPhotoOverrides: _cloneOverrides(_overrides),
        );
        await _settingsService.saveForCurrentProject(updated);
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _onToggle(String fvsCode, int itemIndex, bool value) {
    setState(() {
      _overrides[fvsCode] ??= {};
      _overrides[fvsCode]![itemIndex] = value;
      _hasChanges = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final fvsList = FvsCatalog.all;

    final fvsData = <_FvsWithItems>[];
    for (final template in fvsList) {
      final code = template.codigo.trim();
      if (code.isEmpty) continue;

      final items = <_ItemWithProof>[];
      for (var i = 0; i < template.itens.length; i++) {
        final item = template.itens[i];
        final proof = FvsProofCatalog.resolveForProject(
          fvsCode: code,
          itemIndex: i,
          fallback: item.proof,
        );
        items.add(
          _ItemWithProof(
            index: i,
            item: item,
            baseRequiresPhoto: proof.requiresPhoto,
          ),
        );
      }

      fvsData.add(_FvsWithItems(code: code, template: template, items: items));
    }

    final filteredFvs = fvsData.where((f) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return f.code.toLowerCase().contains(query) ||
          f.template.nome.toLowerCase().contains(query) ||
          f.template.profissao.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprovação por foto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async => await _saveAndPop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () async => await _saveAndPop(),
              child: const Text('Concluído'),
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
                Icon(
                  Icons.info_outline,
                  color: appColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ao marcar "Obrigar foto" em um item, a inspeção exigirá comprovação fotográfica.',
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
                hintText: 'Buscar FVS por código, nome ou profissão...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          if (filteredFvs.isEmpty)
            const Expanded(
              child: Center(child: Text('Nenhuma FVS encontrada.')),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: filteredFvs.length,
                itemBuilder: (context, index) {
                  final fvs = filteredFvs[index];
                  return _FvsCard(
                    fvs: fvs,
                    overrides: _overrides,
                    onToggle: _onToggle,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FvsCard extends StatefulWidget {
  const _FvsCard({
    required this.fvs,
    required this.overrides,
    required this.onToggle,
  });

  final _FvsWithItems fvs;
  final Map<String, Map<int, bool>> overrides;
  final void Function(String fvsCode, int itemIndex, bool value) onToggle;

  @override
  State<_FvsCard> createState() => _FvsCardState();
}

class _FvsCardState extends State<_FvsCard> {
  bool _isExpanded = false;

  int _getConfiguredCount() {
    final items = widget.overrides[widget.fvs.code];
    if (items == null) return 0;
    return items.values.where((v) => v == true).length;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final configuredCount = _getConfiguredCount();
    final hasConfig = configuredCount > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FVS ${widget.fvs.code}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.fvs.template.nome,
                          style: TextStyle(
                            color: appColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (hasConfig)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: appColors.selected.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$configuredCount itens',
                        style: TextStyle(
                          color: appColors.selected,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: appColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              color: appColors.surfaceAlt.withValues(alpha: 0.3),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: widget.fvs.items.map((item) {
                  final savedOverride =
                      widget.overrides[widget.fvs.code]?[item.index];
                  final currentValue = savedOverride ?? item.baseRequiresPhoto;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.index + 1}. ${item.item.descricao}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (savedOverride != null)
                                Text(
                                  savedOverride ? 'Obrigatório' : 'Opcional',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: appColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Switch(
                          value: currentValue,
                          onChanged: (value) {
                            widget.onToggle(widget.fvs.code, item.index, value);
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _FvsWithItems {
  _FvsWithItems({
    required this.code,
    required this.template,
    required this.items,
  });

  final String code;
  final FvsTemplate template;
  final List<_ItemWithProof> items;
}

class _ItemWithProof {
  _ItemWithProof({
    required this.index,
    required this.item,
    required this.baseRequiresPhoto,
  });

  final int index;
  final FvsItem item;
  final bool baseRequiresPhoto;
}
