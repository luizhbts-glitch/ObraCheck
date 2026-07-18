// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_org_membership.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserOrgMembershipAdapter extends TypeAdapter<UserOrgMembership> {
  @override
  final int typeId = 14;

  @override
  UserOrgMembership read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserOrgMembership(
      id: fields[0] as String,
      userId: fields[1] as String,
      orgId: fields[2] as String,
      role: fields[3] as String,
      isActive: fields[4] as bool,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, UserOrgMembership obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.orgId)
      ..writeByte(3)
      ..write(obj.role)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserOrgMembershipAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
