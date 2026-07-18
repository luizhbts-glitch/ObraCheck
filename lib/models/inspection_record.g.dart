// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspection_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

int _safeHiveInt(dynamic value, String field, {int fallback = 0}) {
  if (value == null) {
    if (AppLog.enableSyncLogs) {
      debugPrint('[SYNC][NULL_INT_FIX] campo=$field origem=Hive valor=null fallback=$fallback');
    }
    return fallback;
  }
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value.toString());
  if (parsed != null) return parsed;
  if (AppLog.enableSyncLogs) {
    debugPrint('[SYNC][NULL_INT_FIX] campo=$field origem=Hive valor_invalido="$value" fallback=$fallback');
  }
  return fallback;
}

class InspectionRecordAdapter extends TypeAdapter<InspectionRecord> {
  @override
  final int typeId = 1;

  @override
  InspectionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InspectionRecord(
      obra: fields[0] as String,
      torre: fields[1] as String,
      andar: _safeHiveInt(fields[2], 'InspectionRecord.andar', fallback: 0),
      apto: fields[3] as String,
      fvsCodigo: fields[4] as String,
      fvsNome: fields[5] as String,
      itens: ((fields[6] as List?) ?? const <InspectionItemResult>[])
          .cast<InspectionItemResult>(),
      createdAt: fields[7] as DateTime,
      id: fields[8] as String,
      updatedAt: fields[9] as DateTime,
      status: fields[10] as String,
      finalizedAt: fields[11] as DateTime?,
      localRef: fields[12] as String?,
      locked: fields[13] as bool?,
      lockedAt: fields[14] as DateTime?,
      actionType: fields[15] as String?,
      actionByUid: fields[16] as String?,
      actionByName: fields[17] as String?,
      actionByCargo: fields[18] as String?,
      actionAt: fields[19] as DateTime?,
      deleted: (fields[20] as bool?) ?? false,
      pendingSync: (fields[21] as bool?) ?? false,
      deletedAt: fields[22] as DateTime?,
      ncCompanyId: fields[23] as String?,
      ncCompanyName: fields[24] as String?,
      inspectionElement: fields[25] as String?,
      projectId: (fields[26] as String?) ?? kLegacyProjectId,
      operationalSheetId: fields[27] as String?,
      operationalSheetLabel: fields[28] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InspectionRecord obj) {
    writer
      ..writeByte(29)
      ..writeByte(0)
      ..write(obj.obra)
      ..writeByte(1)
      ..write(obj.torre)
      ..writeByte(2)
      ..write(obj.andar)
      ..writeByte(3)
      ..write(obj.apto)
      ..writeByte(4)
      ..write(obj.fvsCodigo)
      ..writeByte(5)
      ..write(obj.fvsNome)
      ..writeByte(6)
      ..write(obj.itens)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.id)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.finalizedAt)
      ..writeByte(12)
      ..write(obj.localRef)
      ..writeByte(13)
      ..write(obj.locked)
      ..writeByte(14)
      ..write(obj.lockedAt)
      ..writeByte(15)
      ..write(obj.actionType)
      ..writeByte(16)
      ..write(obj.actionByUid)
      ..writeByte(17)
      ..write(obj.actionByName)
      ..writeByte(18)
      ..write(obj.actionByCargo)
      ..writeByte(19)
      ..write(obj.actionAt)
      ..writeByte(20)
      ..write(obj.deleted)
      ..writeByte(21)
      ..write(obj.pendingSync)
      ..writeByte(22)
      ..write(obj.deletedAt)
      ..writeByte(23)
      ..write(obj.ncCompanyId)
      ..writeByte(24)
      ..write(obj.ncCompanyName)
      ..writeByte(25)
      ..write(obj.inspectionElement)
      ..writeByte(26)
      ..write(obj.projectId)
      ..writeByte(27)
      ..write(obj.operationalSheetId)
      ..writeByte(28)
      ..write(obj.operationalSheetLabel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InspectionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InspectionItemResultAdapter extends TypeAdapter<InspectionItemResult> {
  @override
  final int typeId = 2;

  @override
  InspectionItemResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InspectionItemResult(
      index: _safeHiveInt(fields[0], 'InspectionItemResult.index', fallback: 0),
      descricao: fields[1] as String,
      dica: fields[2] as String,
      status: fields[3] as String,
      obs: fields[4] as String,
      photoPaths: ((fields[5] as List?) ?? const <String>[]).cast<String>(),
      photos: ((fields[6] as List?) ?? const <InspectionPhotoData>[])
          .cast<InspectionPhotoData>(),
      ncCompanyId: fields[7] as String?,
      ncCompanyName: fields[8] as String?,
      proofType: (fields[9] as String?) ?? InspectionItemResult.proofVisual,
      requiresPhoto: (fields[10] as bool?) ?? false,
      measuredValue: fields[11] as double?,
      measuredUnit: fields[12] as String?,
      technicalNote: fields[13] as String?,
      sampledLocations: ((fields[14] as List?) ?? const <String>[]).cast<String>(),
      measurementToleranceMin: fields[15] as double?,
      measurementToleranceMax: fields[16] as double?,
      requiresTechnicalNote: (fields[17] as bool?) ?? false,
      supportsSampling: (fields[18] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, InspectionItemResult obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.index)
      ..writeByte(1)
      ..write(obj.descricao)
      ..writeByte(2)
      ..write(obj.dica)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.obs)
      ..writeByte(5)
      ..write(obj.photoPaths)
      ..writeByte(6)
      ..write(obj.photos)
      ..writeByte(7)
      ..write(obj.ncCompanyId)
      ..writeByte(8)
      ..write(obj.ncCompanyName)
      ..writeByte(9)
      ..write(obj.proofType)
      ..writeByte(10)
      ..write(obj.requiresPhoto)
      ..writeByte(11)
      ..write(obj.measuredValue)
      ..writeByte(12)
      ..write(obj.measuredUnit)
      ..writeByte(13)
      ..write(obj.technicalNote)
      ..writeByte(14)
      ..write(obj.sampledLocations)
      ..writeByte(15)
      ..write(obj.measurementToleranceMin)
      ..writeByte(16)
      ..write(obj.measurementToleranceMax)
      ..writeByte(17)
      ..write(obj.requiresTechnicalNote)
      ..writeByte(18)
      ..write(obj.supportsSampling);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InspectionItemResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InspectionPhotoDataAdapter extends TypeAdapter<InspectionPhotoData> {
  @override
  final int typeId = 5;

  @override
  InspectionPhotoData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InspectionPhotoData(
      photoUrl: fields[0] as String,
      storagePath: fields[1] as String,
      localPath: fields[2] as String,
      pendingSync: fields[3] as bool,
      syncError: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InspectionPhotoData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.photoUrl)
      ..writeByte(1)
      ..write(obj.storagePath)
      ..writeByte(2)
      ..write(obj.localPath)
      ..writeByte(3)
      ..write(obj.pendingSync)
      ..writeByte(4)
      ..write(obj.syncError);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InspectionPhotoDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
