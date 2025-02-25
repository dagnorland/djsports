import 'package:djsports/data/controller/djtrack_controller.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
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
  final Ref ref;
  void fetchDJPlaylist() {
    state = repo!.getDJPlaylists();
  }

  String addDJplaylist(DJPlaylist djPlaylist) {
    state = repo!.addDJPlaylist(djPlaylist);
    if (state != null) {
      if (state!.isNotEmpty) {
        return state!.last.id;
      }
    }
    return '';
  }

  void removeDJPlaylist(DJTrackHive trackHive, String id) {
    List<String> trackIds =
        state!.firstWhere((element) => element.id == id).trackIds.toList();
    for (var element in trackIds) {
      if (trackHive.existsDJTrack(element)) {
        trackHive.removeDJTrack(element);
      }
    }
    state = repo!.removeDJPlaylist(id);
  }

  DJPlaylist shuffleTracksInPlaylist(String playlistId) {
    DJPlaylist playlist =
        state!.firstWhere((element) => element.id == playlistId);
    if (!playlist.shuffleAtEnd) {
      return playlist;
    }
    final shuffledTracks = [...playlist.trackIds]..shuffle();
    final updatedPlaylist = playlist.copyWith(trackIds: shuffledTracks);
    fetchDJPlaylist();
    return repo!.updateDJPlaylist(updatedPlaylist);
  }

  DJPlaylist removeDJTrackFromPlaylist(
      DJTrackHive trackHive, String playlistId, String trackId) {
    DJPlaylist playlist = repo!.removeDJTrackFromPlaylist(playlistId, trackId);

    trackHive.removeDJTrack(trackId);
    fetchDJPlaylist();
    return playlist;
  }

  ///Update  current todo from local Storage

  DJPlaylist updateDJPlaylist(DJPlaylist djPlaylist) {
    final updatedPlaylist = repo!.updateDJPlaylist(djPlaylist);
    fetchDJPlaylist();
    return updatedPlaylist;
  }

  DJPlaylist addTrackToDJPlaylist(DJPlaylist djPlaylist, DJTrack djTrack) {
    djPlaylist.addTrack(djTrack.id);
    return repo!.updateDJPlaylist(djPlaylist);
  }
}

extension on DJPlaylist {
  DJPlaylist copyWith({required List<String> trackIds}) {
    return DJPlaylist(
      id: id,
      name: name,
      trackIds: trackIds,
      shuffleAtEnd: shuffleAtEnd,
      type: type,
      spotifyUri: spotifyUri,
      autoNext: autoNext,
    );
  }
}
