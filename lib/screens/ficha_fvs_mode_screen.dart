import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/arsen_structure.dart';
import '../data/fvs_catalog.dart';
import '../models/inspection_record.dart';
import '../services/auth_service.dart';
import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../utils/project_scope.dart';
import 'inspection_screen.dart';
import 'select_fvs_screen.dart';
import 'select_location_screen.dart';

class FichaFvsModeScreen extends StatelessWidget {
  const FichaFvsModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ficha F.V.S.')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Como deseja iniciar?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _ModeCard(
              title: 'Local',
              subtitle: 'Fluxo tradicional: Torre > Andar > Local > FVS',
              icon: Icons.location_on_outlined,
              onTap: () async {
                final picked = await Navigator.push<SelectFvsResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SelectFvsScreen(),
                  ),
                );

                if (!context.mounted || picked == null) return;

                final selection = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SelectLocationScreen(
                      title: 'Ficha F.V.S. – Escolher Local',
                      autoOpenFvsOnMap: false,
                      template: picked.template,
                      locationContext: picked.locationContext,
                    ),
                  ),
                );

                if (!context.mounted || selection == null) return;

                dynamic template = picked.template;
                String inspectionElement = picked.inspectionElement;
                String locationContext = picked.locationContext;
                Map<String, dynamic> location = selection;

                if (selection['location'] is Map<String, dynamic> &&
                    selection['template'] != null) {
                  location = selection['location'] as Map<String, dynamic>;
                  template = selection['template'];
                  inspectionElement = (selection['element'] ?? selection['inspectionElement'] ?? '').toString();
                  locationContext = (selection['locationContext'] ?? locationContext).toString();
                }

                final selectedLocation = location;

                if (!context.mounted || template == null) return;

                final conflict = _findConflictingInspection(
                  location: selectedLocation,
                  fvsCodigo: (template as FvsTemplate).codigo,
                  operationalSheetId: picked.operationalSheetId,
                );

                if (conflict != null && context.mounted) {
                  final choice = await _showDuplicateWarningDialog(context, conflict);
                  if (!context.mounted) return;
                  if (choice == _DuplicateChoice.cancel) return;
                  if (choice == _DuplicateChoice.openExisting) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InspectionScreen(
                          location: {
                            ...selectedLocation,
                            'element': inspectionElement,
                            'inspectionElement': inspectionElement,
                            'locationContext': locationContext,
                          },
                          template: template,
                          inspectionId: conflict.id,
                        ),
                      ),
                    );
                    return;
                  }
                  // _DuplicateChoice.createNew → continua para nova inspeção
                }

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InspectionScreen(
                      location: {
                        ...selectedLocation,
                        'element': inspectionElement,
                        'inspectionElement': inspectionElement,
                        'locationContext': locationContext,
                      },
                      template: template,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ModeCard(
              title: 'Ronda',
              subtitle: 'FVS > Torre > Grade de apartamentos',
              icon: Icons.grid_view_outlined,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RondaFlowScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            _ModeCard(
              title: 'Inspeção',
              subtitle: 'Torre > Grade > Tópicos (somente leitura)',
              icon: Icons.visibility_outlined,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InspectionReadOnlyTowerScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RondaFlowScreen extends StatefulWidget {
  const RondaFlowScreen({super.key});

  @override
  State<RondaFlowScreen> createState() => _RondaFlowScreenState();
}

class _RondaFlowScreenState extends State<RondaFlowScreen> {
  static String? _lastFvsCode;
  static String _lastInspectionElement = '';
  static String _lastLocationContext = '';

  late String _torre;
  FvsTemplate? _template;
  String _inspectionElement = '';
  String _locationContext = '';

  String get _obraAtual => ProjectContextService.instance.currentProjectNameSync;

  @override
  void initState() {
    super.initState();
    _torre = ObraStructure.torres.isNotEmpty ? ObraStructure.torres.first : 'Paris';
    if (_lastFvsCode != null) {
      for (final t in FvsCatalog.all) {
        if (t.codigo == _lastFvsCode) {
          _template = t;
          _inspectionElement = _lastInspectionElement;
          _locationContext = _lastLocationContext;
          break;
        }
      }
    }
  }

  Future<void> _pickFvs() async {
    final selected = await Navigator.push<SelectFvsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectFvsScreen(
          torre: _torre,
          hideFinalizedHint: true,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _template = selected.template;
      _inspectionElement = selected.inspectionElement;
      _locationContext = selected.locationContext;
      _lastFvsCode = selected.template.codigo;
      _lastInspectionElement = selected.inspectionElement;
      _lastLocationContext = selected.locationContext;
    });
  }

  String _keyFor({required OperationalGridCell cell}) => '$_torre|${cell.andar}|${cell.localRef}';

  Map<String, List<InspectionRecord>> _recordsByLocation(List<InspectionRecord> all) {
    final activeProjectId = ProjectContextService.instance.currentProjectIdSync;
    final out = <String, List<InspectionRecord>>{};
    for (final r in all) {
      if (!matchesActiveProject(
        activeProjectId: activeProjectId,
        recordProjectId: r.projectId,
        recordObra: r.obra,
      )) {
        continue;
      }
      if (r.deleted) continue;
      if (r.torre != _torre) continue;
      if (_template != null && r.fvsCodigo != _template!.codigo) continue;
      if (r.normalizedInspectionElement.isNotEmpty) continue;

      final ref = ObraStructure.resolveLocalRefForTower(
        tower: _torre,
        localRef: r.localRef,
        apto: r.apto,
      );
      final key = '$_torre|${r.andar}|$ref';
      out.putIfAbsent(key, () => <InspectionRecord>[]).add(r);
    }
    return out;
  }

  _RondaCellStatus _statusFor(List<InspectionRecord> records) {
    if (records.isEmpty) return _RondaCellStatus.branco;
    final hasOpenNc = records.any((r) => r.itens.any((i) => i.status == 'nok'));
    if (hasOpenNc) return _RondaCellStatus.amarelo;

    InspectionRecord latest = records.first;
    for (final r in records.skip(1)) {
      if (r.updatedAt.isAfter(latest.updatedAt)) latest = r;
    }
    return latest.isFinalState ? _RondaCellStatus.verde : _RondaCellStatus.cinza;
  }

  Future<void> _openInspection(OperationalGridCell cell, InspectionRecord? latestRecord) async {
    if (_template == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma FVS para iniciar a inspeção neste local.')),
      );
      await _pickFvs();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionScreen(
          location: {
            'obra': _obraAtual,
            'projectId': ProjectContextService.instance.currentProjectIdSync,
            'torre': _torre,
            'andar': cell.andar,
            'apto': cell.label,
            'localRef': cell.localRef,
            'localLabel': cell.label,
            'element': _inspectionElement,
            'inspectionElement': _inspectionElement,
            'locationContext': _locationContext,
          },
          template: _template!,
          inspectionId: latestRecord?.id,
          returnResultOnSaveFinish: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cells = ObraStructure.operationalCellsForTower(_torre);
    final specialCells = cells.where((c) => c.isSpecialArea).toList(growable: false);
    final apartmentCells = cells.where((c) => !c.isSpecialArea).toList(growable: false);
    final box = Hive.box<InspectionRecord>('inspections');

    return Scaffold(
      appBar: AppBar(title: const Text('Ronda')),
      body: ValueListenableBuilder<Box<InspectionRecord>>(
        valueListenable: box.listenable(),
        builder: (context, value, _) {
          final activeProjectId = ProjectContextService.instance.currentProjectIdSync;
          final scoped = filterRecordsByProjectScope(
            value.values,
            currentProjectId: activeProjectId,
            projectId: (r) => r.projectId,
            obra: (r) => r.obra,
          ).toList(growable: false);
          final byLocation = _recordsByLocation(scoped);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ObraStructure.torres
                    .map(
                      (t) => ChoiceChip(
                        selected: _torre == t,
                        label: Text(t),
                        onSelected: (_) => setState(() => _torre = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickFvs,
                icon: const Icon(Icons.checklist_outlined),
                label: Text(
                  _template == null
                      ? 'Selecionar FVS'
                      : 'FVS ${_template!.codigo} • ${_template!.nome}',
                ),
              ),
              const SizedBox(height: 10),
              if (specialCells.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: specialCells.length,
                  itemBuilder: (context, index) {
                    final cell = specialCells[index];
                    final records = byLocation[_keyFor(cell: cell)] ?? const <InspectionRecord>[];
                    InspectionRecord? latest;
                    for (final r in records) {
                      if (latest == null || r.updatedAt.isAfter(latest.updatedAt)) latest = r;
                    }
                    return _RondaTile(
                      label: cell.label,
                      status: _statusFor(records),
                      onTap: () async => _openInspection(cell, latest),
                    );
                  },
                ),
              if (specialCells.isNotEmpty) const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.35,
                ),
                itemCount: apartmentCells.length,
                itemBuilder: (context, index) {
                  final cell = apartmentCells[index];
                  final records = byLocation[_keyFor(cell: cell)] ?? const <InspectionRecord>[];
                  InspectionRecord? latest;
                  for (final r in records) {
                    if (latest == null || r.updatedAt.isAfter(latest.updatedAt)) latest = r;
                  }
                  return _RondaTile(
                    label: cell.label,
                    status: _statusFor(records),
                    onTap: () async => _openInspection(cell, latest),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _RondaCellStatus { branco, verde, amarelo, cinza }

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: appColors.borderStrong),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: appColors.selected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RondaTile extends StatelessWidget {
  const _RondaTile({
    required this.label,
    required this.status,
    required this.onTap,
  });

  final String label;
  final _RondaCellStatus status;
  final VoidCallback onTap;

  Color _bg(BuildContext context) {
    final appColors = context.appColors;
    switch (status) {
      case _RondaCellStatus.verde:
        return appColors.cardSemNC;
      case _RondaCellStatus.amarelo:
        return appColors.cardNCAberta;
      case _RondaCellStatus.cinza:
        return appColors.cardBackground;
      case _RondaCellStatus.branco:
        return Theme.of(context).cardColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: _bg(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: status == _RondaCellStatus.branco
                  ? appColors.borderStrong
                  : appColors.border,
              width: status == _RondaCellStatus.branco ? 1.4 : 1.1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: status == _RondaCellStatus.branco
                    ? appColors.textSecondary
                    : appColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InspectionReadOnlyTowerScreen extends StatefulWidget {
  const InspectionReadOnlyTowerScreen({super.key});

  @override
  State<InspectionReadOnlyTowerScreen> createState() => _InspectionReadOnlyTowerScreenState();
}

class _InspectionReadOnlyTowerScreenState extends State<InspectionReadOnlyTowerScreen> {
  late String _torre;

  @override
  void initState() {
    super.initState();
    _torre = ObraStructure.torres.isNotEmpty ? ObraStructure.torres.first : 'Paris';
  }

  String _keyFor({required OperationalGridCell cell}) => '$_torre|${cell.andar}|${cell.localRef}';

  Map<String, List<InspectionRecord>> _recordsByLocation(List<InspectionRecord> all) {
    final activeProjectId = ProjectContextService.instance.currentProjectIdSync;
    final out = <String, List<InspectionRecord>>{};
    for (final r in all) {
      if (!matchesActiveProject(
        activeProjectId: activeProjectId,
        recordProjectId: r.projectId,
        recordObra: r.obra,
      )) {
        continue;
      }
      if (r.deleted) continue;
      if (r.torre != _torre) continue;
      final ref = ObraStructure.resolveLocalRefForTower(
        tower: _torre,
        localRef: r.localRef,
        apto: r.apto,
      );
      final key = '$_torre|${r.andar}|$ref';
      out.putIfAbsent(key, () => <InspectionRecord>[]).add(r);
    }
    return out;
  }

  _RondaCellStatus _statusFor(List<InspectionRecord> records) {
    if (records.isEmpty) return _RondaCellStatus.branco;
    final hasOpenNc = records.any((r) => r.itens.any((i) => i.status == 'nok'));
    if (hasOpenNc) return _RondaCellStatus.amarelo;

    InspectionRecord latest = records.first;
    for (final r in records.skip(1)) {
      if (r.updatedAt.isAfter(latest.updatedAt)) latest = r;
    }
    return latest.isFinalState ? _RondaCellStatus.verde : _RondaCellStatus.cinza;
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<InspectionRecord>('inspections');
    final cells = ObraStructure.operationalCellsForTower(_torre);
    final specialCells = cells.where((c) => c.isSpecialArea).toList(growable: false);
    final apartmentCells = cells.where((c) => !c.isSpecialArea).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Inspeção (somente leitura)')),
      body: ValueListenableBuilder<Box<InspectionRecord>>(
        valueListenable: box.listenable(),
        builder: (context, value, _) {
          final activeProjectId = ProjectContextService.instance.currentProjectIdSync;
          final scoped = filterRecordsByProjectScope(
            value.values,
            currentProjectId: activeProjectId,
            projectId: (r) => r.projectId,
            obra: (r) => r.obra,
          ).toList(growable: false);
          final byLocation = _recordsByLocation(scoped);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ObraStructure.torres
                    .map(
                      (t) => ChoiceChip(
                        selected: _torre == t,
                        label: Text(t),
                        onSelected: (_) => setState(() => _torre = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              if (specialCells.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: specialCells.length,
                  itemBuilder: (context, index) {
                    final cell = specialCells[index];
                    final records = byLocation[_keyFor(cell: cell)] ?? const <InspectionRecord>[];
                    return _RondaTile(
                      label: cell.label,
                      status: _statusFor(records),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InspectionTopicsScreen(
                              torre: _torre,
                              andar: cell.andar,
                              localRef: cell.localRef,
                              localLabel: cell.label,
                              readOnlyMode: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              if (specialCells.isNotEmpty) const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.35,
                ),
                itemCount: apartmentCells.length,
                itemBuilder: (context, index) {
                  final cell = apartmentCells[index];
                  final records = byLocation[_keyFor(cell: cell)] ?? const <InspectionRecord>[];
                  return _RondaTile(
                    label: cell.label,
                    status: _statusFor(records),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InspectionTopicsScreen(
                            torre: _torre,
                            andar: cell.andar,
                            localRef: cell.localRef,
                            localLabel: cell.label,
                            readOnlyMode: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class InspectionTopicsScreen extends StatelessWidget {
  const InspectionTopicsScreen({
    super.key,
    required this.torre,
    required this.andar,
    required this.localRef,
    required this.localLabel,
    this.readOnlyMode = false,
  });

  final String torre;
  final int andar;
  final String localRef;
  final String localLabel;
  final bool readOnlyMode;

  static const Set<String> _aptoPrefixes = {'4', '5', '6', '7', '8'};

  bool _isApartmentScope(FvsTemplate t) {
    final p = t.codigo.split('.').first;
    return _aptoPrefixes.contains(p);
  }

  int _compareFvsCode(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 999999).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 999999).toList();
    final max = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < max; i++) {
      final va = i < pa.length ? pa[i] : -1;
      final vb = i < pb.length ? pb[i] : -1;
      if (va != vb) return va.compareTo(vb);
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final inspections = Hive.box<InspectionRecord>('inspections');
    final activeProjectId = ProjectContextService.instance.currentProjectIdSync;
    final templates = FvsCatalog.all.where(_isApartmentScope).toList()
      ..sort((a, b) => _compareFvsCode(a.codigo, b.codigo));

    return Scaffold(
      appBar: AppBar(title: Text('Tópicos • $torre • $localLabel')),
      body: Builder(
        builder: (context) {
          final latestByFvs = <String, InspectionRecord>{};
          final scopedInspections = filterRecordsByProjectScope(
            inspections.values.where((r) => !r.deleted),
            currentProjectId: activeProjectId,
            projectId: (r) => r.projectId,
            obra: (r) => r.obra,
          );
          for (final record in scopedInspections) {
            if (record.torre != torre ||
                record.andar != andar ||
                record.localRef != localRef ||
                record.normalizedInspectionElement.isNotEmpty) {
              continue;
            }
            final prev = latestByFvs[record.fvsCodigo];
            if (prev == null || record.updatedAt.isAfter(prev.updatedAt)) {
              latestByFvs[record.fvsCodigo] = record;
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final t = templates[index];
              final latest = latestByFvs[t.codigo];

              final appColors = context.appColors;
              Color dot = Theme.of(context).cardColor;
              if (latest != null) {
                final hasNc = latest.itens.any((i) => i.status == 'nok');
                if (hasNc) {
                  dot = appColors.cardNCAberta;
                } else if (latest.isFinalState) {
                  dot = appColors.cardSemNC;
                } else {
                  dot = appColors.cardBackground;
                }
              }

              return Card(
                child: ExpansionTile(
                  title: Text('FVS ${t.codigo}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(t.nome),
                  leading: CircleAvatar(backgroundColor: dot, radius: 8),
                  children: [
                    ...List<Widget>.generate(
                      t.itens.length,
                      (itemIndex) => ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        title: Text('${itemIndex + 1}. ${t.itens[itemIndex].descricao}'),
                        subtitle: t.itens[itemIndex].dica.trim().isEmpty ? null : Text(t.itens[itemIndex].dica),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: TextButton.icon(
                          icon: Icon(readOnlyMode ? Icons.visibility_outlined : Icons.edit_outlined),
                          label: Text(
                            readOnlyMode ? 'Abrir inspeção (somente leitura)' : 'Abrir inspeção (editável)',
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InspectionScreen(
                                  location: {
                                    'obra': ProjectContextService.instance.currentProjectNameSync,
                                    'projectId': ProjectContextService.instance.currentProjectIdSync,
                                    'torre': torre,
                                    'andar': andar,
                                    'apto': localLabel,
                                    'localRef': localRef,
                                    'localLabel': localLabel,
                                  },
                                  template: t,
                                  inspectionId: latest?.id,
                                  readOnly: readOnlyMode,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Detecção de inspeção duplicada ───────────────────────────────────────────

enum _DuplicateChoice { openExisting, createNew, cancel }

/// Procura o registro mais recente (últimos 30 dias) para o mesmo
/// escopo (projeto + torre + local + FVS) feito por outro usuário.
InspectionRecord? _findConflictingInspection({
  required Map<String, dynamic> location,
  required String fvsCodigo,
  String? operationalSheetId,
}) {
  final currentUid = AuthService.instance.currentUser?.uid ?? '';
  final projectId = (location['projectId'] ??
          ProjectContextService.instance.currentProjectIdSync)
      .toString()
      .trim()
      .toLowerCase();
  final torre = (location['torre'] ?? '').toString().trim().toLowerCase();
  final apto = (location['apto'] ?? '').toString().trim();
  final localRef = (location['localRef'] ?? '').toString().trim();
  final normalizedLocation =
      localRef.isNotEmpty ? localRef.toLowerCase() : apto.toLowerCase();
  final normalizedFvs = fvsCodigo.trim().toLowerCase();
  final normalizedSheet = (operationalSheetId ?? '').trim().toLowerCase();
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));

  final box = Hive.box<InspectionRecord>('inspections');
  InspectionRecord? best;
  for (final record in box.values) {
    if (record.deleted) continue;
    if ((record.actionByUid ?? '') == currentUid) continue;
    if (record.updatedAt.isBefore(cutoff)) continue;
    if (record.projectId.trim().toLowerCase() != projectId) continue;
    if (record.fvsCodigo.trim().toLowerCase() != normalizedFvs) continue;
    if (record.torre.trim().toLowerCase() != torre) continue;
    final recLoc = ((record.localRef ?? '').trim().isNotEmpty
            ? record.localRef!.trim()
            : record.apto.trim())
        .toLowerCase();
    if (recLoc != normalizedLocation) continue;
    if ((record.operationalSheetId ?? '').trim().toLowerCase() !=
        normalizedSheet) {
      continue;
    }
    if (best == null || record.updatedAt.isAfter(best.updatedAt)) {
      best = record;
    }
  }
  return best;
}

Future<_DuplicateChoice> _showDuplicateWarningDialog(
  BuildContext context,
  InspectionRecord conflict,
) async {
  final byName = (conflict.actionByName ?? '').trim().isNotEmpty
      ? conflict.actionByName!.trim()
      : 'outro usuário';
  final dt = conflict.updatedAt;
  final dateStr =
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  final choice = await showDialog<_DuplicateChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Inspeção já realizada'),
      content: Text(
        '$byName já inspecionou esta FVS em $dateStr.\n\n'
        'Deseja abrir a inspeção existente ou criar uma nova separada?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _DuplicateChoice.cancel),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _DuplicateChoice.createNew),
          child: const Text('Criar nova'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _DuplicateChoice.openExisting),
          child: const Text('Abrir existente'),
        ),
      ],
    ),
  );
  return choice ?? _DuplicateChoice.cancel;
}

