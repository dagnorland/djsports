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
      mp3Uri: fields[9] as String,
      networkImageUri: fields[10] == null ? '' : fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DJTrack obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.mp3Uri)
      ..writeByte(10)
      ..write(obj.networkImageUri);
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
      startTime: (json['startTime'] as num).toInt(),
      startTimeMS: (json['startTimeMS'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      playCount: (json['playCount'] as num).toInt(),
      spotifyUri: json['spotifyUri'] as String,
      mp3Uri: json['mp3Uri'] as String,
      networkImageUri: json['networkImageUri'] as String,
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
      'mp3Uri': instance.mp3Uri,
      'networkImageUri': instance.networkImageUri,
    };
