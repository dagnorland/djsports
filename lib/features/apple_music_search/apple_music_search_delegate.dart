import 'package:cached_network_image/cached_network_image.dart';
import 'package:djsports/data/provider/apple_music_provider.dart';
import 'package:djsports/data/services/apple_music_platform_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppleMusicSearchDelegate extends SearchDelegate<AppleMusicTrack?> {
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
  List<Widget> buildActions(BuildContext context) {
    return query.isEmpty
        ? []
        : [
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear),
              onPressed: () {
                query = '';
                showSuggestions(context);
              },
            ),
          ];
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 3) {
      return const Center(
        child: Text(
          'Type at least 3 characters to search',
          style: TextStyle(fontSize: 20),
        ),
      );
    }
    return _SearchResults(query: query, onSelected: (t) => close(context, t));
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.length < 3) {
      return const Center(
        child: Text(
          'Type at least 3 characters to search',
          style: TextStyle(fontSize: 20),
        ),
      );
    }
    return _SearchResults(query: query, onSelected: (t) => close(context, t));
  }
}

class _SearchResults extends ConsumerStatefulWidget {
  const _SearchResults({required this.query, required this.onSelected});

  final String query;
  final ValueChanged<AppleMusicTrack> onSelected;

  @override
  ConsumerState<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends ConsumerState<_SearchResults> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(appleMusicSearchProvider.notifier)
          .search(widget.query);
    });
  }

  @override
  void didUpdateWidget(_SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      ref
          .read(appleMusicSearchProvider.notifier)
          .search(widget.query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsValue = ref.watch(appleMusicSearchProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return resultsValue.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const Center(child: Text('No results'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: tracks.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isLandscape ? 8 : 5,
            crossAxisSpacing: 20,
            mainAxisSpacing: 5,
            childAspectRatio: isLandscape ? 0.7 : 0.9,
          ),
          itemBuilder: (context, index) {
            return _AppleMusicTrackTile(
              track: tracks[index],
              onSelected: widget.onSelected,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

class _AppleMusicTrackTile extends StatelessWidget {
  const _AppleMusicTrackTile({
    required this.track,
    required this.onSelected,
  });

  final AppleMusicTrack track;
  final ValueChanged<AppleMusicTrack> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onSelected(track),
      child: Column(
        children: [
          SizedBox(
            height: 125,
            width: 130,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: track.artworkUrl.isNotEmpty
                  ? CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: track.artworkUrl,
                      errorWidget: (context, url, error) =>
                          const _ArtworkPlaceholder(),
                    )
                  : const _ArtworkPlaceholder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            track.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.music_note, color: Colors.white54, size: 48),
    );
  }
}
