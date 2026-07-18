import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/inspection_record.dart';
import '../services/project_context_service.dart';
import '../utils/fvs_icon_formatter.dart';
import '../utils/nc_utils.dart';
import '../utils/project_scope.dart';
import 'duplicate_diagnosis_screen.dart';
import 'report_detail_screen.dart';

class OpenNcScreen extends StatefulWidget {
  const OpenNcScreen({super.key, required this.records});

  final List<InspectionRecord> records;

  @override
  State<OpenNcScreen> createState() => _OpenNcScreenState();
}

class _OpenNcScreenState extends State<OpenNcScreen> {
  static const String _semFvsCode = '__SEM_FVS__';
  static const String _semElemento = '__SEM_ELEMENTO__';

  String? _torreSel;
  String? _fvsSel;
  String? _elementSel;
  final ProjectContextService _projectContext = ProjectContextService.instance;

  String _localLabel(InspectionRecord r) {
    final ref = r.localRef?.trim();
    if (ref == null || ref.isEmpty) return r.apto;
    if (ref.startsWith('APTO_')) return ref.substring(5);

    switch (ref) {
      case 'HALL':
        return 'Hall';
      case 'ESCADA':
        return 'Escada';
      case 'ELEVADOR':
        return 'Elevador';
      case 'COBERTURA':
      case 'ROOFTOP':
        return 'Rooftop';
      case 'LAJE':
        return 'Laje';
      default:
        return ref;
    }
  }

  String _inspectionLabel(InspectionRecord r) {
    final local = _localLabel(r);
    final element = r.normalizedInspectionElement;
    if (element.isEmpty) return local;
    return '$local • $element';
  }

  List<String> _torreOptions(List<InspectionRecord> records) {
    final base = ['Paris', 'Viena', 'Garagem', 'Outros'];
    final all = {...base, ...records.map((r) => r.torre)}.toList();
    all.sort((a, b) {
      final ia = base.indexOf(a);
      final ib = base.indexOf(b);
      if (ia != -1 && ib != -1) return ia.compareTo(ib);
      if (ia != -1) return -1;
      if (ib != -1) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return all;
  }

  int _compareFvsCode(String a, String b) {
    if (a == _semFvsCode && b == _semFvsCode) return 0;
    if (a == _semFvsCode) return 1;
    if (b == _semFvsCode) return -1;

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

  String _normalizeFvsCode(String? code) {
    final normalized = code?.trim() ?? '';
    if (normalized.isEmpty) return _semFvsCode;
    return normalized;
  }

  String _normalizeFvsName(String? name) {
    final normalized = name?.trim() ?? '';
    if (normalized.isEmpty) return 'Sem FVS';
    return normalized;
  }

  String _fvsLabel(String? code) {
    if (code == null) return 'Todas';
    if (code == _semFvsCode) return 'Sem FVS';
    return code;
  }

  String _elementLabel(String? element) {
    if (element == null) return 'Todos';
    if (element == _semElemento) return 'Sem elemento';
    return element;
  }

  int _compareLocalNatural(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  List<_LocalEntry> _sortedEntries(Map<String, InspectionRecord> byLocal) {
    final entries = byLocal.entries
        .map((e) => _LocalEntry(local: e.key, record: e.value))
        .toList()
      ..sort((a, b) => _compareLocalNatural(a.local, b.local));
    return entries;
  }

  Future<void> _openRecord(InspectionRecord record) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(record: record),
      ),
    );
  }

  Future<T?> _openSheet<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required String Function(T) label,
    required T? selected,
  }) async {
    return showModalBottomSheet<T?>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Column(
              children: [
                ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: Icon(selected == null ? Icons.check_circle : Icons.circle_outlined),
                        title: const Text('Todas'),
                        onTap: () => Navigator.pop<T?>(context, null),
                      ),
                      ...options.map(
                        (o) => ListTile(
                          leading: Icon(selected == o ? Icons.check_circle : Icons.circle_outlined),
                          title: Text(label(o)),
                          onTap: () => Navigator.pop<T?>(context, o),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProjectId = _projectContext.currentProjectIdSync;
    final withNc = filterRecordsByProjectScope(
      widget.records.where((r) => r.itens.any((i) => i.status == 'nok')),
      currentProjectId: currentProjectId,
      projectId: (r) => r.projectId,
      obra: (r) => r.obra,
    ).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final torreOptions = _torreOptions(withNc);
    final fvsMap = <String, String>{};
    for (final r in withNc) {
      final fvsCode = _normalizeFvsCode(r.fvsCodigo);
      final fvsName = _normalizeFvsName(r.fvsNome);
      fvsMap.putIfAbsent(fvsCode, () => fvsName);
    }
    final fvsOptions = fvsMap.keys.toList()..sort(_compareFvsCode);

    final elementOptions = withNc
        .map((r) => r.normalizedInspectionElement)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final hasLegacyWithoutElement = withNc.any((r) => r.normalizedInspectionElement.isEmpty);

    final filtered = withNc.where((r) {
      if (_torreSel != null && r.torre != _torreSel) return false;
      if (_fvsSel != null && _normalizeFvsCode(r.fvsCodigo) != _fvsSel) return false;
      if (_elementSel != null) {
        final element = r.normalizedInspectionElement;
        if (_elementSel == _semElemento) {
          if (element.isNotEmpty) return false;
        } else {
          if (element != _elementSel) return false;
        }
      }
      return true;
    }).toList();

    final grouped = SplayTreeMap<String, _FvsGroup>(_compareFvsCode);
    for (final r in filtered) {
      final fvsCode = _normalizeFvsCode(r.fvsCodigo);
      final fvsName = _normalizeFvsName(r.fvsNome);
      final group = grouped.putIfAbsent(
        fvsCode,
        () => _FvsGroup(fvsCode: fvsCode, fvsName: fvsName),
      );
      final local = _inspectionLabel(r);
      group.add(r.torre, local, r);
    }

    final totalOpenItems = countOpenNcItemsUnique(filtered);
    final totalUniqueInspections = countUniqueInspectionsByFvsLocationDay(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NC abertas'),
        actions: [
          IconButton(
            tooltip: 'Diagnóstico de duplicados',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DuplicateDiagnosisScreen(projectId: currentProjectId),
                ),
              );
            },
            icon: const Icon(Icons.analytics_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_outlined, size: 16),
                    label: Text('Torre: ${_torreSel ?? 'Todas'}'),
                    onPressed: () async {
                      final v = await _openSheet<String>(
                        context: context,
                        title: 'Selecionar torre',
                        options: torreOptions,
                        label: (o) => o,
                        selected: _torreSel,
                      );
                      if (!mounted) return;
                      setState(() => _torreSel = v);
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_outlined, size: 16),
                    label: Text('FVS: ${_fvsLabel(_fvsSel)}'),
                    onPressed: () async {
                      final v = await _openSheet<String>(
                        context: context,
                        title: 'Selecionar FVS',
                        options: fvsOptions,
                        label: (o) => o == _semFvsCode ? 'Sem FVS' : '$o - ${fvsMap[o]}',
                        selected: _fvsSel,
                      );
                      if (!mounted) return;
                      setState(() => _fvsSel = v);
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_outlined, size: 16),
                    label: Text('Elemento: ${_elementLabel(_elementSel)}'),
                    onPressed: () async {
                      final options = <String>[
                        if (hasLegacyWithoutElement) _semElemento,
                        ...elementOptions.where((e) => e.isNotEmpty),
                      ];
                      final v = await _openSheet<String>(
                        context: context,
                        title: 'Selecionar elemento',
                        options: options,
                        label: (o) => o == _semElemento ? 'Sem elemento' : o,
                        selected: _elementSel,
                      );
                      if (!mounted) return;
                      setState(() => _elementSel = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$totalOpenItems itens X em $totalUniqueInspections inspeções',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child: grouped.isEmpty
                ? const Center(child: Text('Nenhuma NC em aberto.'))
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      12 + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    itemCount: grouped.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final group = grouped.values.elementAt(index);
                      final baseLabel = group.fvsCode == _semFvsCode
                          ? 'Sem FVS'
                          : (group.fvsName.trim().isNotEmpty
                              ? group.fvsName.trim()
                              : 'FVS ${group.fvsCode}');
                      final title =
                          '${FvsIconFormatter.getFvsIcon(group.fvsName)} $baseLabel';
                      final showParis = _torreSel == null || _torreSel == 'Paris';
                      final showViena = _torreSel == null || _torreSel == 'Viena';
                      final parisMap = group.torreToRecordByLocal['Paris'] ?? <String, InspectionRecord>{};
                      final vienaMap = group.torreToRecordByLocal['Viena'] ?? <String, InspectionRecord>{};
                      final paris = parisMap.keys.toSet();
                      final viena = vienaMap.keys.toSet();

                      return Card(
                        child: ExpansionTile(
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: group.fvsCode == _semFvsCode
                                ? null
                                : Text('Código: ${group.fvsCode}'),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            children: [
                            if (showParis && paris.isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text('Paris:', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ..._sortedEntries(parisMap).map(
                                      (e) => ActionChip(
                                        label: Text(
                                          e.ncCompanyName.isEmpty
                                              ? e.local
                                              : '${e.local} • ${e.ncCompanyName}',
                                        ),
                                        onPressed: () => _openRecord(e.record),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (showViena && viena.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      const Text('Viena:', style: TextStyle(fontWeight: FontWeight.w700)),
                                      ..._sortedEntries(vienaMap).map(
                                        (e) => ActionChip(
                                          label: Text(
                                            e.ncCompanyName.isEmpty
                                                ? e.local
                                                : '${e.local} • ${e.ncCompanyName}',
                                          ),
                                          onPressed: () => _openRecord(e.record),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (!showParis && !showViena)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Sem dados para a torre filtrada.'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FvsGroup {
  _FvsGroup({required this.fvsCode, required this.fvsName});

  final String fvsCode;
  final String fvsName;
  final Map<String, Map<String, InspectionRecord>> torreToRecordByLocal = {
    'Paris': <String, InspectionRecord>{},
    'Viena': <String, InspectionRecord>{},
  };

  void add(String torre, String local, InspectionRecord record) {
    final bucket = torreToRecordByLocal.putIfAbsent(torre, () => <String, InspectionRecord>{});
    final current = bucket[local];
    if (current == null || record.updatedAt.isAfter(current.updatedAt)) {
      bucket[local] = record;
    }
  }
}

class _LocalEntry {
  _LocalEntry({required this.local, required this.record});

  final String local;
  final InspectionRecord record;

  String get ncCompanyName {
    for (final item in record.itens) {
      if (item.status != 'nok') continue;
      final itemCompany = item.ncCompanyName?.trim();
      if (itemCompany != null && itemCompany.isNotEmpty) {
        return itemCompany;
      }
    }
    final recordCompany = record.ncCompanyName?.trim();
    if (recordCompany != null && recordCompany.isNotEmpty) {
      return recordCompany;
    }
    return '';
  }
}
