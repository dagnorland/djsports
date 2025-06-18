part of 'spotify_playlist_form_cubit.dart';

@immutable
abstract class SpotifyPlaylistFormState {
  final AutovalidateMode? autovalidateMode;
  final DJPlaylistType type;
  final String spotifyUri;
  final String spotifyUriSecond;
  final List<String> trackIds;

  const SpotifyPlaylistFormState({
    this.autovalidateMode,
    this.type = DJPlaylistType.hotspot,
    this.spotifyUri = '',
    this.spotifyUriSecond = '',
    this.trackIds = const [],
  });

  SpotifyPlaylistFormState copyWith({
    AutovalidateMode? autovalidateMode,
    DJPlaylistType? type,
    String? spotifyUri,
    String? spotifyUriSecond,
    List<String>? trackIds,
  });
}

class SpotifyPlaylistFormUpdate extends SpotifyPlaylistFormState {
  const SpotifyPlaylistFormUpdate({
    String spotifyUri = '',
    String spotifyUriSecond = '',
    List<String> trackIds = const [],
    DJPlaylistType type = DJPlaylistType.hotspot,
    AutovalidateMode? autovalidateMode,
  }) : super(
          spotifyUri: spotifyUri,
          spotifyUriSecond: spotifyUriSecond,
          trackIds: trackIds,
          type: type,
          autovalidateMode: autovalidateMode,
        );

  @override
  SpotifyPlaylistFormState copyWith({
    AutovalidateMode? autovalidateMode,
    DJPlaylistType? type,
    String? spotifyUri,
    String? spotifyUriSecond,
    List<String>? trackIds,
  }) {
    return SpotifyPlaylistFormUpdate(
      autovalidateMode: autovalidateMode ?? this.autovalidateMode,
      type: type ?? this.type,
      spotifyUri: spotifyUri ?? this.spotifyUri,
      spotifyUriSecond: spotifyUriSecond ?? this.spotifyUriSecond,
      trackIds: trackIds ?? this.trackIds,
    );
  }
}
