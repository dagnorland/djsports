import 'package:djsports/data/services/spotify_search_service.dart';
import 'package:djsports/features/playlist/widgets/spotify_track_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify/spotify.dart';

class SpotifySearchDelegate extends SearchDelegate<Track?> {
  SpotifySearchDelegate(this.searchService);
  final SpotifySearchService searchService;

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
    if (query.isEmpty || query.length < 5) {
      return const Center(
          child: Text(
        'Text min 5 characters to search',
        style: TextStyle(fontSize: 20),
      ));
    }
    // search-as-you-type if enabled
    searchService.searchTrack(query);
    return buildMatchingSuggestions(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty || query.length < 5) {
      return const Center(
          child: Text(
        'Text min 5 characters to search',
        style: TextStyle(fontSize: 20),
      ));
    }
    // always search if submitted
    searchService.searchTrack(query);
    return buildMatchingSuggestions(context);
  }

  Widget buildMatchingSuggestions(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Consumer(
      builder: (_, ref, __) {
        final resultsValue = ref.watch(searchResultsProvider);
        return resultsValue.when(
          data: (result) {
            return result.when(
              (tracks) => GridView.builder(
                itemCount: tracks.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  // if landscape mode set crossAxisCount to 8
                  crossAxisCount: isLandscape ? 8 : 5,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 5,
                  childAspectRatio: isLandscape ? 0.7 : 0.9,
                ),
                itemBuilder: (context, index) {
                  return SpotifyTrackSearchResultTile(
                    track: tracks[index],
                    existInPlaylist: false,
                    onSelected: (track) =>
                        addTrackToPlaylist(context, track, ref),
                  );
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

  void addTrackToPlaylist(BuildContext context, Track track, WidgetRef ref) {
    close(context, track);
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
