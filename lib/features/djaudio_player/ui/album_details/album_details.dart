import 'package:djsports/data/models/audio_player_album.dart';
import 'package:djsports/data/provider/audio_player_providers.dart';
import 'package:djsports/features/djaudio_player/ui/album_details/widgets/album_info.dart';
import 'package:djsports/features/djaudio_player/ui/album_details/widgets/list_songs.dart';
import 'package:djsports/features/djaudio_player/ui/widgets/current_song.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlbumDetails extends StatelessWidget {
  const AlbumDetails({super.key, required this.album});

  final AudioPlayerAlbum album;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          30,
          MediaQuery.of(context).padding.top + 20,
          30,
          80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back),
                ),
                Text(
                  'Detail Album',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Icon(Icons.music_note),
              ],
            ),
            const SizedBox(height: 30),
            AlbumInfo(album: album),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'List Song',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Consumer(
                  builder: (context, ref, child) {
                    return GestureDetector(
                      onTap: () {
                        final songs = ref.watch(songsProvider);
                        ref.watch(audioPlayerProvider.notifier).startPlayList(
                              songs
                                  .where(
                                      (element) => element.album == album.title)
                                  .toList(),
                              0,
                            );
                      },
                      child: Text(
                        'Play',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    );
                  },
                )
              ],
            ),
            const SizedBox(height: 30),
            ListAlbumSongs(album: album),
          ],
        ),
      ),
      bottomSheet: const CurrentSong(),
    );
  }
}
