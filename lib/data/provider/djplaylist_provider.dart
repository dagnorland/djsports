import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../controller/djplaylist_controller.dart';
import '../models/djplaylist_model.dart';
import '../repo/djplaylist_repository.dart';

///filtered data based on user todo status
final typeFilterPlaylistProvider =
    StateProvider<DJPlaylistType>((ref) => DJPlaylistType.all);

/// Filtered Todo List
final typeFilteredAllDataProvider = Provider<List<DJPlaylist>>(
  (ref) {
    final hiveDatas = ref.watch(hivePlaylistData);
    final typeData = hiveDatas!;
    final type = ref.watch(typeFilterPlaylistProvider);
    if (type == DJPlaylistType.all) {
      return hiveDatas.toList();
    }

    List<DJPlaylist> myData =
        typeData.where((todo) => todo.type == type.name).toList();
    return myData;
  },
);

///Category Selection
final selectedRadioProvider = StateProvider<int>((ref) => 0);

///Todo RepoProvider
final providerHive = Provider<DJPlaylistRepo>((ref) => DJPlaylistRepo());

///Hive data
final hivePlaylistData =
    NotifierProvider<DJPlaylistHive, List<DJPlaylist>?>(DJPlaylistHive.new);

/// Returns a specific DJPlaylist by ID
/// Throws [StateError] if playlist is not found
final djPlaylistByIdProvider = Provider.family<DJPlaylist, String>(
  (ref, id) {
    final playlists = ref.watch(hivePlaylistData);
    if (playlists == null) {
      throw StateError('Playlist database is not initialized');
    }

    return playlists.firstWhere(
      (playlist) => playlist.id == id,
      orElse: () => throw StateError('Playlist not found: $id'),
    );
  },
);
