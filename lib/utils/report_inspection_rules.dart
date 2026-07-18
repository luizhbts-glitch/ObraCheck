import '../models/inspection_record.dart';

enum ReportInspectionStatusKind {
  ncOpen,
  ncCorrected,
  draft,
  finalized,
  other,
}

bool isInspectionEligibleForReport(InspectionRecord record) {
  return !record.deleted;
}

DateTime reportInspectionLastActionAt(InspectionRecord record) {
  final updatedOrCreated =
      record.updatedAt.isBefore(record.createdAt) ? record.createdAt : record.updatedAt;
  return (record.finalizedAt ?? record.actionAt ?? updatedOrCreated).toLocal();
}

int reportInspectionNcOpenCount(InspectionRecord record) {
  return record.itens.where((item) => item.status == 'nok').length;
}

bool reportInspectionHasNcCorrected(InspectionRecord record) {
  return record.itens.any((item) => item.status == 'okAfterFix');
}

ReportInspectionStatusKind reportInspectionStatusKind(InspectionRecord record) {
  final ncOpen = reportInspectionNcOpenCount(record);
  if (ncOpen > 0) return ReportInspectionStatusKind.ncOpen;
  if (reportInspectionHasNcCorrected(record)) {
    return ReportInspectionStatusKind.ncCorrected;
  }
  if (record.isDraft) return ReportInspectionStatusKind.draft;
  if (record.isFinalState) return ReportInspectionStatusKind.finalized;
  return ReportInspectionStatusKind.other;
}

String reportInspectionStatusLabel(InspectionRecord record) {
  switch (reportInspectionStatusKind(record)) {
    case ReportInspectionStatusKind.ncOpen:
      return 'NC aberta';
    case ReportInspectionStatusKind.ncCorrected:
      return 'NC corrigida';
    case ReportInspectionStatusKind.draft:
      return 'Rascunho';
    case ReportInspectionStatusKind.finalized:
      return 'Finalizada';
    case ReportInspectionStatusKind.other:
      return 'Sem status';
  }
}
