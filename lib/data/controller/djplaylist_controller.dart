import 'package:djsports/data/controller/djtrack_controller.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/repo/djplaylist_repository.dart';
import 'package:flutter/material.dart';
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
  final StateNotifierProviderRef<StateNotifier<List<DJPlaylist>?>,
      List<DJPlaylist>?> ref;
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

  ///remove todo from local Storage
  void removeDJPlaylist(DJTrackHive trackHive, String id) {
    List<String> trackIds =
        state!.firstWhere((element) => element.id == id).trackIds.toList();
    for (var element in trackIds) {
      debugPrint('remove track id $element');
      trackHive.removeDJTrack(element);
    }
    debugPrint('remove playlist $id');
    state = repo!.removeDJPlaylist(id);
  }

  DJPlaylist removeDJTrackFromPlaylist(
      DJTrackHive trackHive, String playlistId, String trackId) {
    state = repo!.removeDJTrackFromPlaylist(playlistId, trackId);
    trackHive.removeDJTrack(trackId);
    return state!.firstWhere((element) => element.id == playlistId);
  }

  ///Update  current todo from local Storage

  void updateDJPlaylist(DJPlaylist djPlaylist) {
    state = repo!.updateDJPlaylist(djPlaylist);
  }

  void addTrackToDJPlaylist(DJPlaylist djPlaylist, DJTrack djTrack) {
    djPlaylist.addTrack(djTrack.id);
    state = repo!.updateDJPlaylist(djPlaylist);
  }
}
