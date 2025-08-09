import 'package:hive/hive.dart';
import 'package:spotify/spotify.dart';
import 'package:uuid/uuid.dart';
import 'package:json_annotation/json_annotation.dart';
//import 'package:spotify/src/models/_models.dart' as spotify;

part 'djtrack_model.g.dart';

const String djtrackBoxName = 'djtrack';

@HiveType(typeId: 1)
@JsonSerializable()
class DJTrack extends HiveObject {
  DJTrack({
    required this.id,
    required this.name,
    required this.album,
    required this.artist,
    required this.startTime,
    required this.startTimeMS,
    required this.duration,
    required this.playCount,
    required this.spotifyUri,
    required this.mp3Uri,
    required this.networkImageUri,
    this.shortcut = '',
  });

  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String album;
  @HiveField(3)
  String artist;
  @HiveField(4)
  int startTime;
  @HiveField(5)
  int startTimeMS;
  @HiveField(6)
  int duration;
  @HiveField(7)
  int playCount;
  @HiveField(8)
  String spotifyUri;
  @HiveField(9)
  String mp3Uri;
  @HiveField(10, defaultValue: '')
  String networkImageUri;

  @HiveField(11, defaultValue: '')
  String shortcut;

  factory DJTrack.fromJson(Map<String, dynamic> json) =>
      _$DJTrackFromJson(json);

  factory DJTrack.empty() => DJTrack(
        id: '',
        name: '',
        album: '',
        artist: '',
        startTime: 0,
        startTimeMS: 0,
        duration: 0,
        playCount: 0,
        spotifyUri: '',
        mp3Uri: '',
        networkImageUri: '',
        shortcut: '',
      );

  factory DJTrack.simple({
    required String name,
    required String album,
    required String artist,
    String spotifyUri = 'spotify:track:2USlegnFJLrVLpoVfPimKB',
  }) =>
      DJTrack(
        id: const Uuid().v4(),
        name: name,
        album: album,
        artist: artist,
        startTime: 0,
        startTimeMS: 0,
        duration: 0,
        playCount: 0,
        spotifyUri: spotifyUri,
        mp3Uri: '',
        networkImageUri: '',
        shortcut: '',
      );

  Map<String, dynamic> toJson() => _$DJTrackToJson(this);

  @override
  String toString() {
    return 'DJTRACK: $name: $name by $artist from $album';
  }

  String getStartTimeFormatted() {
    int tempStartTime = startTime;

    int minutes = tempStartTime ~/ 60;
    int remainSec = (tempStartTime % 60);
    return ('${minutes.toString().padLeft(2, '0')}:${remainSec.toString().padLeft(2, '0')}');
  }

  String formatMillisecondsAsMMSS(int milliseconds) {
    int minutes = milliseconds ~/ 60;
    int remainSec = (milliseconds % 60);
    return ('${minutes.toString().padLeft(2, '0')}:${remainSec.toString().padLeft(2, '0')}');
  }

  static DJTrack fromSpotifyTrack(Track track) {
    String networkImageUri = track.album?.images?.first.url ?? '';

    String albumName = '';
    if (track.album != null) {
      albumName = track.album!.name!;
    }

    int duration = track.durationMs ?? 0;

    return DJTrack(
      id: track.id!,
      name: track.name!,
      album: albumName,
      artist: track.artists!.first.name!,
      startTime: 0,
      startTimeMS: 0,
      duration: duration,
      playCount: 0,
      spotifyUri: track.uri!,
      mp3Uri: '',
      networkImageUri: networkImageUri,
      shortcut: '',
    );
  }
}
