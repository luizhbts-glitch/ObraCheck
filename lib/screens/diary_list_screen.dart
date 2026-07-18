import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/diary_record.dart';
import '../models/project_record.dart';
import '../services/project_context_service.dart';
import '../utils/app_date_utils.dart';
import '../utils/project_scope.dart';
import 'diary_edit_screen.dart';
import 'project_data_analysis_screen.dart';

class DiaryListScreen extends StatefulWidget {
  const DiaryListScreen({super.key});

  @override
  State<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends State<DiaryListScreen> {
  final ProjectContextService _projectContext = ProjectContextService.instance;

  Future<void> _openDiary({DiaryRecord? diary}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEditScreen(diary: diary),
      ),
    );
  }

  Future<void> _openDataAnalysis() async {
    final projectId = _projectContext.currentProjectIdSync;
    final projectName = _projectContext.currentProjectNameSync;
    if (projectId.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma obra ativa para abrir a análise.'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDataAnalysisScreen(
          projectId: projectId,
          projectName: projectName,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return AppDateUtils.formatDateBr(date);
  }

  String _fallbackClimatePart(String climate, String label) {
    final normalized = climate.trim();
    if (normalized.isEmpty) return '-';
    final regex = RegExp('$label\\s*:\\s*([^|]+)', caseSensitive: false);
    final match = regex.firstMatch(normalized);
    if (match != null) {
      final part = (match.group(1) ?? '').trim();
      if (part.isNotEmpty) return part;
    }
    if (!normalized.contains('|')) {
      return normalized;
    }
    final parts = normalized.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.first;
    return '-';
  }

  String _resolveClimateMorning(DiaryRecord diary) {
    final saved = diary.climateMorning.trim();
    if (saved.isNotEmpty) return saved;
    return _fallbackClimatePart(diary.climate, 'manhã');
  }

  String _resolveClimateAfternoon(DiaryRecord diary) {
    final saved = diary.climateAfternoon.trim();
    if (saved.isNotEmpty) return saved;
    return _fallbackClimatePart(diary.climate, 'tarde');
  }

  int _countOwnLaborPeople(DiaryRecord diary) {
    return diary.ownLaborEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.peopleCount,
    );
  }

  int _countThirdPartyPeople(DiaryRecord diary) {
    return diary.serviceEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.peopleCount,
    );
  }

  int _countTotalPeople(DiaryRecord diary) {
    return _countOwnLaborPeople(diary) + _countThirdPartyPeople(diary);
  }

  int _countFrentes(DiaryRecord diary) {
    return diary.serviceEntries.length;
  }

  _ProjectTimelineSummary _buildProjectTimelineSummary({
    required ProjectRecord? project,
    DateTime? startedAt,
    DateTime? expectedEndAt,
  }) {
    return _ProjectTimelineSummary(
      projectId: project?.id,
      startedAt: startedAt == null ? null : AppDateUtils.normalizeLocalDate(startedAt),
      expectedEndAt: expectedEndAt == null ? null : AppDateUtils.normalizeLocalDate(expectedEndAt),
      today: AppDateUtils.getTodayDate(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<DiaryRecord>('diaries');

    return Scaffold(
      appBar: AppBar(title: const Text('Diário de Obra')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDiary(),
        icon: const Icon(Icons.add),
        label: const Text('Novo diário'),
      ),
      body: ValueListenableBuilder<Box<DiaryRecord>>(
        valueListenable: box.listenable(),
        builder: (context, value, _) {
          final currentProjectId = _projectContext.currentProjectIdSync;
          final diariesDesc = filterRecordsByProjectScope(
            value.values.where((d) => !d.deleted),
            currentProjectId: currentProjectId,
            projectId: (d) => d.projectId,
            obra: (d) => d.obra,
          ).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          final diariesAsc = [...diariesDesc]..sort((a, b) => a.date.compareTo(b.date));
          final diaryNumberById = <String, int>{};
          for (var i = 0; i < diariesAsc.length; i++) {
            diaryNumberById[diariesAsc[i].id] = i + 1;
          }

          final project = Hive.box<ProjectRecord>('projects').get(currentProjectId);
          final timelineSummary = _buildProjectTimelineSummary(project: project);

          if (diariesDesc.isEmpty) {
            return const Center(
              child: Text('Nenhum diário lançado para a obra ativa.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: diariesDesc.length + 2,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _openDataAnalysis,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Análise de dados'),
                  ),
                );
              }

              if (index == 1) {
                return _ProjectTimelineCard(summary: timelineSummary);
              }

              final diary = diariesDesc[index - 2];
              final diaryNumber = diaryNumberById[diary.id] ?? 0;
              final climateMorning = _resolveClimateMorning(diary);
              final climateAfternoon = _resolveClimateAfternoon(diary);
              final totalPeople = _countTotalPeople(diary);
              final frentes = _countFrentes(diary);

              return Card(
                child: ListTile(
                  title: Text('Diário $diaryNumber • ${_formatDate(diary.date)}'),
                  subtitle: Text(
                    'Clima: $climateMorning | $climateAfternoon • Pessoas: $totalPeople • Frentes: $frentes',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDiary(diary: diary),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProjectTimelineSummary {
  const _ProjectTimelineSummary({
    required this.projectId,
    required this.startedAt,
    required this.expectedEndAt,
    required this.today,
  });

  final String? projectId;
  final DateTime? startedAt;
  final DateTime? expectedEndAt;
  final DateTime today;

  bool get hasTimelineConfigured => startedAt != null && expectedEndAt != null;

  int? get elapsedDays {
    if (!hasTimelineConfigured) return null;
    if (today.isBefore(startedAt!)) return 0;
    return today.difference(startedAt!).inDays;
  }

  int? get remainingDays {
    if (!hasTimelineConfigured) return null;
    if (today.isAfter(expectedEndAt!)) return 0;
    return expectedEndAt!.difference(today).inDays;
  }
}

class _ProjectTimelineCard extends StatelessWidget {
  const _ProjectTimelineCard({required this.summary});

  final _ProjectTimelineSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final configured = summary.hasTimelineConfigured;
    final message = configured
        ? 'Prazo da obra • Dias decorridos: ${summary.elapsedDays} • Dias restantes: ${summary.remainingDays}'
        : 'Prazo da obra: configure data inicial e previsão final para habilitar contagem de dias.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_outlined, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

