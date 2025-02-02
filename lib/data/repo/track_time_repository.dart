import 'package:djsports/data/models/track_time_model.dart';
import 'package:hive/hive.dart';

class TrackTimeRepo {
  late Box<TrackTime> _hive;
  late List<TrackTime> _box;

  TrackTimeRepo();

  List<TrackTime> getTrackTimes() {
    _hive = Hive.box<TrackTime>(trackTimeBoxName);
    _box = _hive.values.toList();
    return _box;
  }

  TrackTime getTrackTime(String id) {
    return _hive.values.toList().firstWhere((element) => element.id == id);
  }

  List<TrackTime> addTrackTime(TrackTime time) {
    _hive.add(time);
    return _hive.values.toList();
  }

  List<TrackTime> removeTrackTime(String id) {
    _hive.deleteAt(
      _hive.values.toList().indexWhere((element) => element.id == id),
    );
    return _hive.values.toList();
  }

  List<TrackTime> updateTrackTime(TrackTime time) {
    final index =
        _hive.values.toList().indexWhere((element) => element.id == time.id);
    _hive.putAt(index, time);
    return _hive.values.toList();
  }

  void deleteAll() {
    _hive.clear();
  }
}
