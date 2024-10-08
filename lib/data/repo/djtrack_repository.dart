import 'package:djsports/data/models/djtrack_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DJTrackRepo {
  late Box<DJTrack> _hive;
  late List<DJTrack> _box;
  DJTrackRepo();

  List<DJTrack> getDJTracks() {
    _hive = Hive.box<DJTrack>(djtrackBoxName);
    _box = _hive.values.toList();
    return _box;
  }

  DJTrack getDJTrack(String id) {
    return _hive.values.toList().firstWhere((element) => element.id == id);
  }

  List<DJTrack> addDJTrack(DJTrack track) {
    _hive.add(track);
    return _hive.values.toList();
  }

  List<DJTrack> removeDJTrack(String id) {
    _hive.deleteAt(
        _hive.values.toList().indexWhere((element) => element.id == id));
    return _hive.values.toList();
  }

  List<DJTrack> updateDJTrack(DJTrack track) {
    final index =
        _hive.values.toList().indexWhere((element) => element.id == track.id);
    _hive.putAt(index, track);
    return _hive.values.toList();
  }

  void deleteAll() {
    _hive.clear();
  }
}
