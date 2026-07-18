import 'package:flutter/material.dart';

import '../services/inspection_duplicate_cleanup_service.dart';
import '../services/inspection_duplicate_diagnosis_service.dart';

class DuplicateDiagnosisScreen extends StatefulWidget {
  const DuplicateDiagnosisScreen({super.key, this.projectId});

  final String? projectId;

  @override
  State<DuplicateDiagnosisScreen> createState() => _DuplicateDiagnosisScreenState();
}

class _DuplicateDiagnosisScreenState extends State<DuplicateDiagnosisScreen> {
  late Future<InspectionDuplicateDiagnosisSummary> _future;
  InspectionDuplicateCleanupPreview? _lastPreview;

  @override
  void initState() {
    super.initState();
    _future = _runDiagnosis();
  }

  Future<InspectionDuplicateDiagnosisSummary> _runDiagnosis() {
    return InspectionDuplicateDiagnosisService.instance.diagnoseLocalDuplicates(
      projectId: widget.projectId,
      verboseLogs: true,
    );
  }

  Future<void> _previewCleanup(DuplicateCleanupMode mode) async {
    final preview = await InspectionDuplicateCleanupService.instance.previewCleanup(
      projectId: widget.projectId,
      mode: mode,
      verboseLogs: true,
    );
    if (!mounted) return;
    setState(() {
      _lastPreview = preview;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Prévia (${mode.name}): ${preview.totalDuplicateGroups} grupos, '
          '${preview.totalRecordsToRemove} registros para remoção.',
        ),
      ),
    );
  }

  Future<void> _runCleanup(DuplicateCleanupMode mode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar limpeza'),
        content: Text(
          mode == DuplicateCleanupMode.safeKeepLatest
              ? 'Modo seguro: manter o mais recente de cada grupo duplicado e remover os demais.'
              : 'Modo agressivo: remover todos os registros de cada grupo duplicado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Executar limpeza'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await InspectionDuplicateCleanupService.instance.executeCleanup(
      projectId: widget.projectId,
      mode: mode,
      verboseLogs: true,
    );

    if (!mounted) return;
    setState(() {
      _lastPreview = result.preview;
      _future = _runDiagnosis();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Limpeza concluída: removidos ${result.removedCount}. '
          'NC ${result.beforeOpenNc}→${result.afterOpenNc}, '
          'Hoje ${result.beforeTodayInspections}→${result.afterTodayInspections}.',
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:''${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de duplicados'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Limpeza de duplicados',
            onSelected: (value) async {
              if (value == 'preview_safe') {
                await _previewCleanup(DuplicateCleanupMode.safeKeepLatest);
              } else if (value == 'preview_aggressive') {
                await _previewCleanup(DuplicateCleanupMode.aggressiveDeleteAll);
              } else if (value == 'run_safe') {
                await _runCleanup(DuplicateCleanupMode.safeKeepLatest);
              } else if (value == 'run_aggressive') {
                await _runCleanup(DuplicateCleanupMode.aggressiveDeleteAll);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'preview_safe',
                child: Text('Prévia limpeza (modo seguro)'),
              ),
              PopupMenuItem(
                value: 'run_safe',
                child: Text('Executar limpeza (modo seguro)'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'preview_aggressive',
                child: Text('Prévia limpeza (modo agressivo)'),
              ),
              PopupMenuItem(
                value: 'run_aggressive',
                child: Text('Executar limpeza (modo agressivo)'),
              ),
            ],
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () {
              setState(() {
                _future = _runDiagnosis();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<InspectionDuplicateDiagnosisSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Falha ao rodar diagnóstico: ${snapshot.error}'),
              ),
            );
          }

          final summary = snapshot.data;
          if (summary == null) {
            return const Center(child: Text('Sem dados para diagnóstico.'));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (_lastPreview != null)
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Última prévia de limpeza',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text('Modo: ${_lastPreview!.mode.name}'),
                        Text('Grupos: ${_lastPreview!.totalDuplicateGroups}'),
                        Text('Registros para remoção: ${_lastPreview!.totalRecordsToRemove}'),
                        Text(
                          'Backup: ${_lastPreview!.backupFilePath ?? 'inline JSON no serviço'}',
                        ),
                      ],
                    ),
                  ),
                ),
              if (_lastPreview != null) const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inspeções analisadas: ${summary.totalInspectionsAnalyzed}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('Itens analisados: ${summary.totalItemOccurrencesAnalyzed}'),
                      Text('Grupos duplicados: ${summary.totalDuplicateGroups}'),
                      Text('Ocorrências duplicadas: ${summary.totalDuplicateOccurrences}'),
                      Text(
                        'Pendentes de sync (em duplicados): ${summary.totalWithPendingSyncInDuplicates}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (summary.groups.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Nenhum grupo duplicado detectado.'),
                  ),
                )
              else
                ...summary.groups.map(
                  (group) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FVS ${group.fvsCode} — ${group.fvsName}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text('Local: ${group.location}'),
                          Text('Item: ${group.itemDescription}'),
                          Text('Ocorrências: ${group.occurrences.length}'),
                          Text('Origem provável: ${group.originHints.join(', ')}'),
                          const SizedBox(height: 8),
                          ...group.occurrences.map(
                            (occurrence) => Text(
                              '- ${_formatDate(occurrence.date)} '
                              '(${occurrence.status}/${occurrence.itemStatus}) '
                              'id=${occurrence.recordId}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
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
