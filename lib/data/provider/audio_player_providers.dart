import 'package:audio_service/audio_service.dart';
import 'package:djsports/data/controller/djplaylist_state.dart';
import 'package:djsports/data/models/audio_player_album.dart';
import 'package:djsports/data/provider/djaudio_player_notifier.dart';
import 'package:djsports/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final songsProvider = StateProvider<List<MediaItem>>((ref) => []);
final albumsProvider = StateProvider<List<AudioPlayerAlbum>>((ref) => []);
final audioHandlerProvider = Provider<AudioHandler>(
    (ref) => AudioServiceSingleton.instance.audioHandler);

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, PlayListState>(
  (ref) => AudioPlayerNotifier(ref.read(audioHandlerProvider)),
);
