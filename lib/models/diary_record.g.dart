// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DiaryServiceEntryAdapter extends TypeAdapter<DiaryServiceEntry> {
  @override
  final int typeId = 8;

  @override
  DiaryServiceEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiaryServiceEntry(
      id: fields[0] as String,
      companyId: fields[1] as String,
      companyName: fields[2] as String,
      localRef: fields[3] as String,
      localLabel: fields[4] as String,
      peopleCount: fields[5] as int,
      serviceStatus: fields[6] as String,
      note: fields[7] as String,
      photos: (fields[8] as List).cast<InspectionPhotoData>(),
      fvsCodigo: fields[9] as String,
      fvsNome: fields[10] as String,
      tower: fields[11] as String,
      floor: fields[12] as int,
      apartment: fields[13] as String,
      locationType: fields[14] as String,
      locationContext: fields[15] as String,
      inspectionElement: fields[16] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DiaryServiceEntry obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.companyId)
      ..writeByte(2)
      ..write(obj.companyName)
      ..writeByte(3)
      ..write(obj.localRef)
      ..writeByte(4)
      ..write(obj.localLabel)
      ..writeByte(5)
      ..write(obj.peopleCount)
      ..writeByte(6)
      ..write(obj.serviceStatus)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.photos)
      ..writeByte(9)
      ..write(obj.fvsCodigo)
      ..writeByte(10)
      ..write(obj.fvsNome)
      ..writeByte(11)
      ..write(obj.tower)
      ..writeByte(12)
      ..write(obj.floor)
      ..writeByte(13)
      ..write(obj.apartment)
      ..writeByte(14)
      ..write(obj.locationType)
      ..writeByte(15)
      ..write(obj.locationContext)
      ..writeByte(16)
      ..write(obj.inspectionElement);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryServiceEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DiaryOwnLaborEntryAdapter extends TypeAdapter<DiaryOwnLaborEntry> {
  @override
  final int typeId = 9;

  @override
  DiaryOwnLaborEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiaryOwnLaborEntry(
      id: fields[0] as String,
      role: fields[1] as String,
      peopleCount: fields[2] as int,
      orderIndex: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DiaryOwnLaborEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.peopleCount)
      ..writeByte(3)
      ..write(obj.orderIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryOwnLaborEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DiaryRecordAdapter extends TypeAdapter<DiaryRecord> {
  @override
  final int typeId = 10;

  @override
  DiaryRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiaryRecord(
      id: fields[0] as String,
      projectId: fields[1] as String,
      obra: fields[2] as String,
      date: fields[3] as DateTime,
      climate: fields[4] as String,
      generalNotes: fields[5] as String,
      serviceEntries: (fields[6] as List).cast<DiaryServiceEntry>(),
      ownLaborEntries: (fields[7] as List).cast<DiaryOwnLaborEntry>(),
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
      deleted: fields[10] as bool,
      pendingSync: fields[11] as bool,
      deletedAt: fields[12] as DateTime?,
      generalPhotos: (fields[13] as List).cast<InspectionPhotoData>(),
      climateMorning: fields[14] as String,
      climateAfternoon: fields[15] as String,
      rentedMachinery: fields[16] as String,
      rentedEquipment: fields[17] as String,
      createdByName: fields[18] as String,
      approvedByName: fields[19] as String,
      approvalStatus: fields[20] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DiaryRecord obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.obra)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.climate)
      ..writeByte(5)
      ..write(obj.generalNotes)
      ..writeByte(6)
      ..write(obj.serviceEntries)
      ..writeByte(7)
      ..write(obj.ownLaborEntries)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.deleted)
      ..writeByte(11)
      ..write(obj.pendingSync)
      ..writeByte(12)
      ..write(obj.deletedAt)
      ..writeByte(13)
      ..write(obj.generalPhotos)
      ..writeByte(14)
      ..write(obj.climateMorning)
      ..writeByte(15)
      ..write(obj.climateAfternoon)
      ..writeByte(16)
      ..write(obj.rentedMachinery)
      ..writeByte(17)
      ..write(obj.rentedEquipment)
      ..writeByte(18)
      ..write(obj.createdByName)
      ..writeByte(19)
      ..write(obj.approvedByName)
      ..writeByte(20)
      ..write(obj.approvalStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
