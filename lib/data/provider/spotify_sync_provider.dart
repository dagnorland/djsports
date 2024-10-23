import 'package:djsports/data/models/spotify_playlist_result.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:spotify/spotify.dart';

part 'spotify_sync_provider.g.dart';
part 'spotify_sync_provider.freezed.dart';

@freezed
class SyncProgress with _$SyncProgress {
  const factory SyncProgress({
    @Default(0) int addedCount,
    @Default(0) int skippedCount,
    @Default(0) int totalTracks,
  }) = _SyncProgress;
}

typedef GetTracksByUri = Future<Iterable<Track>> Function(String);
typedef GetTracksByUriAsyncValue = Future<SpotifyPlaylistResult> Function(
    String);
typedef GetSpotifyNameUri = Future<String> Function(String);
typedef AddDJTrack = void Function(DJTrack);
typedef AddTrackToDJPlaylist = void Function(DJPlaylist, DJTrack);
typedef UpdateDJPlaylist = void Function(DJPlaylist);

@riverpod
class SpotifySync extends _$SpotifySync {
  @override
  FutureOr<SyncProgress> build() => const SyncProgress();

  Future<void> syncPlaylist(
    String playlistUri,
    DJPlaylist playlist,
    List<String> existingTrackSpotifyUris,
    GetTracksByUri getTracksByUri,
    GetSpotifyNameUri getSpotifyNameUri,
    AddDJTrack addDJTrack,
    AddTrackToDJPlaylist addTrackToDJPlaylist,
    UpdateDJPlaylist updateDJPlaylist,
  ) async {
    state = const AsyncValue.loading();

    try {
      final result = await getTracksByUri(playlistUri);
      final syncName = await getSpotifyNameUri(playlistUri);

      var progress = SyncProgress(totalTracks: result.length);

      for (final track in result) {
        if (existingTrackSpotifyUris.contains(track.uri)) {
          progress = progress.copyWith(
            skippedCount: progress.skippedCount + 1,
          );
        } else {
          final addTrack = DJTrack.fromSpotifyTrack(track);
          addDJTrack(addTrack);
          addTrackToDJPlaylist(playlist, addTrack);
          progress = progress.copyWith(
            addedCount: progress.addedCount + 1,
          );
        }

        state = AsyncValue.data(progress);
      }

      playlist = playlist.copyWith(name: syncName);
      updateDJPlaylist(playlist);

      state = AsyncValue.data(progress);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
