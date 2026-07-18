enum InspectionRecordStatus {
  draft,
  finalStatus,
}

InspectionRecordStatus inspectionStatusFromStorage(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'draft':
      return InspectionRecordStatus.draft;
    case 'final':
    case 'finalized':
      return InspectionRecordStatus.finalStatus;
    default:
      return InspectionRecordStatus.draft;
  }
}

String inspectionStatusToStorage(InspectionRecordStatus status) {
  switch (status) {
    case InspectionRecordStatus.draft:
      return 'draft';
    case InspectionRecordStatus.finalStatus:
      return 'final';
  }
}

