import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/inspection_record.dart';
import '../utils/project_scope.dart';

class InspectionDuplicateDiagnosisService {
  InspectionDuplicateDiagnosisService._();

  static final InspectionDuplicateDiagnosisService instance =
      InspectionDuplicateDiagnosisService._();

  Future<InspectionDuplicateDiagnosisSummary> diagnoseLocalDuplicates({
    String? projectId,
    Duration nearWindow = const Duration(hours: 2),
    bool verboseLogs = true,
  }) async {
    final box = Hive.box<InspectionRecord>('inspections');
    final currentProjectId = currentProjectIdOrNull(projectId);
    final all = box.values.where((record) {
      if (record.deleted) return false;
      if (currentProjectId == null) return true;
      return recordInProjectScope(
        recordProjectId: record.projectId,
        recordObra: record.obra,
        currentProjectId: currentProjectId,
      );
    }).toList();

    final grouped = <String, List<_DuplicateOccurrence>>{};
    for (final record in all) {
      final businessDate = _businessDate(record);
      for (final item in record.itens) {
        final key = _baseKey(record, item);
        final list = grouped.putIfAbsent(key, () => <_DuplicateOccurrence>[]);
        list.add(
          _DuplicateOccurrence(
            record: record,
            item: item,
            businessDate: businessDate,
          ),
        );
      }
    }

    final duplicateGroups = <InspectionDuplicateGroup>[];
    var totalPendingSyncInDuplicates = 0;

    for (final occurrences in grouped.values) {
      if (occurrences.length < 2) continue;
      occurrences.sort((a, b) => a.businessDate.compareTo(b.businessDate));

      if (!_hasCloseOccurrences(occurrences, nearWindow)) {
        continue;
      }

      final hints = _inferOriginHints(occurrences, nearWindow);
      final group = InspectionDuplicateGroup(
        projectId: occurrences.first.record.projectId,
        fvsCode: occurrences.first.record.fvsCodigo,
        fvsName: occurrences.first.record.fvsNome,
        location: _locationLabel(occurrences.first.record),
        tower: occurrences.first.record.torre,
        itemDescription: occurrences.first.item.descricao,
        occurrences: occurrences
            .map(
              (o) => InspectionDuplicateOccurrence(
                recordId: o.record.id,
                status: o.record.status,
                itemStatus: o.item.status,
                date: o.businessDate,
                updatedAt: o.record.updatedAt,
                actionType: o.record.actionType,
                actionByUid: o.record.actionByUid,
                pendingSync: o.record.pendingSync,
              ),
            )
            .toList(),
        originHints: hints,
      );
      duplicateGroups.add(group);
      totalPendingSyncInDuplicates +=
          group.occurrences.where((o) => o.pendingSync).length;

      if (verboseLogs) {
        _logGroup(group);
      }
    }

    final summary = InspectionDuplicateDiagnosisSummary(
      totalInspectionsAnalyzed: all.length,
      totalItemOccurrencesAnalyzed:
          grouped.values.fold<int>(0, (acc, list) => acc + list.length),
      totalDuplicateGroups: duplicateGroups.length,
      totalDuplicateOccurrences:
          duplicateGroups.fold<int>(0, (acc, g) => acc + g.occurrences.length),
      totalWithPendingSyncInDuplicates: totalPendingSyncInDuplicates,
      groups: duplicateGroups,
    );

    if (verboseLogs) {
      debugPrint(
        '[DUPLICATE][SUMMARY] analyzedInspections=${summary.totalInspectionsAnalyzed} '
        'analyzedItems=${summary.totalItemOccurrencesAnalyzed} '
        'duplicateGroups=${summary.totalDuplicateGroups} '
        'duplicateOccurrences=${summary.totalDuplicateOccurrences} '
        'pendingSyncInDuplicates=${summary.totalWithPendingSyncInDuplicates}',
      );
    }

    return summary;
  }

  void _logGroup(InspectionDuplicateGroup group) {
    final dates = group.occurrences
        .map((o) => o.date.toIso8601String())
        .join(', ');
    final statuses = group.occurrences
        .map((o) => '${o.status}/${o.itemStatus}')
        .join(', ');
    final ids = group.occurrences.map((o) => o.recordId).join(', ');
    final hints = group.originHints.join(', ');

    debugPrint('[DUPLICATE]');
    debugPrint('FVS: ${group.fvsCode} - ${group.fvsName}');
    debugPrint('Local: ${group.location}');
    debugPrint('Torre: ${group.tower}');
    debugPrint('Item: ${group.itemDescription}');
    debugPrint('Ocorrências: ${group.occurrences.length}');
    debugPrint('Datas: [$dates]');
    debugPrint('Status: [$statuses]');
    debugPrint('RecordIds: [$ids]');
    debugPrint('Origem provável: [$hints]');
  }

  bool _hasCloseOccurrences(
    List<_DuplicateOccurrence> occurrences,
    Duration nearWindow,
  ) {
    for (var i = 1; i < occurrences.length; i++) {
      final a = occurrences[i - 1].businessDate;
      final b = occurrences[i].businessDate;
      if (_sameDay(a, b) || b.difference(a).abs() <= nearWindow) {
        return true;
      }
    }
    return false;
  }

  List<String> _inferOriginHints(
    List<_DuplicateOccurrence> occurrences,
    Duration nearWindow,
  ) {
    final hints = <String>{};

    final hasPendingSync = occurrences.any((o) => o.record.pendingSync);
    if (hasPendingSync) {
      hints.add('sync');
    }

    final hasDraft = occurrences.any((o) => o.record.isDraft);
    final hasFinal = occurrences.any((o) => o.record.isFinalState);
    if (hasDraft && hasFinal) {
      hints.add('rascunho+finalizacao');
    }

    final hasReopenedLike = occurrences.any((o) {
      final action = (o.record.actionType ?? '').toLowerCase();
      if (action.contains('reab')) return true;
      return o.record.isDraft &&
          (o.record.finalizedAt != null ||
              o.record.locked == true ||
              action == 'finalizou');
    });
    if (hasReopenedLike) {
      hints.add('reabertura_fvs');
    }

    var hasCloseFinalPair = false;
    for (var i = 1; i < occurrences.length; i++) {
      final prev = occurrences[i - 1];
      final next = occurrences[i];
      if (!prev.record.isFinalState || !next.record.isFinalState) continue;
      final diff = next.businessDate.difference(prev.businessDate).abs();
      if (diff <= nearWindow) {
        hasCloseFinalPair = true;
        break;
      }
    }
    if (hasCloseFinalPair && !hasPendingSync) {
      hints.add('merge');
    }

    if (hints.isEmpty) {
      hints.add('indefinido');
    }

    return hints.toList()..sort();
  }

  DateTime _businessDate(InspectionRecord record) {
    final eventAt = record.isDraft ? record.createdAt : record.businessDate;
    return eventAt.toLocal();
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _baseKey(InspectionRecord record, InspectionItemResult item) {
    return '${_normalize(record.projectId)}|'
        '${_normalize(record.fvsCodigo)}|'
        '${_normalize(_locationLabel(record))}|'
        '${_normalize(item.descricao)}';
  }

  String _locationLabel(InspectionRecord record) {
    final ref = (record.localRef ?? '').trim();
    final apto = record.apto.trim();
    final location = ref.isNotEmpty ? ref : apto;
    final element = record.normalizedInspectionElement;
    if (element.isEmpty) return '${record.torre}|$location';
    return '${record.torre}|$location|$element';
  }

  String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class InspectionDuplicateDiagnosisSummary {
  final int totalInspectionsAnalyzed;
  final int totalItemOccurrencesAnalyzed;
  final int totalDuplicateGroups;
  final int totalDuplicateOccurrences;
  final int totalWithPendingSyncInDuplicates;
  final List<InspectionDuplicateGroup> groups;

  const InspectionDuplicateDiagnosisSummary({
    required this.totalInspectionsAnalyzed,
    required this.totalItemOccurrencesAnalyzed,
    required this.totalDuplicateGroups,
    required this.totalDuplicateOccurrences,
    required this.totalWithPendingSyncInDuplicates,
    required this.groups,
  });
}

class InspectionDuplicateGroup {
  final String projectId;
  final String fvsCode;
  final String fvsName;
  final String location;
  final String tower;
  final String itemDescription;
  final List<InspectionDuplicateOccurrence> occurrences;
  final List<String> originHints;

  const InspectionDuplicateGroup({
    required this.projectId,
    required this.fvsCode,
    required this.fvsName,
    required this.location,
    required this.tower,
    required this.itemDescription,
    required this.occurrences,
    required this.originHints,
  });
}

class InspectionDuplicateOccurrence {
  final String recordId;
  final String status;
  final String itemStatus;
  final DateTime date;
  final DateTime updatedAt;
  final String? actionType;
  final String? actionByUid;
  final bool pendingSync;

  const InspectionDuplicateOccurrence({
    required this.recordId,
    required this.status,
    required this.itemStatus,
    required this.date,
    required this.updatedAt,
    required this.actionType,
    required this.actionByUid,
    required this.pendingSync,
  });
}

class _DuplicateOccurrence {
  final InspectionRecord record;
  final InspectionItemResult item;
  final DateTime businessDate;

  const _DuplicateOccurrence({
    required this.record,
    required this.item,
    required this.businessDate,
  });
}
