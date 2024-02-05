import 'package:djsports/data/services/spotify_playlist_service.dart';
import 'package:djsports/features/playlist/widgets/spotify_track_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify/spotify.dart';

class SpotifyPlaylistDelegate extends SearchDelegate<Track?> {
  SpotifyPlaylistDelegate(this.playlistService, this.existingSpotifyTrackUris);
  final SpotifyPlaylistService playlistService;
  final List<String> existingSpotifyTrackUris;

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Text('Enter a playlist ID to search');
    }
    // search-as-you-type if enabled

    playlistService.getPlaylistById(query);
    return buildMatchingSuggestions(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return Text('Waiting for result is still empty ${DateTime.now()}');
    }
    // always search if submitted
    debugPrint('buildResults get playlist by id: $query ${DateTime.now()}');
    playlistService.getPlaylistById(query);
    return buildMatchingSuggestions(context);
  }

  Widget buildMatchingSuggestions(BuildContext context) {
    debugPrint('buildMatchingSuggestions: $query ${DateTime.now()}');
    return Consumer(
      builder: (_, ref, __) {
        final resultsValue = ref.watch(playlistResultsProvider);
        debugPrint(
            'buildMatchingSuggestions playlist resultsValue: $resultsValue ${DateTime.now()}');
        return resultsValue.when(
          data: (result) {
            debugPrint('buildMatchingSuggestions playlist result: $result');
            return result.when(
              (tracks) => GridView.builder(
                itemCount: tracks.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  debugPrint(
                      'buildMatchingSuggestions playlist index spotifyUri: ${tracks.elementAt(index).uri}');
                  final trackExist = existingSpotifyTrackUris
                      .contains(tracks.elementAt(index).uri);
                  return Container(
                      decoration: BoxDecoration(
                          border: Border.all(
                              width: trackExist ? 0 : 3,
                              color: trackExist
                                  ? Colors.green.shade100
                                  : Colors.red)),
                      child: SpotifyTrackSearchResultTile(
                        track: tracks.elementAt(index),
                        onSelected: (value) => close(context, value),
                      ));
                },
              ),
              error: (error) => SearchPlaceholder(title: error.toString()),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text(e.toString())),
        );
      },
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return query.isEmpty
        ? []
        : <Widget>[
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear),
              onPressed: () {
                query = '';
                showSuggestions(context);
              },
            )
          ];
  }
}
