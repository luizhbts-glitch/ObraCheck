import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/arsen_structure.dart';
import '../models/inspection_record.dart';
import '../services/project_context_service.dart';
import '../theme/app_colors.dart';
import '../utils/project_scope.dart';
import 'ficha_fvs_mode_screen.dart';

class VisualTowerMapScreen extends StatefulWidget {
  const VisualTowerMapScreen({super.key, this.initialTower});

  final String? initialTower;

  @override
  State<VisualTowerMapScreen> createState() => _VisualTowerMapScreenState();
}

class _VisualTowerMapScreenState extends State<VisualTowerMapScreen> {
  late String _torre;

  @override
  void initState() {
    super.initState();
    final defaultTower = ObraStructure.torres.isNotEmpty ? ObraStructure.torres.first : 'Paris';
    _torre = widget.initialTower ?? defaultTower;
  }

  List<_ApartmentCell> _buildApartmentCells() {
    final out = <_ApartmentCell>[];
    final cells = ObraStructure.operationalCellsForTower(_torre);

    for (final c in cells) {
      out.add(_ApartmentCell(andar: c.andar, apto: c.label, localRef: c.localRef));
    }

    return out;
  }

  String _recordLocalRef(InspectionRecord r) {
    final localRef = r.localRef?.trim();
    if (localRef != null && localRef.isNotEmpty) return localRef;
    return 'APTO_${r.apto}';
  }

  bool _isOpenNc(InspectionRecord r) {
    return r.itens.any((i) => i.status == 'nok');
  }

  Map<String, bool> _openNcByApartment(List<InspectionRecord> all) {
    final map = <String, bool>{};
    for (final r in all) {
      if (r.torre != _torre) continue;
      final ref = _recordLocalRef(r);
      final apt = _labelFromLocalRef(ref);
      final hasOpenNc = _isOpenNc(r);
      final prev = map[apt] ?? false;
      map[apt] = prev || hasOpenNc;
    }
    return map;
  }

  String _labelFromLocalRef(String ref) {
    if (ref.startsWith('APTO_')) return ref.substring(5);
    if (ref == 'ROOFTOP' || ref == 'COBERTURA') return 'Rooftop';

    for (final e in ObraStructure.specialAreasForTower(_torre)) {
      if (e.localRef == ref) return e.label;
    }
    return ref;
  }

  Future<void> _openApartmentInspection({
    required BuildContext context,
    required _ApartmentCell cell,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionTopicsScreen(
          torre: _torre,
          andar: cell.andar,
          localRef: cell.localRef,
          localLabel: cell.apto,
          readOnlyMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final box = Hive.box<InspectionRecord>('inspections');
    final cells = _buildApartmentCells();

    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa visual - Torre $_torre'),
      ),
      body: ValueListenableBuilder<Box<InspectionRecord>>(
        valueListenable: box.listenable(),
        builder: (context, value, _) {
          final activeProjectId = ProjectContextService.instance.currentProjectIdSync;
          final all = value.values
              .where(
                (record) =>
                    !record.deleted &&
                    matchesActiveProject(
                      activeProjectId: activeProjectId,
                      recordProjectId: record.projectId,
                      recordObra: record.obra,
                    ),
              )
              .toList();
          final openByApt = _openNcByApartment(all);
          final normalCells = cells.where((c) => c.localRef.startsWith('APTO_')).toList();
          final coverageCells = cells.where((c) => !c.localRef.startsWith('APTO_')).toList();
          final totalApartamentos = cells.length;
          final comNc = cells.where((c) => openByApt[c.apto] == true).length;
          final semNc = totalApartamentos - comNc;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mapa visual - Torre $_torre',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visão rápida de NC abertas por apartamento',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ObraStructure.torres
                          .map(
                            (t) => ChoiceChip(
                              selected: _torre == t,
                              label: Text(t),
                              labelStyle: TextStyle(
                                color: _torre == t ? Colors.blueGrey.shade900 : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              selectedColor: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.18),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                              onSelected: (_) => setState(() => _torre = t),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryCard(
                    title: 'Apartamentos',
                    value: '$totalApartamentos',
                    color: appColors.primaryAction,
                  ),
                  _SummaryCard(
                    title: 'Com NC',
                    value: '$comNc',
                    color: appColors.warning,
                  ),
                  _SummaryCard(
                    title: 'Sem NC',
                    value: '$semNc',
                    color: appColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _LegendPill(color: appColors.cardSemNC, label: 'Sem NC'),
                      _LegendPill(color: appColors.cardNCAberta, label: 'NC aberta'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 10.0;
                      final normalCardWidth = (constraints.maxWidth - (gap * 3)) / 4;
                      final coverageCardWidth = (constraints.maxWidth - (gap * 2)) / 3;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: gap,
                            runSpacing: 12,
                            children: normalCells
                                .map(
                                  (cell) => SizedBox(
                                    width: normalCardWidth,
                                    child: _ApartmentStatusCard(
                                      apto: cell.apto,
                                      hasOpenNc: openByApt[cell.apto] == true,
                                      onTap: () async => _openApartmentInspection(
                                        context: context,
                                        cell: cell,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          if (coverageCells.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Cobertura',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: gap,
                              runSpacing: 12,
                              children: coverageCells
                                  .map(
                                    (cell) => SizedBox(
                                      width: coverageCardWidth,
                                      child: _ApartmentStatusCard(
                                        apto: cell.apto,
                                        hasOpenNc: openByApt[cell.apto] == true,
                                        onTap: () async => _openApartmentInspection(
                                          context: context,
                                          cell: cell,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ApartmentCell {
  const _ApartmentCell({
    required this.andar,
    required this.apto,
    required this.localRef,
  });

  final int andar;
  final String apto;
  final String localRef;
}

class _ApartmentStatusCard extends StatelessWidget {
  const _ApartmentStatusCard({
    required this.apto,
    required this.hasOpenNc,
    required this.onTap,
  });

  final String apto;
  final bool hasOpenNc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasOpenNc ? appColors.cardNCAberta : appColors.cardSemNC,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            apto,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: hasOpenNc ? appColors.cardNCAbertaText : appColors.cardSemNCText,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.black12),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
