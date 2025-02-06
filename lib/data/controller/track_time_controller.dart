import 'package:djsports/data/repo/track_time_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:djsports/data/models/track_time_model.dart';

final trackTimeRepositoryProvider =
    Provider<TrackTimeRepo>((ref) => TrackTimeRepo());

class TrackTimeHive extends StateNotifier<List<TrackTime>?> {
  TrackTimeHive(this.ref) : super(null) {
    /// Repository Todo Service Provider
    repo = ref.read(trackTimeRepositoryProvider);
    fetchTrackTimes();
  }
  late TrackTimeRepo? repo;
  final Ref ref;

  ///fetch all todo from to local Storage

  void fetchTrackTimes() {
    state = repo!.getTrackTimes();
  }

  List<String> getTrackTimesById(List<String> trackIds) {
    if (repo == null) {
      return [];
    }
    final trackTimes = repo!
        .getTrackTimes()
        .where((element) => trackIds.contains(element.id))
        .toList();
    for (var trackTime in trackTimes) {
      if (trackTime.id.isNotEmpty) {
        return trackTimes.map((e) => e.id).toList();
      }
    }
    return [];
  }

  bool existsTrackTime(String trackId) {
    final allTrackTimes = repo!.getTrackTimes();
    return allTrackTimes.any((track) => track.id == trackId);
  }

  List<TrackTime> getTrackTimesByIds(List<String> trackIds) {
    final allTrackTimes = repo!.getTrackTimes();
    return trackIds
        .map((id) => allTrackTimes.firstWhere(
              (track) => track.id == id,
              orElse: () => TrackTime(id: '', startTime: 0, startTimeMS: 0),
            ))
        .where((track) => track.id.isNotEmpty)
        .toList();
  }

  void addTrackTime(TrackTime trackTime) {
    if (trackTime.id.isEmpty) {
      throw Exception('Missing id');
    }
    final existingTrackTimes = repo!.getTrackTimes();
    if (existingTrackTimes.any((track) => track.id == trackTime.id)) {
      return;
    }
    state = repo!.addTrackTime(trackTime);
  }

  void removeTrackTime(String id) {
    state = repo!.removeTrackTime(id);
  }

  ///Update  current todo from local Storage

  void updateTrackTime(TrackTime trackTime) {
    state = repo!.updateTrackTime(trackTime);
  }

  List<TrackTime> getAllTrackTimes() {
    List<TrackTime> trackTimes = [];
    if (state != null) {
      for (var track in state!) {
        trackTimes.add(track);
      }
    }
    return trackTimes;
  }
}
