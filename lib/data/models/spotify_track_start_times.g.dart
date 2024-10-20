// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spotify_track_start_times.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SpotifyTrackStartTimeImpl _$$SpotifyTrackStartTimeImplFromJson(
        Map<String, dynamic> json) =>
    _$SpotifyTrackStartTimeImpl(
      uri: json['uri'] as String,
      startTime: (json['startTime'] as num).toInt(),
    );

Map<String, dynamic> _$$SpotifyTrackStartTimeImplToJson(
        _$SpotifyTrackStartTimeImpl instance) =>
    <String, dynamic>{
      'uri': instance.uri,
      'startTime': instance.startTime,
    };
