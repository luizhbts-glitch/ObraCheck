import '../models/inspection_record.dart';

class OpenNcEntry {
  final InspectionRecord record;
  final InspectionItemResult item;

  OpenNcEntry({required this.record, required this.item});
}

bool _isNok(InspectionItemResult item) => item.status == 'nok';

String _normalizeText(String? raw) {
  return (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _locationKey(InspectionRecord record) {
  final ref = (record.localRef ?? '').trim();
  final apto = record.apto.trim();
  final locationBase = ref.isNotEmpty ? ref : apto;
  final element = record.normalizedInspectionElement;
  return '${_normalizeText(record.torre)}|${_normalizeText(locationBase)}|${_normalizeText(element)}';
}

DateTime _inspectionBusinessDate(InspectionRecord record) {
  return (record.isDraft ? record.createdAt : record.businessDate).toLocal();
}

String _dayKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

int countOpenNcRecords(List<InspectionRecord> records) {
  return records.where((r) => r.itens.any(_isNok)).length;
}

int countOpenNcItems(List<InspectionRecord> records) {
  return records.fold<int>(0, (acc, r) => acc + r.itens.where(_isNok).length);
}

int countOpenNcItemsUnique(List<InspectionRecord> records) {
  final latestByKey = <String, DateTime>{};

  for (final record in records) {
    if (record.deleted) continue;
    for (final item in record.itens.where(_isNok)) {
      final key = '${_normalizeText(record.projectId)}|'
          '${_normalizeText(record.fvsCodigo)}|'
          '${_locationKey(record)}|'
          '${_normalizeText(item.descricao)}';
      final currentDate = _inspectionBusinessDate(record);
      final previousDate = latestByKey[key];
      if (previousDate == null || currentDate.isAfter(previousDate)) {
        latestByKey[key] = currentDate;
      }
    }
  }

  return latestByKey.length;
}

int countUniqueInspectionsByFvsLocationDay(Iterable<InspectionRecord> records) {
  final latestByKey = <String, DateTime>{};
  for (final record in records) {
    if (record.deleted) continue;
    final businessDate = _inspectionBusinessDate(record);
    final key = '${_normalizeText(record.projectId)}|'
        '${_normalizeText(record.fvsCodigo)}|'
        '${_locationKey(record)}|'
        '${_dayKey(businessDate)}';
    final previousDate = latestByKey[key];
    if (previousDate == null || businessDate.isAfter(previousDate)) {
      latestByKey[key] = businessDate;
    }
  }
  return latestByKey.length;
}

List<OpenNcEntry> getOpenNcList(List<InspectionRecord> records) {
  final out = <OpenNcEntry>[];
  for (final r in records) {
    for (final item in r.itens.where(_isNok)) {
      out.add(OpenNcEntry(record: r, item: item));
    }
  }
  return out;
}

