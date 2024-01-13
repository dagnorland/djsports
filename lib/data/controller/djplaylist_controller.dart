import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/repo/djplaylist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final djplaylistRepositoryProvider =
    Provider<DJPlaylistRepo>((ref) => DJPlaylistRepo());

class DJPlaylistHive extends StateNotifier<List<DJPlaylist>?> {
  DJPlaylistHive(this.ref) : super(null) {
    /// Repository Todo Service Provider
    repo = ref.read(djplaylistRepositoryProvider);
    fetchDJPlaylist();
  }
  late DJPlaylistRepo? repo;
  final StateNotifierProviderRef ref;

  ///fetch all todo from to local Storage

  void fetchDJPlaylist() {
    state = repo!.getDJPlaylists();
  }

  ///add todo to local Storage

  void addDJplaylist(DJPlaylist djPlaylist) {
    state = repo!.addDJPlaylist(djPlaylist);
  }

  ///remove todo from local Storage
  void removeDJPlaylist(String id) {
    state = repo!.removeDJPlaylist(id);
  }

  ///Update  current todo from local Storage

  void updateDJPlaylist(DJPlaylist djPlaylist) {
    state = repo!.updateDJPlaylist(djPlaylist);
  }
}
