// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_time_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackTimeAdapter extends TypeAdapter<TrackTime> {
  @override
  final int typeId = 2;

  @override
  TrackTime read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrackTime(
      id: fields[0] as String,
      startTime: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TrackTime obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackTimeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
