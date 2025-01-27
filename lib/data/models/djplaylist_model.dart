import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'djplaylist_model.g.dart';

const String djplaylistBoxName = "djplaylist";
const String djplaylistTracksBoxName = "djplaylisttracks";
const String musicCenterBoxName = "musiccenterbox";

// Make a DJPlaylisttype with enums hotspot, match, fun_stuff, pre_match, archived
enum DJPlaylistType { all, hotspot, match, funStuff, preMatch, archived }

extension TypeExtension on DJPlaylistType {
  String get type {
    String type;
    switch (this) {
      case DJPlaylistType.hotspot:
        type = 'hotspot';
        break;
      case DJPlaylistType.match:
        type = 'match';
        break;
      case DJPlaylistType.funStuff:
        type = 'fun stuff';
        break;
      case DJPlaylistType.preMatch:
        type = 'pre match';
        break;
      case DJPlaylistType.archived:
        type = 'archived';
        break;
      case DJPlaylistType.all:
        type = "all";
        break;
    }
    return type;
  }
}

extension TypeColor on DJPlaylistType {
  Color get color {
    Color color;
    switch (this) {
      case DJPlaylistType.hotspot:
        color = Colors.red;
        break;
      case DJPlaylistType.match:
        color = Colors.green;
        break;
      case DJPlaylistType.funStuff:
        color = Colors.blue;
        break;
      case DJPlaylistType.preMatch:
        color = Colors.black;
        break;
      case DJPlaylistType.archived:
        color = Colors.greenAccent;
        break;
      case DJPlaylistType.all:
        color = Colors.black;
        break;
    }
    return color;
  }
}

@JsonSerializable()
class StringList {
  List<String> items = [];
  StringList(this.items);

  factory StringList.fromJson(Map<String, dynamic> json) =>
      _$StringListFromJson(json);

  Map<String, dynamic> toJson() => _$StringListToJson(this);
}

@HiveType(typeId: 0)
@JsonSerializable()
class DJPlaylist extends HiveObject {
  DJPlaylist(
      {required this.id,
      required this.name,
      required this.type,
      required this.spotifyUri,
      required this.autoNext,
      required this.shuffleAtEnd,
      this.currentTrack = 0,
      this.playCount = 0,
      required this.trackIds,
      this.position = 0}); // = const Uuid().v4();

  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String type;
  @HiveField(3)
  String spotifyUri;
  @HiveField(4)
  bool autoNext;
  @HiveField(5)
  bool shuffleAtEnd;
  @HiveField(6)
  int currentTrack;
  @HiveField(7)
  int playCount;
  @HiveField(8)
  List<String> trackIds;
  @HiveField(9, defaultValue: 0)
  int position;

  factory DJPlaylist.simple(String id, String name, DJPlaylistType type) =>
      DJPlaylist(
        id: id,
        name: name,
        type: type.name,
        playCount: 0,
        autoNext: true,
        shuffleAtEnd: false,
        trackIds: [],
        spotifyUri:
            'spotify:playlist:18SMKqQEhQvRgD6RdoVGp1?si=43ea45edc7074725',
      );

  factory DJPlaylist.fromJson(Map<String, dynamic> json) =>
      _$DJPlaylistFromJson(json);

  Map<String, dynamic> toJson() => _$DJPlaylistToJson(this);

  DJPlaylist addTrack(String trackId) {
    trackIds.add(trackId);
    return this;
  }

  void setCurrentTrack(String trackId) {
    debugPrint(
        'setCurrentTrack $trackId in plalist $name - we have ${trackIds.length.toString()} tracks');
    currentTrack = trackIds.indexOf(trackId);
  }
}

/*

final djPlaylist = await Hive.box<DJPlaylistWithTracks>(‘dj_playlists_with_tracks’).get(KEY_OF_PLAYLIST);
  final track1 = DJTrack(‘…’);
  final track2 = DJTrack(‘…’);
  final track3 = DJTrack(‘…’);
 djPlaylist.tracks = HiveList([track1, track2, track3])

*/
