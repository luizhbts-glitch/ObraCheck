import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/inspection_record.dart';
import '../utils/project_scope.dart';
import '../utils/nc_utils.dart';

enum DuplicateCleanupMode {
  safeKeepLatest,
  aggressiveDeleteAll,
}

class InspectionDuplicateCleanupService {
  InspectionDuplicateCleanupService._();

  static final InspectionDuplicateCleanupService instance =
      InspectionDuplicateCleanupService._();

  Future<InspectionDuplicateCleanupPreview> previewCleanup({
    String? projectId,
    DuplicateCleanupMode mode = DuplicateCleanupMode.safeKeepLatest,
    bool verboseLogs = true,
  }) async {
    final box = Hive.box<InspectionRecord>('inspections');
    final records = _scopedRecords(box: box, projectId: projectId);
    final groups = _buildDuplicateGroups(records, mode: mode);
    final toRemoveIds = groups.expand((g) => g.removeRecordIds).toList();
    final removedRecords = records.where((r) => toRemoveIds.contains(r.id)).toList();

    final backupPayload = {
      'generatedAt': DateTime.now().toIso8601String(),
      'mode': mode.name,
      'projectId': projectId,
      'totalGroups': groups.length,
      'totalToRemove': toRemoveIds.length,
      'records': removedRecords.map((r) => r.toMap()).toList(),
      'groups': groups.map((g) => g.toMap()).toList(),
    };
    final backupJson = const JsonEncoder.withIndent('  ').convert(backupPayload);
    final backupPath = await _tryWriteBackupFile(backupJson);

    final preview = InspectionDuplicateCleanupPreview(
      mode: mode,
      projectId: projectId,
      totalDuplicateGroups: groups.length,
      totalRecordsToRemove: toRemoveIds.length,
      groups: groups,
      backupJson: backupJson,
      backupFilePath: backupPath,
    );

    if (verboseLogs) {
      _logPreview(preview);
    }

    return preview;
  }

  Future<InspectionDuplicateCleanupResult> executeCleanup({
    String? projectId,
    DuplicateCleanupMode mode = DuplicateCleanupMode.safeKeepLatest,
    bool verboseLogs = true,
  }) async {
    final box = Hive.box<InspectionRecord>('inspections');
    final beforeRecords = _scopedRecords(box: box, projectId: projectId);
    final beforeNcOpen = countOpenNcItemsUnique(beforeRecords);
    final beforeToday = _countTodayUnique(beforeRecords);

    final preview = await previewCleanup(
      projectId: projectId,
      mode: mode,
      verboseLogs: verboseLogs,
    );

    var removed = 0;
    for (final group in preview.groups) {
      for (final id in group.removeRecordIds) {
        await box.delete(id);
        removed++;
        if (verboseLogs) {
          debugPrint(
            '[DUPLICATE_CLEANUP][REMOVE] id=$id mode=${mode.name} '
            'groupKey=${group.logicalKey}',
          );
        }
      }
    }

    final afterRecords = _scopedRecords(box: box, projectId: projectId);
    final afterNcOpen = countOpenNcItemsUnique(afterRecords);
    final afterToday = _countTodayUnique(afterRecords);

    final result = InspectionDuplicateCleanupResult(
      preview: preview,
      removedCount: removed,
      beforeOpenNc: beforeNcOpen,
      afterOpenNc: afterNcOpen,
      beforeTodayInspections: beforeToday,
      afterTodayInspections: afterToday,
    );

    if (verboseLogs) {
      debugPrint(
        '[DUPLICATE_CLEANUP][DONE] removed=$removed '
        'groups=${preview.totalDuplicateGroups} '
        'openNc:$beforeNcOpen->$afterNcOpen '
        'today:$beforeToday->$afterToday '
        'mode=${mode.name}',
      );
    }

    return result;
  }

  List<InspectionRecord> _scopedRecords({
    required Box<InspectionRecord> box,
    String? projectId,
  }) {
    final currentProjectId = currentProjectIdOrNull(projectId);
    return box.values.where((record) {
      if (record.deleted) return false;
      if (currentProjectId == null) return true;
      return recordInProjectScope(
        recordProjectId: record.projectId,
        recordObra: record.obra,
        currentProjectId: currentProjectId,
      );
    }).toList();
  }

  List<InspectionDuplicateCleanupGroup> _buildDuplicateGroups(
    List<InspectionRecord> records, {
    required DuplicateCleanupMode mode,
  }) {
    final byKey = <String, List<InspectionRecord>>{};
    for (final record in records) {
      final key = record.logicalBusinessKey();
      byKey.putIfAbsent(key, () => <InspectionRecord>[]).add(record);
    }

    final groups = <InspectionDuplicateCleanupGroup>[];
    for (final entry in byKey.entries) {
      final list = entry.value;
      if (list.length < 2) continue;
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final keepId =
          mode == DuplicateCleanupMode.safeKeepLatest ? list.first.id : null;
      final removeIds = mode == DuplicateCleanupMode.safeKeepLatest
          ? list.skip(1).map((r) => r.id).toList()
          : list.map((r) => r.id).toList();

      final first = list.first;
      groups.add(
        InspectionDuplicateCleanupGroup(
          logicalKey: entry.key,
          fvsCode: first.fvsCodigo,
          fvsName: first.fvsNome,
          location: InspectionRecord.resolveLocationForLogicalKey(
            apto: first.apto,
            localRef: first.localRef,
          ),
          tower: first.torre,
          date: first.businessDate.toLocal(),
          recordIds: list.map((r) => r.id).toList(),
          keptRecordId: keepId,
          removeRecordIds: removeIds,
        ),
      );
    }

    groups.sort((a, b) {
      final dateCmp = b.date.compareTo(a.date);
      if (dateCmp != 0) return dateCmp;
      final fvsCmp = a.fvsCode.toLowerCase().compareTo(b.fvsCode.toLowerCase());
      if (fvsCmp != 0) return fvsCmp;
      return a.location.toLowerCase().compareTo(b.location.toLowerCase());
    });
    return groups;
  }

  int _countTodayUnique(List<InspectionRecord> records) {
    final now = DateTime.now().toLocal();
    final today = records.where((record) {
      final d = record.businessDate.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
    return countUniqueInspectionsByFvsLocationDay(today);
  }

  Future<String?> _tryWriteBackupFile(String backupJson) async {
    if (kIsWeb) return null;
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${baseDir.path}/duplicate_cleanup_backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final now = DateTime.now();
      final fileName =
          'inspection_duplicates_${now.millisecondsSinceEpoch}.json';
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(backupJson);
      return file.path;
    } catch (e) {
      debugPrint('[DUPLICATE_CLEANUP][BACKUP][WARN] Falha ao gravar backup: $e');
      return null;
    }
  }

  void _logPreview(InspectionDuplicateCleanupPreview preview) {
    debugPrint(
      '[DUPLICATE_CLEANUP][PREVIEW] mode=${preview.mode.name} '
      'groups=${preview.totalDuplicateGroups} '
      'toRemove=${preview.totalRecordsToRemove} '
      'backupFile=${preview.backupFilePath ?? 'inline_json'}',
    );
    for (final group in preview.groups) {
      debugPrint('[DUPLICATE_CLEANUP][GROUP]');
      debugPrint('FVS: ${group.fvsCode} - ${group.fvsName}');
      debugPrint('Local: ${group.location}');
      debugPrint('Torre: ${group.tower}');
      debugPrint('Data: ${group.date.toIso8601String()}');
      debugPrint('IDs: ${group.recordIds.join(', ')}');
      debugPrint('Ocorrências: ${group.recordIds.length}');
      debugPrint('Mantido: ${group.keptRecordId ?? 'nenhum (modo agressivo)'}');
      debugPrint('Remover: ${group.removeRecordIds.join(', ')}');
    }
  }
}

class InspectionDuplicateCleanupPreview {
  final DuplicateCleanupMode mode;
  final String? projectId;
  final int totalDuplicateGroups;
  final int totalRecordsToRemove;
  final List<InspectionDuplicateCleanupGroup> groups;
  final String backupJson;
  final String? backupFilePath;

  const InspectionDuplicateCleanupPreview({
    required this.mode,
    required this.projectId,
    required this.totalDuplicateGroups,
    required this.totalRecordsToRemove,
    required this.groups,
    required this.backupJson,
    required this.backupFilePath,
  });
}

class InspectionDuplicateCleanupResult {
  final InspectionDuplicateCleanupPreview preview;
  final int removedCount;
  final int beforeOpenNc;
  final int afterOpenNc;
  final int beforeTodayInspections;
  final int afterTodayInspections;

  const InspectionDuplicateCleanupResult({
    required this.preview,
    required this.removedCount,
    required this.beforeOpenNc,
    required this.afterOpenNc,
    required this.beforeTodayInspections,
    required this.afterTodayInspections,
  });
}

class InspectionDuplicateCleanupGroup {
  final String logicalKey;
  final String fvsCode;
  final String fvsName;
  final String location;
  final String tower;
  final DateTime date;
  final List<String> recordIds;
  final String? keptRecordId;
  final List<String> removeRecordIds;

  const InspectionDuplicateCleanupGroup({
    required this.logicalKey,
    required this.fvsCode,
    required this.fvsName,
    required this.location,
    required this.tower,
    required this.date,
    required this.recordIds,
    required this.keptRecordId,
    required this.removeRecordIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'logicalKey': logicalKey,
      'fvsCode': fvsCode,
      'fvsName': fvsName,
      'location': location,
      'tower': tower,
      'date': date.toIso8601String(),
      'recordIds': recordIds,
      'keptRecordId': keptRecordId,
      'removeRecordIds': removeRecordIds,
    };
  }
}
