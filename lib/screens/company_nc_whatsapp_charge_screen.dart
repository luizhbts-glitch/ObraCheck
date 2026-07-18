import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/company_record.dart';
import '../models/inspection_record.dart';
import '../services/project_context_service.dart';
import '../utils/project_scope.dart';

class CompanyNcWhatsappChargeScreen extends StatefulWidget {
  const CompanyNcWhatsappChargeScreen({
    super.key,
    required this.company,
  });

  final CompanyRecord company;

  @override
  State<CompanyNcWhatsappChargeScreen> createState() =>
      _CompanyNcWhatsappChargeScreenState();
}

class _CompanyNcWhatsappChargeScreenState
    extends State<CompanyNcWhatsappChargeScreen> {
  final Set<String> _selected = <String>{};
  final ProjectContextService _projectContext = ProjectContextService.instance;

  String _localLabel(InspectionRecord r) {
    final ref = r.localRef?.trim();
    if (ref == null || ref.isEmpty) return r.apto;
    if (ref.startsWith('APTO_')) return ref.substring(5);
    return ref;
  }

  List<_NcChargeEntry> _buildEntries({
    required CompanyRecord company,
    required Iterable<InspectionRecord> inspections,
  }) {
    final currentProjectId = _projectContext.currentProjectIdSync;
    final scopedInspections = filterRecordsByProjectScope(
      inspections,
      currentProjectId: currentProjectId,
      projectId: (r) => r.projectId,
      obra: (r) => r.obra,
    );

    final out = <_NcChargeEntry>[];
    for (final record in scopedInspections) {
      if (record.deleted) continue;
      for (final item in record.itens) {
        if (item.status != 'nok') continue;
        final itemCompanyId = (item.ncCompanyId ?? '').trim();
        final recordCompanyId = (record.ncCompanyId ?? '').trim();
        final belongsToCompany =
            itemCompanyId == company.id ||
                (itemCompanyId.isEmpty && recordCompanyId == company.id);
        if (!belongsToCompany) continue;

        final summary = item.obs.trim().isNotEmpty
            ? item.obs.trim()
            : item.descricao.trim();
        final key = '${record.id}:${item.index}';

        out.add(
          _NcChargeEntry(
            key: key,
            record: record,
            item: item,
            tower: record.torre,
            location: _localLabel(record),
            fvsCode: record.fvsCodigo.trim(),
            fvsName: record.fvsNome.trim(),
            summary: summary,
          ),
        );
      }
    }

    out.sort((a, b) {
      final byTower = a.tower.toLowerCase().compareTo(b.tower.toLowerCase());
      if (byTower != 0) return byTower;
      final byLocation =
          a.location.toLowerCase().compareTo(b.location.toLowerCase());
      if (byLocation != 0) return byLocation;
      return a.summary.toLowerCase().compareTo(b.summary.toLowerCase());
    });
    return out;
  }

  String _formatPhoneForWhatsApp(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('55')) return digits;
    if (digits.length == 10 || digits.length == 11) return '55$digits';
    return digits;
  }

  String _buildWhatsappMessage({
    required String companyName,
    required List<_NcChargeEntry> selectedEntries,
  }) {
    final lines = selectedEntries.map((e) {
      final fvsLabel = e.fvsCode.isEmpty ? e.fvsName : 'FVS ${e.fvsCode}';
      return '- ${e.tower} ${e.location} — $fvsLabel — ${e.summary}';
    }).join('\n');

    return 'Olá, $companyName.\n\n'
        'Seguem pendências para regularização:\n\n'
        '$lines\n\n'
        'Favor programar retorno para correção.';
  }

  Future<void> _sendToWhatsApp({
    required CompanyRecord company,
    required List<_NcChargeEntry> entries,
  }) async {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há NC aberta para este empreiteiro.')),
      );
      return;
    }

    final selected = entries.where((e) => _selected.contains(e.key)).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos uma pendência antes de cobrar.'),
        ),
      );
      return;
    }

    final phone = _formatPhoneForWhatsApp((company.phone ?? '').trim());
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este empreiteiro não possui telefone/WhatsApp cadastrado.'),
        ),
      );
      return;
    }

    final message = _buildWhatsappMessage(
      companyName: company.nome,
      selectedEntries: selected,
    );

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o WhatsApp neste dispositivo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companiesBox = Hive.box<CompanyRecord>('companies');
    final inspectionsBox = Hive.box<InspectionRecord>('inspections');

    return ValueListenableBuilder<Box<InspectionRecord>>(
      valueListenable: inspectionsBox.listenable(),
      builder: (context, inspectionsValue, _) {
        return ValueListenableBuilder<Box<CompanyRecord>>(
          valueListenable: companiesBox.listenable(),
          builder: (context, companiesValue, _) {
            final currentCompany =
                companiesValue.get(widget.company.id) ?? widget.company;

            final entries = _buildEntries(
              company: currentCompany,
              inspections: inspectionsValue.values,
            );

            _selected.removeWhere(
              (key) => !entries.any((e) => e.key == key),
            );

            return Scaffold(
              appBar: AppBar(
                title: Text('Cobrar NC • ${currentCompany.nome}'),
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: entries.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _selected
                                        ..clear()
                                        ..addAll(entries.map((e) => e.key));
                                    });
                                  },
                            icon: const Icon(Icons.done_all_outlined),
                            label: const Text('Marcar tudo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selected.isEmpty
                                ? null
                                : () {
                                    setState(_selected.clear);
                                  },
                            icon: const Icon(Icons.remove_done_outlined),
                            label: const Text('Desmarcar tudo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${entries.length} pendências abertas • ${_selected.length} selecionadas',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(
                            child: Text('Nenhuma NC aberta para este empreiteiro.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            itemCount: entries.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final selected = _selected.contains(entry.key);
                              final fvsText = entry.fvsCode.isEmpty
                                  ? entry.fvsName
                                  : 'FVS ${entry.fvsCode}';
                              final title =
                                  '${entry.tower} ${entry.location} — $fvsText — ${entry.summary}';

                              return Card(
                                child: CheckboxListTile(
                                  value: selected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selected.add(entry.key);
                                      } else {
                                        _selected.remove(entry.key);
                                      }
                                    });
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(title),
                                  subtitle: Text(
                                    'Inspeção ${entry.record.id} • Item ${entry.item.index + 1}',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: FilledButton.icon(
                  onPressed: () async {
                    await _sendToWhatsApp(company: currentCompany, entries: entries);
                  },
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('Cobrar no WhatsApp'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NcChargeEntry {
  const _NcChargeEntry({
    required this.key,
    required this.record,
    required this.item,
    required this.tower,
    required this.location,
    required this.fvsCode,
    required this.fvsName,
    required this.summary,
  });

  final String key;
  final InspectionRecord record;
  final InspectionItemResult item;
  final String tower;
  final String location;
  final String fvsCode;
  final String fvsName;
  final String summary;
}

