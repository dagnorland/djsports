import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DJPlaylistRepo {
  late Box<DJPlaylist> _hive;
  late List<DJPlaylist> _box;
  DJPlaylistRepo();

  List<DJPlaylist> getDJPlaylists() {
    _hive = Hive.box<DJPlaylist>(djplaylistBoxName);
    _box = _hive.values.toList();
    return _box;
  }

  List<DJPlaylist> addDJPlaylist(DJPlaylist playlist) {
    _hive.add(playlist);
    return _hive.values.toList();
  }

  List<DJPlaylist> removeDJPlaylist(String id) {
    _hive.deleteAt(
        _hive.values.toList().indexWhere((element) => element.id == id));
    return _hive.values.toList();
  }

  List<DJPlaylist> updateDJPlaylist(DJPlaylist playlist) {
    final index = _hive.values
        .toList()
        .indexWhere((element) => element.id == playlist.id);
    _hive.putAt(index, playlist);
    return _hive.values.toList();
  }

  void deleteAll() {
    _hive.clear();
  }
}
