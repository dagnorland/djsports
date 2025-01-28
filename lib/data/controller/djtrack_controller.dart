import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/repo/djtrack_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final djtrackRepositoryProvider = Provider<DJTrackRepo>((ref) => DJTrackRepo());

class DJTrackHive extends StateNotifier<List<DJTrack>?> {
  DJTrackHive(this.ref) : super(null) {
    /// Repository Todo Service Provider
    repo = ref.read(djtrackRepositoryProvider);
    fetchDJTrack();
  }
  late DJTrackRepo? repo;
  final Ref ref;

  ///fetch all todo from to local Storage

  void fetchDJTrack() {
    state = repo!.getDJTracks();
  }

  List<String> getDJTracksSpotifyUri(List<String> trackIds) {
    if (repo == null) {
      return [];
    }
    final djTracks = repo!
        .getDJTracks()
        .where((element) => trackIds.contains(element.id))
        .toList();
    for (var djTrack in djTracks) {
      if (djTrack.spotifyUri.isNotEmpty) {
        return djTracks.map((e) => e.spotifyUri).toList();
      }
    }
    return [];
  }

  List<DJTrack> getDJTracks(List<String> trackIds) {
    return repo!
        .getDJTracks()
        .where((element) => trackIds.contains(element.id))
        .toList();
  }

  Future<bool> resumePlayer() async {
    {
      bool isPlaying =
          await ref.read(spotifyRemoteRepositoryProvider).resumePlayer();
      return isPlaying;
    }
  }

  void addDJTrack(DJTrack djTrack) {
    if (djTrack.id.isEmpty) {
      djTrack.id = const Uuid().v4();
    }
    final existingTracks = repo!.getDJTracks();
    if (existingTracks.any((track) => track.id == djTrack.id)) {
      return;
    }
    state = repo!.addDJTrack(djTrack);
  }

  String getFirstNetworkImageUri(List<String> trackIds) {
    if (repo == null) {
      return '';
    }

    final tracks = repo!.getDJTracks();
    for (var track in tracks) {
      if (trackIds.contains(track.id) && track.networkImageUri.isNotEmpty) {
        return track.networkImageUri;
      }
    }

    return '';
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
