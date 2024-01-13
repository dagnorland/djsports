// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'djtrack_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DJTrackAdapter extends TypeAdapter<DJTrack> {
  @override
  final int typeId = 1;

  @override
  DJTrack read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DJTrack(
      id: fields[0] as String,
      name: fields[1] as String,
      album: fields[2] as String,
      artist: fields[3] as String,
      startTime: fields[4] as int,
      startTimeMS: fields[5] as int,
      duration: fields[6] as int,
      playCount: fields[7] as int,
      spotifyUri: fields[8] as String,
      mp3Path: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DJTrack obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.album)
      ..writeByte(3)
      ..write(obj.artist)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.startTimeMS)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.playCount)
      ..writeByte(8)
      ..write(obj.spotifyUri)
      ..writeByte(9)
      ..write(obj.mp3Path);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DJTrackAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DJTrack _$DJTrackFromJson(Map<String, dynamic> json) => DJTrack(
      id: json['id'] as String,
      name: json['name'] as String,
      album: json['album'] as String,
      artist: json['artist'] as String,
      startTime: json['startTime'] as int,
      startTimeMS: json['startTimeMS'] as int,
      duration: json['duration'] as int,
      playCount: json['playCount'] as int,
      spotifyUri: json['spotifyUri'] as String,
      mp3Path: json['mp3Path'] as String,
    );

Map<String, dynamic> _$DJTrackToJson(DJTrack instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'album': instance.album,
      'artist': instance.artist,
      'startTime': instance.startTime,
      'startTimeMS': instance.startTimeMS,
      'duration': instance.duration,
      'playCount': instance.playCount,
      'spotifyUri': instance.spotifyUri,
      'mp3Path': instance.mp3Path,
    };
