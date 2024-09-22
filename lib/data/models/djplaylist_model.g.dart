// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'djplaylist_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DJPlaylistAdapter extends TypeAdapter<DJPlaylist> {
  @override
  final int typeId = 0;

  @override
  DJPlaylist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DJPlaylist(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      spotifyUri: fields[3] as String,
      autoNext: fields[4] as bool,
      shuffleAtEnd: fields[5] as bool,
      currentTrack: fields[6] as int,
      playCount: fields[7] as int,
      trackIds: (fields[8] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DJPlaylist obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.spotifyUri)
      ..writeByte(4)
      ..write(obj.autoNext)
      ..writeByte(5)
      ..write(obj.shuffleAtEnd)
      ..writeByte(6)
      ..write(obj.currentTrack)
      ..writeByte(7)
      ..write(obj.playCount)
      ..writeByte(8)
      ..write(obj.trackIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DJPlaylistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StringList _$StringListFromJson(Map<String, dynamic> json) => StringList(
      (json['items'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$StringListToJson(StringList instance) =>
    <String, dynamic>{
      'items': instance.items,
    };

DJPlaylist _$DJPlaylistFromJson(Map<String, dynamic> json) => DJPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      spotifyUri: json['spotifyUri'] as String,
      autoNext: json['autoNext'] as bool,
      shuffleAtEnd: json['shuffleAtEnd'] as bool,
      currentTrack: (json['currentTrack'] as num?)?.toInt() ?? 0,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      trackIds:
          (json['trackIds'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$DJPlaylistToJson(DJPlaylist instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'spotifyUri': instance.spotifyUri,
      'autoNext': instance.autoNext,
      'shuffleAtEnd': instance.shuffleAtEnd,
      'currentTrack': instance.currentTrack,
      'playCount': instance.playCount,
      'trackIds': instance.trackIds,
    };
