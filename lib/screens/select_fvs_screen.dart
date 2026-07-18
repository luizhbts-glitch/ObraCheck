import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/fvs_catalog.dart';
import '../data/fvs_location_catalog.dart';
import '../data/inspection_element_catalog.dart';
import '../models/project_settings_record.dart';
import '../services/project_settings_service.dart';
import '../theme/app_colors.dart';
import '../utils/fvs_icon_formatter.dart';

class SelectFvsResult {
  const SelectFvsResult({
    required this.template,
    required this.inspectionElement,
    this.locationContext = '',
    this.operationalSheetId,
    this.operationalSheetLabel,
  });

  final FvsTemplate template;
  final String inspectionElement;
  final String locationContext;
  final String? operationalSheetId;
  final String? operationalSheetLabel;
}

class SelectFvsScreen extends StatefulWidget {
  const SelectFvsScreen({
    super.key,
    this.torre,
    this.andar,
    this.localLabel,
    this.localRef,
    this.hideFinalizedHint = false,
  });

  final String? torre;
  final int? andar;
  final String? localLabel;
  final String? localRef;
  final bool hideFinalizedHint;

  @override
  State<SelectFvsScreen> createState() => _SelectFvsScreenState();
}

class _SelectFvsScreenState extends State<SelectFvsScreen> {
  int? _selectedIndex;
  String _selectedElement = '';
  String _selectedLocationContext = '';
  String _selectedOperationalSheetId = '';

  final _searchController = TextEditingController();
  String _searchQuery = '';

  final ProjectSettingsService _projectSettingsService = ProjectSettingsService.instance;

  String get _subtitleLocal {
    final parts = <String>[];
    final torre = widget.torre?.trim();
    if (torre != null && torre.isNotEmpty) parts.add(torre);

    final andar = widget.andar;
    if (andar != null) {
      parts.add(andar == 17 ? 'Rooftop' : '$andarº andar');
    }

    final local = widget.localLabel?.trim();
    if (local != null && local.isNotEmpty) parts.add(local);

    return parts.join(' • ');
  }

  @override
  void initState() {
    super.initState();
    _loadLastSelection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLastSelection() async {
    try {
      final prefs = Hive.box('prefs');
      final lastCod = prefs.get('last_fvs_codigo') as String?;

      if (!mounted) return;
      if (lastCod == null) return;

      final all = FvsCatalog.all;
      final filtered = all.toList()..sort((a, b) => a.codigo.compareTo(b.codigo));

      final idx = filtered.indexWhere((e) => e.codigo == lastCod);
      if (!mounted) return;

      if (idx >= 0) {
        setState(() {
          _selectedIndex = idx;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  List<FvsTemplate> get _filteredTemplates {
    final all = FvsCatalog.all;
    if (_searchQuery.trim().isEmpty) {
      return all.toList()..sort((a, b) => a.codigo.compareTo(b.codigo));
    }
    final query = _searchQuery.toLowerCase().trim();
    return all.where((template) {
      final nomeMatch = template.nome.toLowerCase().contains(query);
      final profissaoMatch = template.profissao.toLowerCase().contains(query);
      final codigoMatch = template.codigo.toLowerCase().contains(query);
      return nomeMatch || profissaoMatch || codigoMatch;
    }).toList()..sort((a, b) => a.codigo.compareTo(b.codigo));
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final filtered = _filteredTemplates;

    final selectedTemplate = (_selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < filtered.length)
        ? filtered[_selectedIndex!]
        : null;
    final requiresElement = selectedTemplate != null &&
        InspectionElementCatalog.requiresElement(selectedTemplate);
    final elementOptions =
        selectedTemplate == null ? const <String>[] : InspectionElementCatalog.elementsFor(selectedTemplate);
    final locationProfile =
        selectedTemplate == null ? null : FvsLocationCatalog.profileForTemplate(selectedTemplate);
    final requiresLocationContext = locationProfile?.hasVariableContext == true;
    final locationContextOptions = locationProfile?.contexts ?? const <FvsLocationContextOption>[];
    final operationalSheets = selectedTemplate == null
        ? const <FvsOperationalSheetConfig>[]
        : _projectSettingsService.activeOperationalSheetsForFvsSync(selectedTemplate.codigo);
    final requiresOperationalSheet = operationalSheets.length > 1;
    final selectedOperationalSheet = operationalSheets.where((e) => e.id == _selectedOperationalSheetId).firstOrNull;
    final defaultOperationalSheet = operationalSheets.length == 1 ? operationalSheets.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecionar FVS'),
            if (_subtitleLocal.isNotEmpty) ...[
              const SizedBox(height: 2),
                Text(
                  _subtitleLocal,
                  style: TextStyle(fontSize: 12, color: appColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar FVS',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                const Text(
                  'Selecione a FVS',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                if (filtered.isEmpty)
                  _buildEmptyState(_searchQuery.isNotEmpty ? 'Nenhuma FVS encontrada.' : 'Nenhuma FVS cadastrada.')
                else
                  ...List.generate(filtered.length, (i) {
                    final template = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FvsListItem(
                        template: template,
                        selected: _selectedIndex == i,
                        onTap: () {
                          setState(() {
                            if (_selectedIndex == i) {
                              _selectedIndex = null;
                              _selectedElement = '';
                            } else {
                              _selectedIndex = i;
                              final templateElements = InspectionElementCatalog.elementsFor(template);
                              final templateLocation = FvsLocationCatalog.profileForTemplate(template);
                              if (!InspectionElementCatalog.requiresElement(template)) {
                                _selectedElement = '';
                              } else if (!templateElements.contains(_selectedElement)) {
                                _selectedElement = templateElements.isNotEmpty ? templateElements.first : '';
                              }
                              _selectedLocationContext = templateLocation.defaultContextId;
                              final sheets = _projectSettingsService.activeOperationalSheetsForFvsSync(template.codigo);
                              _selectedOperationalSheetId = sheets.length == 1 ? sheets.first.id : '';
                            }
                          });
                        },
                      ),
                    );
                  }),
                if (selectedTemplate != null && operationalSheets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (operationalSheets.length == 1)
                    _buildInfoCard(
                      'Folha operacional: ${operationalSheets.first.label}',
                      'Escopo operacional aplicado automaticamente nesta FVS.',
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedOperationalSheetId.trim().isEmpty ? null : _selectedOperationalSheetId,
                      decoration: const InputDecoration(
                        labelText: 'Folha operacional',
                        helperText: 'Selecione o escopo operacional desta FVS.',
                        border: OutlineInputBorder(),
                      ),
                      items: operationalSheets
                          .map(
                            (sheet) => DropdownMenuItem<String>(
                              value: sheet.id,
                              child: Text(sheet.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        setState(() {
                          _selectedOperationalSheetId = (value ?? '').trim();
                        });
                      },
                    ),
                ],
                if (selectedTemplate != null && requiresLocationContext) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLocationContext.trim().isEmpty ? null : _selectedLocationContext,
                    decoration: const InputDecoration(
                      labelText: 'Contexto do local',
                      helperText: 'Define o fluxo de localização desta FVS.',
                      border: OutlineInputBorder(),
                    ),
                    items: locationContextOptions
                        .map(
                          (ctx) => DropdownMenuItem<String>(
                            value: ctx.id,
                            child: Text(ctx.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLocationContext = (value ?? '').trim();
                      });
                    },
                  ),
                ],
                if (selectedTemplate != null && requiresElement) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedElement.trim().isEmpty ? null : _selectedElement,
                    decoration: const InputDecoration(
                      labelText: 'Elemento da inspeção',
                      helperText: 'Selecione antes de abrir a FVS.',
                      border: OutlineInputBorder(),
                    ),
                    items: elementOptions
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedElement = (value ?? '').trim();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: selectedTemplate == null
                  ? null
                  : (requiresLocationContext && _selectedLocationContext.trim().isEmpty)
                  ? null
                  : (requiresElement && _selectedElement.trim().isEmpty)
                  ? null
                  : (requiresOperationalSheet && _selectedOperationalSheetId.trim().isEmpty)
                  ? null
                  : () async {
                      final prefs = Hive.box('prefs');
                      await prefs.put('last_profissao', selectedTemplate.profissao);
                      await prefs.put('last_fvs_codigo', selectedTemplate.codigo);
                      final resolvedSheet = selectedOperationalSheet ?? defaultOperationalSheet;
                      if (!context.mounted) return;
                      Navigator.pop(
                        context,
                        SelectFvsResult(
                          template: selectedTemplate,
                          inspectionElement: _selectedElement.trim(),
                          locationContext: _selectedLocationContext.trim(),
                          operationalSheetId: resolvedSheet?.id,
                          operationalSheetLabel: resolvedSheet?.label,
                        ),
                      );
                    },
              child: const Text('Confirmar FVS'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appColors.border),
        color: Theme.of(context).cardColor,
      ),
      child: Text(
        text,
        style: TextStyle(color: appColors.textSecondary),
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle) {
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColors.border),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: appColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: appColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

}

class _FvsListItem extends StatelessWidget {
  const _FvsListItem({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final FvsTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? appColors.selected : scheme.outlineVariant,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          '${FvsIconFormatter.getFvsIcon(template.nome)} '
          '${template.nome.trim().isNotEmpty ? template.nome : 'FVS ${template.codigo}'}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Profissão: ${template.profissao}'),
          ],
        ),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? appColors.selected : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
