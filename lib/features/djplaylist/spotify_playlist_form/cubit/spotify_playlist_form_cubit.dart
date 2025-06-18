import 'package:bloc/bloc.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:flutter/cupertino.dart';

part 'spotify_playlist_form_state.dart';

//TODO: bloc validation example
https://medium.com/@azharbinanwar/flutter-form-validation-with-bloc-b46a1ced63c2

class SpotifyPlaylistFormCubit extends Cubit<SpotifyPlaylistFormState> {
  SpotifyPlaylistFormCubit() : super(const SpotifyPlaylistFormUpdate());

  void initForm({
    String spotifyUri = '',
    String spotifyUriSecond = '',
    List<String> trackIds = const [],
  }) {
    emit(state.copyWith(
      spotifyUri: spotifyUri,
      spotifyUriSecond: spotifyUriSecond,
      trackIds: trackIds,
    ));
  }

  void onSpotifyUriChanged(String value) {
    emit(state.copyWith(spotifyUri: value));
  }

  void onSpotifyUriSecondChanged(String value) {
    emit(state.copyWith(spotifyUriSecond: value));
  }

  void onTrackIdsChanged(List<String> value) {
    emit(state.copyWith(trackIds: value));
  }

  void onTypeChanged(DJPlaylistType value) {
    emit(state.copyWith(type: value));
  }

  void updateAutovalidateMode(AutovalidateMode? autovalidateMode) {
    emit(state.copyWith(autovalidateMode: autovalidateMode));
  }

  void reset() {
    emit(const SpotifyPlaylistFormUpdate());
  }
}
