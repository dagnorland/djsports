import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:equatable/equatable.dart';

enum SpotifyPlaylistField {
  type,
  spotifyUri,
  spotifyUriSecond,
}

class SpotifyImportFormData extends Equatable {
  const SpotifyImportFormData({
    this.type,
    this.spotifyUri,
    this.spotifyUriSecond,
    this.trackIds,
  });

  final DJPlaylistType? type;
  final String? spotifyUri;
  final String? spotifyUriSecond;
  final List<String>? trackIds;

  @override
  List<Object?> get props => [type, spotifyUri, spotifyUriSecond, trackIds];
}
