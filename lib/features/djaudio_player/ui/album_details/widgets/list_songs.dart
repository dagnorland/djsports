import 'package:audio_service/audio_service.dart';
import 'package:djsports/data/models/audio_player_album.dart';
import 'package:djsports/data/provider/audio_player_providers.dart';
import 'package:djsports/features/djaudio_player/ui/album_details/widgets/album_song.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ListAlbumSongs extends ConsumerWidget {
  const ListAlbumSongs({super.key, required this.album});
  final AudioPlayerAlbum album;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<MediaItem> songs = ref
        .watch(songsProvider)
        .where((item) => item.album == album.title)
        .toList();
    return Expanded(
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: songs.length,
        itemBuilder: (context, index) {
          return AlbumSong(song: songs[index]);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 10),
      ),
    );
  }
}
