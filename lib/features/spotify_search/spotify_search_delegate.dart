import 'package:cached_network_image/cached_network_image.dart';
import 'package:djsports/data/services/spotify_search_service.dart';
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
    if (query.isEmpty) {
      return Container();
    }
    // search-as-you-type if enabled
    searchService.searchTrack(query);
    return buildMatchingSuggestions(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return Container();
    }
    // always search if submitted
    searchService.searchTrack(query);
    return buildMatchingSuggestions(context);
  }

  Widget buildMatchingSuggestions(BuildContext context) {
    return Consumer(
      builder: (_, ref, __) {
        final resultsValue = ref.watch(searchResultsProvider);
        return resultsValue.when(
          data: (result) {
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
                  return SpotifyTrackSearchResultTile(
                    track: tracks[index],
                    onSelected: (value) => close(context, value),
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

class SpotifyTrackSearchResultTile extends StatelessWidget {
  const SpotifyTrackSearchResultTile(
      {super.key, required this.track, required this.onSelected});
  final Track track;
  final ValueChanged<Track> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: () => onSelected(track),
      child: Column(
        children: [
          if (track.album!.images!.first.url != null)
            ClipPath(
              clipper: const ShapeBorderClipper(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: track.album!.images!.first.url!,
              ),
            ),
          const SizedBox(height: 8.0),
          Text(
            track.name!,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.start,
          )
        ],
      ),
    );
  }
}

class SearchPlaceholder extends StatelessWidget {
  const SearchPlaceholder({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Text(
        title,
        style: theme.textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
