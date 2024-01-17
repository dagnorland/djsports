import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/repo/djtrack_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final djtrackRepositoryProvider = Provider<DJTrackRepo>((ref) => DJTrackRepo());

class DJTrackHive extends StateNotifier<List<DJTrack>?> {
  DJTrackHive(this.ref) : super(null) {
    /// Repository Todo Service Provider
    repo = ref.read(djtrackRepositoryProvider);
    fetchDJTrack();
  }
  late DJTrackRepo? repo;
  final StateNotifierProviderRef ref;

  ///fetch all todo from to local Storage

  void fetchDJTrack() {
    state = repo!.getDJTracks();
  }

  ///add todo to local Storage

  void addDJTrack(DJTrack djTrack) {
    state = repo!.addDJTrack(djTrack);
  }

  ///remove todo from local Storage
  void removeDJTrack(String id) {
    state = repo!.removeDJTrack(id);
  }

  ///Update  current todo from local Storage

  void updateDJTrack(DJTrack djTrack) {
    state = repo!.updateDJTrack(djTrack);
  }
}
