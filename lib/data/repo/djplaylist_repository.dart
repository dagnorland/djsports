import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class DJPlaylistRepo {
  late Box<DJPlaylist> _hive;
  late List<DJPlaylist> _box;
  DJPlaylistRepo();

  DJPlaylist getDJPlaylist(String id) {
    return _hive.values.toList().firstWhere((element) => element.id == id);
  }

  List<DJPlaylist> getDJPlaylists() {
    _hive = Hive.box<DJPlaylist>(djplaylistBoxName);
    _box = _hive.values.toList();
    return _box;
  }

  List<DJPlaylist> addDJPlaylist(DJPlaylist playlist) {
    // do we have any listlist with same spotify uri
    if (_hive.values
        .any((element) => element.spotifyUri == playlist.spotifyUri)) {
      DJPlaylist existingPlaylist = _hive.values
          .firstWhere((element) => element.spotifyUri == playlist.spotifyUri);
      throw Exception(
          'Playlist ${existingPlaylist.name} has same spotify uri ');
    }

    if (playlist.id.isEmpty) {
      playlist.id = const Uuid().v4();
    }
    _hive.add(playlist);
    return _hive.values.toList();
  }

  List<DJPlaylist> removeDJPlaylist(String id) {
    _hive.deleteAt(
        _hive.values.toList().indexWhere((element) => element.id == id));
    return _hive.values.toList();
  }

  DJPlaylist removeDJTrackFromPlaylist(String playlistId, String trackId) {
    DJPlaylist playlist =
        _hive.values.toList().firstWhere((element) => element.id == playlistId);

    playlist.trackIds.removeWhere((element) => element == trackId);
    return updateDJPlaylist(playlist);
  }

  DJPlaylist updateDJPlaylist(DJPlaylist playlist) {
    final index = _hive.values
        .toList()
        .indexWhere((element) => element.id == playlist.id);
    _hive.putAt(index, playlist);
    return _hive.values
        .toList()
        .firstWhere((element) => element.id == playlist.id);
  }

  void deleteAll() {
    _hive.clear();
  }
}
