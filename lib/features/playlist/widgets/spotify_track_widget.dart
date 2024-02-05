import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:spotify/spotify.dart';

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
            SizedBox(
                height: 120,
                width: 120,
                child: ClipPath(
                  clipper: const ShapeBorderClipper(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,
                    imageUrl: track.album!.images!.first.url!,
                  ),
                )),
          const SizedBox(height: 8.0),
          Text(
            track.name!,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.start,
          ),
          Text(
            track.artists!.first.name!,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.start,
          ),
          Text(
            track.duration!.toString(),
            style: theme.textTheme.titleSmall,
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
